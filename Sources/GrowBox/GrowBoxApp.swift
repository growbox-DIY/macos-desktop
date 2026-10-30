import AppKit
import SwiftUI

// GrowBox for the Mac: the phone app's screens (Home, Scheduler, Settings)
// in a window with a sidebar. Same ESP API, same colours and rules.

enum Section: String, CaseIterable, Identifiable {
    case home = "Home"
    case scheduler = "Scheduler"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: Ionicon {
        switch self {
        case .home: .homeOutline
        case .scheduler: .calendarOutline
        case .settings: .settingsOutline
        }
    }
}

@main
struct GrowBoxApp: App {
    @State private var model = BoxModel()

    init() {
        Ionicon.registerFont()
    }

    var body: some Scene {
        WindowGroup("GrowBox") {
            RootView(model: model)
                .frame(minWidth: 860, minHeight: 640)
                .onAppear {
                    model.start()
                    Snapshot.runIfAsked(model: model)
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct RootView: View {
    let model: BoxModel
    @State private var section: Section? = .home

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $section) { item in
                Label {
                    Text(item.rawValue).foregroundStyle(Palette.text)
                } icon: {
                    item.icon.view(size: 16).foregroundStyle(section == item ? Palette.green : Palette.textMuted)
                }
                .tag(item)
            }
            .scrollContentBackground(.hidden)
            .background(Palette.surface)
            .navigationSplitViewColumnWidth(170)
        } detail: {
            ScrollView {
                switch section ?? .home {
                case .home: HomeView(model: model)
                case .scheduler: SchedulerView(model: model)
                case .settings: SettingsView(model: model)
                }
            }
            .background(Palette.background)
        }
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .snapshotSection)) { note in
            section = note.object as? Section ?? section
        }
    }
}

extension Notification.Name {
    static let snapshotSection = Notification.Name("GrowBoxSnapshotSection")
}

struct HomeView: View {
    let model: BoxModel

    var body: some View {
        VStack(spacing: 12) {
            Header(title: "GrowBox", model: model)
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 12) {
                    SensorCard(model: model)
                    ChartCard(model: model)
                }
                // the app's home: Manual = fan, veg nutrients, feeding;
                // Auto = flowering card, nutrients or end of period, feeding
                VStack(spacing: 12) {
                    StatusCard(model: model)
                    if model.mode == "AUTO" {
                        FloweringSection(model: model)
                    } else {
                        NutrientsCard(title: "Veg nutrients", doses: FertilizerPlan.veg)
                    }
                    FeedingCard(model: model)
                    ActionError(model: model)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: 1100)
    }
}

// title on the left, connection state or mode on the right
struct Header: View {
    let title: String
    let model: BoxModel

    var body: some View {
        HStack {
            Text(title).font(.system(size: 22, weight: .bold)).foregroundStyle(Palette.text)
            Spacer()
            if model.isSearching {
                Loader(text: "Searching for the box…")
            } else if model.response == nil && model.error == nil {
                Loader(text: "Connecting…")
            } else if let error = model.error {
                Text(error).font(.system(size: 12)).foregroundStyle(Palette.red)
            } else {
                Text(model.isFlowering ? "AUTO" : "MANUAL")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.green)
            }
        }
    }
}

// --snapshot <file.png> [--snapshot-delay <s>] [--snapshot-section <name>]:
// render a screen once the data is in and quit (layout checks without
// screen access)
enum Snapshot {
    @MainActor
    static func runIfAsked(model: BoxModel) {
        let args = CommandLine.arguments

        guard let index = args.firstIndex(of: "--snapshot"), index + 1 < args.count else {
            return
        }

        let path = args[index + 1]
        let delay = value(after: "--snapshot-delay", in: args).flatMap(Double.init) ?? 10
        let section = value(after: "--snapshot-section", in: args).flatMap(Section.init(rawValue:)) ?? .home

        Task { @MainActor in
            if let window = NSApp.windows.first(where: { $0.isVisible }) {
                window.setContentSize(NSSize(width: 1180, height: 560))
                window.center()
                NSApp.activate()
                window.makeKeyAndOrderFront(nil)
                NotificationCenter.default.post(name: .snapshotSection, object: section)
            }

            try? await Task.sleep(for: .seconds(delay))

            // the whole window (sidebar, title bar buttons and all), drawn
            // from the view tree - no screen recording permission needed
            if let window = NSApp.windows.first(where: { $0.isVisible }),
               let frameView = window.contentView?.superview,
               let rep = NSBitmapImageRep(
                   bitmapDataPlanes: nil,
                   pixelsWide: Int(frameView.bounds.width) * 2,
                   pixelsHigh: Int(frameView.bounds.height) * 2,
                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                   colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
               )?.retagging(with: .sRGB) {
                rep.size = frameView.bounds.size
                frameView.cacheDisplay(in: frameView.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            }

            NSApp.terminate(nil)
        }
    }

    private static func value(after flag: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else {
            return nil
        }

        return args[index + 1]
    }
}
