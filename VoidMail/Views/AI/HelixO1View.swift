import SwiftUI

// HelixO1View — Helix-o1 AI copilot dashboard with chat interface.

struct HelixO1View: View {
    @StateObject private var gmailService = GmailService.shared
    @StateObject private var calendarService = GoogleCalendarService.shared
    @State private var alerts: [AIAlert] = []
    @State private var animateCards = false
    @State private var digestText: String?
    @State private var isLoadingDigest = false

    // Chat state
    @State private var chatMessages: [ChatMessage] = []
    @State private var chatInput = ""
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgDeep.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            // MARK: Header
                            ScreenHeader(
                                metaLeft: "HELIX-O1",
                                metaRight: statusLabel,
                                title: "Helix-o1"
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                            // Helix branding
                            helixBranding
                                .padding(.horizontal, 20)

                            // MARK: Inbox Digest
                            digestCard
                                .padding(.horizontal, 20)
                                .opacity(animateCards ? 1 : 0)
                                .offset(y: animateCards ? 0 : 20)

                            // MARK: Quick Stats
                            quickStatsRow
                                .padding(.horizontal, 20)
                                .opacity(animateCards ? 1 : 0)
                                .offset(y: animateCards ? 0 : 15)
                                .animation(.spring(response: 0.5).delay(0.15), value: animateCards)

                            // MARK: Smart Alerts
                            if !alerts.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionDivider(label: "Smart Alerts · \(alerts.count)")
                                        .padding(.horizontal, 20)

                                    ForEach(Array(alerts.enumerated()), id: \.element.id) { index, alert in
                                        AlertCard(alert: alert) {
                                            withAnimation(.spring(response: 0.3)) {
                                                alerts.removeAll { $0.id == alert.id }
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .opacity(animateCards ? 1 : 0)
                                        .offset(y: animateCards ? 0 : 20)
                                        .animation(.spring(response: 0.5).delay(Double(index) * 0.1 + 0.3), value: animateCards)
                                    }
                                }
                            }

                            // MARK: Chat with Helix
                            chatSection(proxy: proxy)
                                .padding(.horizontal, 20)
                                .opacity(animateCards ? 1 : 0)
                                .offset(y: animateCards ? 0 : 15)
                                .animation(.spring(response: 0.5).delay(0.4), value: animateCards)

                            // MARK: Quick Actions
                            VStack(alignment: .leading, spacing: 12) {
                                SectionDivider(label: "Quick Actions")
                                    .padding(.horizontal, 20)

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                    quickTile(icon: "envelope.badge", title: "UNREAD", count: "\(gmailService.emails.filter { !$0.isRead }.count)", color: .accentPink)
                                    quickTile(icon: "star.fill", title: "STARRED", count: "\(gmailService.emails.filter { $0.isStarred }.count)", color: .accentYellow)
                                    quickTile(icon: "calendar", title: "EVENTS", count: "\(calendarService.events.count)", color: .accentSkyBlue)
                                    quickTile(icon: "paperclip", title: "FILES", count: "\(gmailService.emails.filter { !$0.attachments.isEmpty }.count)", color: .accentGreen)
                                }
                                .padding(.horizontal, 20)
                            }
                            .opacity(animateCards ? 1 : 0)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                withAnimation(.spring(response: 0.6).delay(0.2)) {
                    animateCards = true
                }
            }
            .task {
                await loadDigest()
                generateSmartAlerts()
            }
        }
    }

    private var statusLabel: String {
        if isLoadingDigest || isSending { return "THINKING..." }
        return "ACTIVE"
    }

    // MARK: - Helix Branding

    private var helixBranding: some View {
        HStack(spacing: 14) {
            // Pulsing sparkle icon
            ZStack {
                Circle()
                    .fill(Color.accentSkyBlue.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: "sparkles")
                    .font(.system(size: 22))
                    .foregroundColor(.accentSkyBlue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("HELIX-O1")
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .tracking(-0.5)
                Text("YOUR AI EMAIL CO-PILOT")
                    .font(Typo.mono)
                    .foregroundColor(.textTertiary)
                    .tracking(2)
            }
            Spacer()
        }
    }

    // MARK: - Digest Card

    private var digestCard: some View {
        VoidCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                    Text("INBOX SUMMARY")
                        .font(Typo.mono)
                        .foregroundColor(.textSecondary)
                        .tracking(1)
                    Spacer()
                    Text("TODAY")
                        .font(Typo.mono)
                        .foregroundColor(.textTertiary)
                        .tracking(1)
                }

                // Gemini Digest
                if isLoadingDigest {
                    HStack(spacing: 8) {
                        ProgressView().tint(.accentSkyBlue)
                        Text("ANALYZING INBOX...")
                            .font(Typo.mono)
                            .foregroundColor(.accentSkyBlue)
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                } else if let digest = digestText {
                    Text(digest)
                        .font(Typo.subhead)
                        .foregroundColor(.textSecondary)
                        .lineSpacing(4)
                } else {
                    Text("Sign in and sync your inbox to get an AI-powered digest.")
                        .font(Typo.subhead)
                        .foregroundColor(.textTertiary)
                        .lineSpacing(4)
                }

                // Progress
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("INBOX ZERO")
                            .font(Typo.mono)
                            .foregroundColor(.textTertiary)
                            .tracking(1)
                        Spacer()
                        Text("\(inboxZeroPercent)%")
                            .font(Typo.mono)
                            .foregroundColor(.textPrimary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.bgCardHover)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentGreen)
                                .frame(width: animateCards ? geo.size.width * CGFloat(inboxZeroPercent) / 100.0 : 0, height: 4)
                                .animation(.spring(response: 1.0).delay(0.5), value: animateCards)
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
    }

    // MARK: - Quick Stats Row

    private var quickStatsRow: some View {
        HStack(spacing: 10) {
            statPill(value: "\(gmailService.emails.filter { !$0.isRead }.count)", label: "NEW", color: .accentPink)
            statPill(value: "\(gmailService.emails.filter { $0.isStarred }.count)", label: "STARRED", color: .accentYellow)
            statPill(value: "\(calendarService.events.count)", label: "EVENTS", color: .accentSkyBlue)
        }
    }

    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.textPrimary)
            Text(label)
                .font(Typo.monoSmall)
                .foregroundColor(color)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: - Chat Section

    private func chatSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionDivider(label: "Ask Helix")

            // Chat history
            if !chatMessages.isEmpty {
                VStack(spacing: 8) {
                    ForEach(chatMessages) { msg in
                        chatBubble(msg)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity
                            ))
                    }
                }
            }

            // Input
            HStack(spacing: 10) {
                TextField("Ask anything about your inbox...", text: $chatInput)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.bgCard)
                    .cornerRadius(8)
                    .onSubmit { sendChat(proxy: proxy) }

                Button {
                    sendChat(proxy: proxy)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(chatInput.isEmpty ? Color.bgCardHover : Color.accentSkyBlue)
                            .frame(width: 44, height: 44)
                        if isSending {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(chatInput.isEmpty ? .textTertiary : .white)
                        }
                    }
                }
                .disabled(chatInput.isEmpty || isSending)
            }
            .id("chatInput")
        }
    }

    private func chatBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if !message.isUser {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundColor(.accentSkyBlue)
                        Text("HELIX")
                            .font(Typo.monoSmall)
                            .foregroundColor(.accentSkyBlue)
                            .tracking(1)
                    }
                }

                Text(message.text)
                    .font(Typo.subhead)
                    .foregroundColor(message.isUser ? .textPrimary : .textSecondary)
                    .lineSpacing(4)
                    .padding(12)
                    .background(message.isUser ? Color.bgCardHover : Color.bgCard)
                    .cornerRadius(12)
            }

            if !message.isUser { Spacer(minLength: 60) }
        }
    }

    // MARK: - Actions

    private func sendChat(proxy: ScrollViewProxy) {
        let text = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        chatInput = ""
        let userMsg = ChatMessage(id: UUID().uuidString, text: text, isUser: true)
        withAnimation(.spring(response: 0.3)) {
            chatMessages.append(userMsg)
        }

        isSending = true
        Task {
            // Build context from inbox
            let emailContext = gmailService.emails.prefix(5).map {
                "From: \($0.from.displayName), Subject: \($0.subject)"
            }.joined(separator: "\n")

            let reply = await GeminiService.shared.generateDraft(
                context: "User asks: \(text)\n\nRecent inbox:\n\(emailContext)\n\nRespond helpfully and concisely as Helix-o1, an AI email assistant. Keep answers under 3 sentences.",
                replyTo: nil
            ) ?? "I couldn't process that right now. Try again in a moment."

            let botMsg = ChatMessage(id: UUID().uuidString, text: reply, isUser: false)
            withAnimation(.spring(response: 0.3)) {
                chatMessages.append(botMsg)
            }
            isSending = false

            withAnimation {
                proxy.scrollTo("chatInput", anchor: .bottom)
            }
        }
    }

    private func loadDigest() async {
        isLoadingDigest = true
        let emails = gmailService.emails
        guard !emails.isEmpty else {
            isLoadingDigest = false
            return
        }
        let summaryEmails = emails.prefix(10).map { e in
            (from: e.from.displayName, subject: e.subject, snippet: e.snippet, isRead: e.isRead)
        }
        digestText = await GeminiService.shared.generateInboxDigest(emails: summaryEmails)
        isLoadingDigest = false
    }

    private func generateSmartAlerts() {
        var newAlerts: [AIAlert] = []

        // Unread emails older than 1 day = awaiting reply
        let oldUnread = gmailService.emails.filter { !$0.isRead && $0.date < Date().addingTimeInterval(-86400) }
        for email in oldUnread.prefix(2) {
            newAlerts.append(AIAlert(
                id: "reply_\(email.id)",
                type: .awaitingReply,
                title: "\(email.from.displayName) is waiting",
                subtitle: email.subject,
                emailId: email.id,
                eventId: nil,
                date: email.date
            ))
        }

        // Upcoming meetings in the next 30 min
        let upcoming = calendarService.events.filter {
            $0.startDate > Date() && $0.startDate < Date().addingTimeInterval(1800)
        }
        for event in upcoming.prefix(2) {
            newAlerts.append(AIAlert(
                id: "meeting_\(event.id)",
                type: .upcomingMeeting,
                title: event.title,
                subtitle: "Starts \(event.startTimeFormatted)",
                emailId: nil,
                eventId: event.id,
                date: event.startDate
            ))
        }

        // New senders today
        let todayEmails = gmailService.emails.filter { Calendar.current.isDateInToday($0.date) }
        let newSenders = todayEmails.filter { email in
            gmailService.emails.filter { $0.from.email == email.from.email }.count == 1
        }
        for email in newSenders.prefix(1) {
            newAlerts.append(AIAlert(
                id: "new_\(email.id)",
                type: .newSender,
                title: "New: \(email.from.displayName)",
                subtitle: email.subject,
                emailId: email.id,
                eventId: nil,
                date: email.date
            ))
        }

        withAnimation(.spring(response: 0.5)) {
            alerts = newAlerts
        }
    }

    private var inboxZeroPercent: Int {
        let total = gmailService.emails.count
        guard total > 0 else { return 100 }
        let read = gmailService.emails.filter { $0.isRead }.count
        return Int(Double(read) / Double(total) * 100)
    }

    private func quickTile(icon: String, title: String, count: String, color: Color) -> some View {
        VoidCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Text(title)
                    .font(Typo.mono)
                    .foregroundColor(.textPrimary)
                    .tracking(1)
                Text(count)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id: String
    let text: String
    let isUser: Bool
}

// MARK: - Alert Card

struct AlertCard: View {
    let alert: AIAlert
    let onDismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(alert.type.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: alert.type.icon)
                    .font(.system(size: 16))
                    .foregroundColor(alert.type.color)
            }

            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(alert.title)
                    .font(Typo.subhead)
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)
                Text(alert.subtitle)
                    .font(Typo.mono)
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Actions
            VStack(spacing: 6) {
                actionButton(label: primaryAction, isPrimary: true)
                actionButton(label: secondaryAction, isPrimary: false) {
                    onDismiss()
                }
            }
        }
        .padding(14)
        .background(Color.bgCard)
        .cornerRadius(8)
        .scaleEffect(appeared ? 1 : 0.96)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }

    private var primaryAction: String {
        switch alert.type {
        case .awaitingReply: return "Reply"
        case .upcomingMeeting: return "Join"
        case .followUp: return "Open"
        case .newSender: return "Allow"
        }
    }

    private var secondaryAction: String {
        switch alert.type {
        case .awaitingReply: return "Snooze"
        case .upcomingMeeting: return "Prep"
        case .followUp: return "Done"
        case .newSender: return "Block"
        }
    }

    private func actionButton(label: String, isPrimary: Bool, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            Text(label)
                .font(Typo.meta)
                .tracking(0.5)
                .foregroundColor(isPrimary ? .textPrimary : .textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isPrimary ? Color.bgCardHover : Color.bgCard)
                .cornerRadius(6)
        }
    }
}
