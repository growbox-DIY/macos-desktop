import SwiftUI

// The phone app's controls (components/controlers, ManualMode, AutoMode,
// scheduler.tsx, FloweringStart, FertilizerSection, EndOfPeriodCard) with
// the same API calls and rules.

// --- building blocks ---

struct SwitchRow: View {
    let title: String
    let icon: Ionicon
    let color: Color
    let isOn: Bool
    var status: String?
    var disabled = false
    let action: () async -> Void

    var body: some View {
        Card {
            HStack(spacing: 12) {
                icon.view(size: 20).foregroundStyle(color)
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.text)
                Spacer()
                Text(status ?? (isOn ? "ON" : "OFF"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isOn ? Palette.green : Palette.textMuted)
                Toggle("", isOn: Binding(get: { isOn }, set: { _ in Task { await action() } }))
                    .toggleStyle(.switch)
                    .tint(Palette.green)
                    .labelsHidden()
                    .disabled(disabled)
            }
        }
    }
}

// a 0-100 % slider that sends its value once, on release
struct LevelRow: View {
    let label: String
    let value: Int
    var range: ClosedRange<Double> = 0...100
    var step: Double = 1
    var disabled = false
    let onCommit: (Int) async -> Void

    @State private var draft: Double?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(label).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.text)
                    Spacer()
                    Text("\(Int(draft ?? Double(value)))%")
                        .font(.system(size: 15, weight: .bold).monospacedDigit())
                        .foregroundStyle(disabled ? Palette.textMuted : Palette.green)
                }
                Slider(
                    value: Binding(get: { draft ?? Double(value) }, set: { draft = $0 }),
                    in: range,
                    step: step,
                    onEditingChanged: { editing in
                        guard !editing, let level = draft else { return }
                        Task {
                            await onCommit(Int(level))
                            draft = nil
                        }
                    }
                )
                .tint(Palette.green)
                .disabled(disabled)
            }
        }
        .opacity(disabled ? 0.5 : 1)
    }
}

struct SectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(Palette.text)
            Text(subtitle).font(.system(size: 14)).foregroundStyle(Palette.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InfoCard: View {
    let icon: Ionicon
    let color: Color
    let title: String
    let text: String

    var body: some View {
        Card {
            HStack(spacing: 14) {
                icon.view(size: 22).foregroundStyle(color)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.text)
                    Text(text).font(.system(size: 13)).foregroundStyle(Palette.textMuted)
                }
                Spacer()
            }
        }
    }
}

// --- Settings: mode tabs, Manual / Auto controls, OLED, TFT monitor ---

struct SettingsView: View {
    let model: BoxModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Header(title: "Settings", model: model)

            Picker("", selection: Binding(
                get: { model.mode },
                set: { mode in if mode != model.mode { Task { await model.toggleMode() } } }
            )) {
                Text("Manual").tag("MANUAL")
                Text("Auto").tag("AUTO")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(model.response == nil || model.isSaving)

            if model.mode == "MANUAL" {
                SectionTitle(title: "Manual mode", subtitle: "Control everything manually.")
                SwitchRow(title: "Light", icon: .bulbOutline, color: Palette.yellow, isOn: model.lightOn) {
                    await model.toggleLight()
                }
                SwitchRow(title: "Fan", icon: .apertureOutline, color: Palette.blue, isOn: model.fanOn) {
                    await model.toggleFan()
                }
                SwitchRow(
                    title: "Auto fan", icon: .thermometerOutline, color: Palette.blue, isOn: model.fanAuto,
                    status: model.fanAuto ? "BY TEMPERATURE" : "OFF"
                ) {
                    await model.toggleFanAuto()
                }
                LevelRow(label: "Day fan", value: model.dayLevel, disabled: model.fanAuto) { level in
                    await model.setFanLevel(level)
                }
            } else {
                SectionTitle(title: "Auto mode", subtitle: "Automated growing schedule.")
                FloweringStartCard(model: model)
                LevelRow(label: "Fan speed", value: model.dayLevel) { level in
                    await model.setFanLevel(level)
                }
                SwitchRow(title: "Night fan", icon: .moonOutline, color: Palette.blue, isOn: model.nightFanOn) {
                    await model.toggleNightFan()
                }
                LevelRow(label: "Night dimmer level", value: model.nightLevel) { level in
                    await model.setNightFanLevel(level)
                }
            }

            SwitchRow(title: "Display", icon: .desktopOutline, color: Palette.cyan, isOn: model.displayOn) {
                await model.toggleDisplay()
            }

            if let monitor = model.monitor {
                SwitchRow(title: "Monitor", icon: .tvOutline, color: Palette.cyan, isOn: monitor.enabled) {
                    await model.setMonitor(enabled: !monitor.enabled)
                }
                LevelRow(
                    label: "Monitor brightness", value: monitor.brightness, range: 5...100, step: 5,
                    disabled: !monitor.enabled
                ) { level in
                    await model.setMonitor(brightness: level)
                }
            }

            ActionError(model: model)
        }
        .padding(20)
        .frame(maxWidth: 700, alignment: .leading)
    }
}

struct ActionError: View {
    let model: BoxModel

    var body: some View {
        if let error = model.actionError {
            Text(error).font(.system(size: 12)).foregroundStyle(Palette.red)
        }
    }
}

// Auto: start date and week, or a button to start flowering today
struct FloweringStartCard: View {
    let model: BoxModel
    @State private var confirmReset = false

    var body: some View {
        if let start = model.floweringStartDate {
            Card {
                HStack(spacing: 12) {
                    Ionicon.leafOutline.view(size: 25).foregroundStyle(Palette.green)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Flowering start").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.text)
                        Text("\(start), Week \(min(model.floweringWeek?.week ?? 1, FertilizerPlan.totalWeeks))")
                            .font(.system(size: 13)).foregroundStyle(Palette.textMuted)
                    }
                    Spacer()
                    Button { confirmReset = true } label: {
                        Ionicon.closeCircle.view(size: 28).foregroundStyle(Palette.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .confirmationDialog("Clear the flowering start?", isPresented: $confirmReset) {
                Button("Clear", role: .destructive) { Task { await model.setFloweringStartDate(nil) } }
            }
        } else {
            StartFloweringButton(model: model)
        }
    }
}

struct StartFloweringButton: View {
    let model: BoxModel
    @State private var confirm = false

    var body: some View {
        Button { confirm = true } label: {
            HStack {
                Text("Start flowering").font(.system(size: 16, weight: .bold))
                Spacer()
                Ionicon.leafOutline.view(size: 23)
            }
            .foregroundStyle(Palette.surfaceLight)
            .padding(14)
            .background(Palette.green, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .confirmationDialog("Start flowering today?", isPresented: $confirm) {
            Button("Start flowering") { Task { await model.setFloweringStartDate(FertilizerPlan.today()) } }
        }
    }
}

// --- Scheduler: the light schedule, Auto only ---

struct SchedulerView: View {
    let model: BoxModel
    @State private var editing: String?
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Header(title: "Scheduler", model: model)
            SensorCard(model: model)

            if model.mode != "AUTO" {
                InfoCard(
                    icon: .calendarOutline, color: Palette.blue, title: "Auto mode required",
                    text: "The scheduler is available only when the system is running in Auto mode."
                )
            } else {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "Light schedule", subtitle: "Set when the light turns on and off.")
                        row("ON", model.schedule?.on ?? "--:--", key: "on")
                        Divider().overlay(Palette.border)
                        row("OFF", model.schedule?.off ?? "--:--", key: "off")

                        if let editing {
                            editor(editing)
                        }
                    }
                }
            }

            ActionError(model: model)
        }
        .padding(20)
        .frame(maxWidth: 700, alignment: .leading)
    }

    private func row(_ label: String, _ time: String, key: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.textMuted)
                Text(time).font(.system(size: 28, weight: .bold).monospacedDigit()).foregroundStyle(Palette.text)
            }
            Spacer()
            Button("Change") {
                editing = key
                draft = time.replacingOccurrences(of: ":", with: "")
            }
            .disabled(model.schedule == nil)
        }
    }

    private func editor(_ key: String) -> some View {
        HStack(spacing: 10) {
            Text(key == "on" ? "ON time" : "OFF time").foregroundStyle(Palette.textMuted)
            TextField("HHMM", text: Binding(
                get: { draft },
                set: { draft = String($0.filter(\.isNumber).prefix(4)) }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 90)
            .onSubmit { Task { await save(key) } }
            Button("Cancel") { editing = nil }
            Button("Save") { Task { await save(key) } }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.count != 4 || model.isSaving)
        }
    }

    // same checks as the app: four digits, hours <= 23, minutes <= 59
    private func save(_ key: String) async {
        guard draft.count == 4, let schedule = model.schedule,
              let hours = Int(draft.prefix(2)), let minutes = Int(draft.suffix(2)),
              hours <= 23, minutes <= 59 else { return }

        let time = "\(draft.prefix(2)):\(draft.suffix(2))"
        let on = key == "on" ? time : schedule.on
        let off = key == "off" ? time : schedule.off

        if await model.setLightSchedule(on: on, off: off) {
            editing = nil
        }
    }
}

// --- Home cards ---

enum FertilizerPlan {
    struct Dose: Identifiable {
        let name: String
        let ml: Int
        var id: String { name }
        var color: Color { Self.colors[name] ?? Palette.text }

        // BioBizz label colours from data/fertilizerSchedule.ts
        static let colors: [String: Color] = [
            "ROOT·JUICE": Color(hex: 0xB08982), "BIO·GROW": Color(hex: 0x76BC7A),
            "FISH·MIX": Color(hex: 0x4A95E8), "BIO·BLOOM": Color(hex: 0xF1604C),
            "TOP·MAX": Color(hex: 0xD85A61), "BIO·HEAVEN": Color(hex: 0x5CCAD6),
            "ALG·A·MIC": Color(hex: 0x53DF74), "ACTI·VERA": Color(hex: 0x9BC86A),
        ]
    }

    static let totalWeeks = 10
    // from this week on nothing is fed any more: the period ends
    static let endOfPeriodWeek = 9

    // Manual (vegetative) feeding = BioBizz Week 2, per 1 L of water
    static let veg = doses(2, 0, 0, 2, 2)

    // our week -> BioBizz week + 2, per 1 L of water
    static let schedule: [Int: [Dose]] = [
        1: doses(2, 1, 1, 2, 2), 2: doses(2, 2, 1, 2, 2), 3: doses(3, 2, 1, 3, 3),
        4: doses(3, 3, 1, 4, 4), 5: doses(4, 3, 1, 4, 4), 6: doses(4, 4, 4, 5, 5),
        7: doses(4, 4, 4, 5, 5), 8: doses(4, 4, 4, 5, 5), 9: doses(4, 4, 4, 5, 5),
        10: doses(4, 4, 4, 5, 5),
    ]

    private static func doses(_ grow: Int, _ bloom: Int, _ topMax: Int, _ heaven: Int, _ vera: Int) -> [Dose] {
        [
            Dose(name: "BIO·GROW", ml: grow), Dose(name: "BIO·BLOOM", ml: bloom),
            Dose(name: "TOP·MAX", ml: topMax), Dose(name: "BIO·HEAVEN", ml: heaven),
            Dose(name: "ACTI·VERA", ml: vera),
        ].filter { $0.ml > 0 }
    }

    // the app sends new Date().toISOString().slice(0, 10)
    static func today() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: Date())
    }
}

struct NutrientsCard: View {
    let title: String
    let doses: [FertilizerPlan.Dose]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Ionicon.flaskOutline.view(size: 18).foregroundStyle(Palette.green)
                    Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.text)
                    Spacer()
                    Text("per 1 L").font(.system(size: 12)).foregroundStyle(Palette.textMuted)
                }
                ForEach(doses) { dose in
                    HStack {
                        Text(dose.name).font(.system(size: 14, weight: .bold)).foregroundStyle(dose.color)
                        Spacer()
                        Text("\(dose.ml) ml").font(.system(size: 14, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Palette.text)
                    }
                }
            }
        }
    }
}

// Auto home: start button, or the week's nutrients, or the end of the period
struct FloweringSection: View {
    let model: BoxModel

    var body: some View {
        if model.floweringStartDate == nil {
            InfoCard(
                icon: .leafOutline, color: Palette.green, title: "Start flowering first",
                text: "Start flowering in Auto mode to see the flowering schedule and nutrients."
            )
            StartFloweringButton(model: model)
        } else {
            let week = model.floweringWeek?.week ?? 1

            if week >= FertilizerPlan.endOfPeriodWeek {
                EndOfPeriodCard(model: model)
            } else {
                NutrientsCard(title: "Nutrients schedule", doses: FertilizerPlan.schedule[week] ?? [])
            }
        }
    }
}

struct EndOfPeriodCard: View {
    let model: BoxModel
    @State private var confirm = false
    @State private var message: String?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Ionicon.flagOutline.view(size: 24).foregroundStyle(Palette.cyan)
                    Text("End of period").font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.text)
                    Spacer()
                }
                HStack(spacing: 8) {
                    Ionicon.waterOutline.view(size: 18).foregroundStyle(Palette.text)
                    Text("Water only").font(.system(size: 14)).foregroundStyle(Palette.textMuted)
                }
                Button("Finish") { confirm = true }
                    .disabled(model.isSaving)
                if let message {
                    Text(message).font(.system(size: 12)).foregroundStyle(Palette.red)
                }
            }
        }
        .confirmationDialog("Finish the period?", isPresented: $confirm) {
            Button("Finish", role: .destructive) { Task { await finish() } }
        } message: {
            Text("This erases all sensor logs on the SD card and in the app, then switches the box to Manual.")
        }
    }

    // erase the log, then switch to Manual - the card only shows in Auto
    private func finish() async {
        guard await model.eraseEnvironment() else {
            message = "Could not erase the logs. Check the connection and try again."
            return
        }

        if model.mode == "AUTO" {
            await model.toggleMode()
            if model.mode == "AUTO" {
                message = "Logs erased. Could not switch to Manual. Switch the mode by hand."
            }
        }
    }
}

// the Feeded button: a confirm step so a stray click can't log a watering,
// and locked for 24 h after a feeding (FeedingCard.tsx)
struct FeedButton: View {
    let model: BoxModel
    @State private var confirm = false

    var body: some View {
        let overdue = model.feedingStatus == .overdue

        Button { confirm = true } label: {
            Text(overdue ? "Feed me now!" : "Feeded")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.surfaceLight)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(overdue ? Palette.red : Palette.green, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(model.fedRecently || model.isSaving || model.response == nil)
        .confirmationDialog("Save today's watering on the controller?", isPresented: $confirm) {
            Button("Feed") { Task { _ = await model.logFeeding() } }
        }
    }
}
