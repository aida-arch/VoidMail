import SwiftUI

struct InboxView: View {
    @StateObject private var gmailService = GmailService.shared
    @StateObject private var authService = GoogleAuthService.shared
    @EnvironmentObject var notificationManager: InAppNotificationManager
    @State private var selectedTab = 0
    @State private var selectedEmail: Email?
    @State private var searchText = ""
    @State private var showHelix = false
    @State private var selectedAccountEmail: String? = nil  // nil = All accounts

    private let chips = ["All", "Priority", "Updates", "Newsletters"]

    private var unreadCount: Int {
        filteredEmails.filter { !$0.isRead }.count
    }

    private var primaryAccountColor: Color {
        if let selected = selectedAccountEmail,
           let account = authService.accounts.first(where: { $0.email == selected }) {
            return account.colorTag.color
        }
        return authService.accounts.first?.colorTag.color ?? .accentSkyBlue
    }

    /// Get account color for a specific email
    private func accountColor(for email: Email) -> Color {
        if let accountEmail = email.accountEmail,
           let account = authService.accounts.first(where: { $0.email == accountEmail }) {
            return account.colorTag.color
        }
        return primaryAccountColor
    }

    /// Display name for the currently selected account
    private var selectedAccountLabel: String {
        if let email = selectedAccountEmail {
            return authService.getAccountName(for: email)
        }
        return "All"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.bgDeep.ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: Screen Header
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("VOIDMAIL")
                                .metaLabel()
                            Spacer()
                            HStack(spacing: 8) {
                                Text("\(unreadCount) UNREAD")
                                    .font(Typo.mono)
                                    .tracking(1)
                                    .foregroundColor(unreadCount > 0 ? .accentYellow : .textTertiary)

                                // Refresh button
                                Button {
                                    Task { await gmailService.sync() }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.accentGreen.opacity(0.12))
                                            .frame(width: 34, height: 34)
                                        if gmailService.isSyncing {
                                            ProgressView()
                                                .tint(.accentGreen)
                                                .scaleEffect(0.7)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.accentGreen)
                                        }
                                    }
                                }
                                .disabled(gmailService.isSyncing)

                                // AI Helix button
                                Button { showHelix = true } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.accentSkyBlue.opacity(0.12))
                                            .frame(width: 34, height: 34)
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.accentSkyBlue)
                                    }
                                }
                            }
                        }

                        // Inbox title + account dropdown pill
                        HStack(spacing: 12) {
                            Text("Inbox")
                                .displayTitle()

                            // Account dropdown pill
                            Menu {
                                // "All Inboxes" option
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { selectedAccountEmail = nil }
                                } label: {
                                    HStack {
                                        Label("All Inboxes", systemImage: "tray.2.fill")
                                        if selectedAccountEmail == nil {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }

                                Divider()

                                // Per-account options
                                ForEach(authService.accounts) { account in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) { selectedAccountEmail = account.email }
                                    } label: {
                                        HStack {
                                            Label(account.label, systemImage: "envelope.fill")
                                            if selectedAccountEmail == account.email {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if let email = selectedAccountEmail,
                                       let account = authService.accounts.first(where: { $0.email == email }) {
                                        Circle()
                                            .fill(account.colorTag.color)
                                            .frame(width: 6, height: 6)
                                    }
                                    Text(selectedAccountLabel)
                                        .font(Typo.meta)
                                        .tracking(0.5)
                                        .foregroundColor(.textPrimary)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.textTertiary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.bgCardHover)
                                .clipShape(Capsule())
                            }

                            Spacer()
                        }
                        .padding(.top, -6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // MARK: Filter Chips
                    FilterChipBar(chips: chips, selected: $selectedTab)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 12)

                    // MARK: Email List
                    emailList
                }

                // FAB moved to ContentView to sit next to floating nav bar
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showHelix) {
                HelixO1View()
            }
            .navigationDestination(item: $selectedEmail) { email in
                EmailDetailView(email: email)
            }
        }
    }

    // MARK: - Email List

    private var emailList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let grouped = groupedEmails
                let sortedKeys = grouped.keys.sorted { key1, key2 in
                    if key1 == "Today" { return true }
                    if key2 == "Today" { return false }
                    if key1 == "Yesterday" { return true }
                    if key2 == "Yesterday" { return false }
                    return key1 > key2
                }

                ForEach(sortedKeys, id: \.self) { dateKey in
                    // Date divider
                    DateDivider(label: dateKey)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 10)

                    // Email cards
                    ForEach(grouped[dateKey] ?? []) { email in
                        EmailRowView(email: email, accountColor: accountColor(for: email))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEmail = email
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await gmailService.deleteEmail(email.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                                .tint(.accentPink)

                                Button {
                                    Task { await gmailService.toggleRead(email.id) }
                                } label: {
                                    Label(email.isRead ? "Unread" : "Read",
                                          systemImage: email.isRead ? "envelope.badge.fill" : "envelope.open.fill")
                                }
                                .tint(.accentSkyBlue)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    Task { await gmailService.archiveEmail(email.id) }
                                } label: {
                                    Label("Archive", systemImage: "archivebox.fill")
                                }
                                .tint(.accentGreen)
                            }
                    }
                }
            }
            .padding(.bottom, 140)
        }
        .refreshable {
            await gmailService.sync()
        }
        .task {
            // Wire in-app notifications
            gmailService.inAppNotificationManager = notificationManager
            // Auto-fetch emails on first appear
            if gmailService.emails.isEmpty {
                await gmailService.fetchEmails()
            }
            // Start auto-refresh timer
            gmailService.startAutoRefresh()
        }
    }

    // MARK: - Grouped Emails

    private var filteredEmails: [Email] {
        var result = gmailService.emails

        // Filter by account
        if let selectedAccount = selectedAccountEmail {
            result = result.filter { $0.accountEmail == selectedAccount }
        }

        // Filter by chip
        if selectedTab > 0 {
            let category = EmailCategory.allCases[selectedTab - 1]
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.subject.localizedCaseInsensitiveContains(searchText) ||
                $0.from.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.snippet.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    private var groupedEmails: [String: [Email]] {
        let calendar = Calendar.current
        var groups: [String: [Email]] = [:]
        for email in filteredEmails {
            let key: String
            if calendar.isDateInToday(email.date) {
                key = "Today"
            } else if calendar.isDateInYesterday(email.date) {
                key = "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                key = formatter.string(from: email.date)
            }
            groups[key, default: []].append(email)
        }
        return groups
    }
}
