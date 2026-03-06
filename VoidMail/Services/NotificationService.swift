import Foundation
import UserNotifications
import UIKit

// MARK: - Notification Service
// Handles local notifications for new emails arriving.
// Requests permission, schedules notifications, manages badge count.

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false
    @Published var badgeCount = 0

    private let center = UNUserNotificationCenter.current()

    // MARK: - Request Permission

    func requestPermission() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            if granted {
                print("[NotificationService] Permission granted")
            }
        } catch {
            print("[NotificationService] Permission error: \(error.localizedDescription)")
        }
    }

    // MARK: - Check Authorization Status

    func checkAuthorization() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Schedule New Email Notification

    func notifyNewEmail(from senderName: String, subject: String, snippet: String, emailId: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = senderName
        content.subtitle = subject
        content.body = String(snippet.prefix(100))
        content.sound = UNNotificationSound(named: UNNotificationSoundName("mail_received.caf"))
        content.badge = NSNumber(value: badgeCount + 1)
        content.userInfo = ["emailId": emailId]
        content.categoryIdentifier = "NEW_EMAIL"
        content.threadIdentifier = emailId

        // Deliver immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "email_\(emailId)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("[NotificationService] Failed to schedule: \(error.localizedDescription)")
            }
        }

        badgeCount += 1
    }

    // MARK: - Notify Multiple New Emails

    func notifyNewEmails(_ emails: [(from: String, subject: String, snippet: String, id: String)]) {
        for email in emails {
            notifyNewEmail(from: email.from, subject: email.subject, snippet: email.snippet, emailId: email.id)
        }
    }

    // MARK: - Clear Badge

    func clearBadge() {
        badgeCount = 0
        center.setBadgeCount(0)
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Register Notification Categories

    func registerCategories() {
        let replyAction = UNNotificationAction(
            identifier: "REPLY_ACTION",
            title: "Reply",
            options: [.foreground]
        )
        let archiveAction = UNNotificationAction(
            identifier: "ARCHIVE_ACTION",
            title: "Archive",
            options: [.destructive]
        )
        let markReadAction = UNNotificationAction(
            identifier: "MARK_READ_ACTION",
            title: "Mark as Read",
            options: []
        )

        let emailCategory = UNNotificationCategory(
            identifier: "NEW_EMAIL",
            actions: [replyAction, archiveAction, markReadAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        center.setNotificationCategories([emailCategory])
    }
}
