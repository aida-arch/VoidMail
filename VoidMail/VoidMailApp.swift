import SwiftUI
import UserNotifications

@main
struct VoidMailApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @AppStorage("appearance_mode") private var appearanceMode: String = "dark"

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
                .task {
                    // Request notification permission on launch
                    await NotificationService.shared.requestPermission()
                    NotificationService.shared.registerCategories()
                }
        }
    }
}

// MARK: - App Delegate for Notifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case "REPLY_ACTION":
            if let emailId = userInfo["emailId"] as? String {
                print("[AppDelegate] Reply to email: \(emailId)")
            }
        case "ARCHIVE_ACTION":
            if let emailId = userInfo["emailId"] as? String {
                Task { @MainActor in
                    await GmailService.shared.archiveEmail(emailId)
                }
            }
        case "MARK_READ_ACTION":
            if let emailId = userInfo["emailId"] as? String {
                Task { @MainActor in
                    await GmailService.shared.toggleRead(emailId)
                }
            }
        default:
            if let emailId = userInfo["emailId"] as? String {
                print("[AppDelegate] Open email: \(emailId)")
            }
        }

        completionHandler()
    }
}
