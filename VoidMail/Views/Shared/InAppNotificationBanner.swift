import SwiftUI

// MARK: - Notification Data

struct NotificationData: Identifiable, Equatable {
    let id: UUID
    let senderName: String
    let subject: String
    let snippet: String
    let emailId: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        senderName: String,
        subject: String,
        snippet: String,
        emailId: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.senderName = senderName
        self.subject = subject
        self.snippet = snippet
        self.emailId = emailId
        self.timestamp = timestamp
    }
}

// MARK: - Notification Manager

final class InAppNotificationManager: ObservableObject {
    @Published var currentNotification: NotificationData?
    @Published var isShowing: Bool = false

    private var dismissTask: DispatchWorkItem?

    func show(senderName: String, subject: String, snippet: String, emailId: String) {
        // Cancel any pending auto-dismiss from a previous notification
        dismissTask?.cancel()

        let data = NotificationData(
            senderName: senderName,
            subject: subject,
            snippet: snippet,
            emailId: emailId
        )

        currentNotification = data

        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            isShowing = true
        }

        // Auto-dismiss after 4 seconds
        let task = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: task)
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil

        withAnimation(.easeOut(duration: 0.3)) {
            isShowing = false
        }

        // Clear data after fade-out completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            if self?.isShowing == false {
                self?.currentNotification = nil
            }
        }
    }
}

// MARK: - In-App Notification Banner

struct InAppNotificationBanner: View {
    @ObservedObject var manager: InAppNotificationManager
    var onTap: ((String) -> Void)?

    var body: some View {
        VStack {
            if manager.isShowing, let notification = manager.currentNotification {
                bannerContent(notification)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: manager.isShowing)
    }

    // MARK: - Banner Content

    @ViewBuilder
    private func bannerContent(_ notification: NotificationData) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Mail icon
            Image(systemName: "envelope.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.accentSkyBlue)
                .frame(width: 36, height: 36)
                .background(Color.bgDeep)
                .cornerRadius(8)

            // Text content
            VStack(alignment: .leading, spacing: 3) {
                // Sender + timestamp
                HStack {
                    Text(notification.senderName)
                        .font(Typo.headline)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(notification.timestamp.relativeFormatted)
                        .font(Typo.mono)
                        .foregroundColor(.textTertiary)
                }

                // Subject
                Text(notification.subject)
                    .font(Typo.subhead)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)

                // Snippet
                Text(notification.snippet)
                    .font(Typo.subhead)
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
            }

            // Close button
            Button {
                manager.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.textTertiary)
                    .frame(width: 24, height: 24)
                    .background(Color.bgDeep)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.bgCard)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?(notification.emailId)
            manager.dismiss()
        }
    }
}

// MARK: - View Modifier

extension View {
    func inAppNotificationBanner(
        manager: InAppNotificationManager,
        onTap: ((String) -> Void)? = nil
    ) -> some View {
        self.overlay(
            InAppNotificationBanner(manager: manager, onTap: onTap)
                .allowsHitTesting(manager.isShowing)
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.bgDeep.ignoresSafeArea()

        Text("INBOX")
            .font(Typo.display)
            .foregroundColor(.textPrimary)
    }
    .inAppNotificationBanner(
        manager: {
            let mgr = InAppNotificationManager()
            mgr.currentNotification = NotificationData(
                senderName: "Alice Chen",
                subject: "Re: Deployment pipeline fix",
                snippet: "Pushed the hotfix to staging, can you verify the build logs when you get a chance?",
                emailId: "preview-001"
            )
            mgr.isShowing = true
            return mgr
        }()
    )
}
