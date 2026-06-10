import SwiftUI
import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}

@main
struct fearGodApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                TodayView()
                    .tabItem { Label("Today", systemImage: "sun.max.fill") }
                BookListView()
                    .tabItem { Label("Bible", systemImage: "book.fill") }
                FavoritesView()
                    .tabItem { Label("Saved", systemImage: "heart.fill") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
        }
        .onChange(of: scenePhase) { phase in
            // Keep the 7-day notification window rolling forward.
            if phase == .active && DailyNotifications.enabled {
                DailyNotifications.reschedule()
            }
        }
    }
}
