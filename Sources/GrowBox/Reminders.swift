import Foundation
import UserNotifications

// Watering reminders, rescheduled whenever the last feeding changes - the
// app's hooks/useWateringReminders.ts: a gentle one on day 3 at 19:00, then
// from day 4 a time-sensitive alert every 2 h, 8:00-22:00, for up to a week.
// macOS fires them even with the app closed.
enum Reminders {
    private static let reminderHour = 19
    private static let lateAfterDays = 3
    private static let overdueAfterDays = 4
    private static let alertHours = stride(from: 8, through: 22, by: 2)
    private static let alertDays = 7
    private static let idPrefix = "watering-"

    static func sync(lastFedAt: Date?) {
        // UNUserNotificationCenter needs an app bundle (not `swift run`)
        guard Bundle.main.bundleIdentifier != nil else { return }

        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            center.getPendingNotificationRequests { requests in
                center.removePendingNotificationRequests(
                    withIdentifiers: requests.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
                )

                // nothing recorded yet: there is no date to count from
                guard let fedAt = lastFedAt else { return }

                schedule(center, "\(idPrefix)late", at(fedAt, lateAfterDays, reminderHour),
                         title: "Time to water", body: "Last watering was \(lateAfterDays) days ago.")

                for day in 0..<alertDays {
                    let days = overdueAfterDays + day

                    for hour in alertHours {
                        schedule(center, "\(idPrefix)overdue-\(day)-\(hour)", at(fedAt, days, hour),
                                 title: "Watering missed",
                                 body: "The plant hasn't been watered for \(days) days. Feed it now!",
                                 timeSensitive: true)
                    }
                }
            }
        }
    }

    // midnight of the feeding day + days, at the hour
    private static func at(_ fedAt: Date, _ days: Int, _ hour: Int) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: fedAt))!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    private static func schedule(
        _ center: UNUserNotificationCenter, _ id: String, _ date: Date,
        title: String, body: String, timeSensitive: Bool = false
    ) {
        guard date > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if timeSensitive { content.interruptionLevel = .timeSensitive }

        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
