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
    @State private var readFilter: ReadFilter = .read

    enum ReadFilter: String, CaseIterable {
        case all = "All"
        case unread = "Unread"
        case read = "Read"

        var icon: String {
            switch self {
            case .all: return "envelope.fill"
            case .unread: return "envelope.badge.fill"
            case .read: return "envelope.open.fill"
            }
        }

        /// Label shown in the pill (no text for "All" state)
        var pillLabel: String {
            switch self {
            case .all: return ""
            case .unread: return "Unread"
            case .read: return "Read"
            }
        }
    }

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

                        // Inbox title + inline filter pills (all on one row)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Inbox")
                                .font(.system(size: 48, weight: .heavy))
                                .foregroundColor(.textPrimary)
                                .textCase(.uppercase)
                                .tracking(-1.5)
                                .fixedSize()
                                .layoutPriority(1)

                            Spacer(minLength: 4)

                            // Account dropdown pill
                            Menu {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { selectedAccountEmail = nil }
                                } label: {
                                    HStack {
                                        Label("All Inboxes", systemImage: "tray.2.fill")
                                        if selectedAccountEmail == nil { Image(systemName: "checkmark") }
                                    }
                                }
                                Divider()
                                ForEach(authService.accounts) { account in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) { selectedAccountEmail = account.email }
                                    } label: {
                                        HStack {
                                            Label(account.label, systemImage: "envelope.fill")
                                            if selectedAccountEmail == account.email { Image(systemName: "checkmark") }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
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
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: 80)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.textTertiary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.bgCardHover)
                                .clipShape(Capsule())
                                .fixedSize()
                            }

                            // Read/Unread filter pill
                            Menu {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { readFilter = .unread }
                                } label: {
                                    HStack {
                                        Label("Unread", systemImage: "envelope.badge.fill")
                                        if readFilter == .unread { Image(systemName: "checkmark") }
                                    }
                                }
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { readFilter = .read }
                                } label: {
                                    HStack {
                                        Label("Read", systemImage: "envelope.open.fill")
                                        if readFilter == .read { Image(systemName: "checkmark") }
                                    }
                                }
                                if readFilter != .all {
                                    Divider()
                                    Button(role: .destructive) {
                                        withAnimation(.easeInOut(duration: 0.2)) { readFilter = .all }
                                    } label: {
                                        Label("Clear Filter", systemImage: "xmark.circle")
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: readFilter.icon)
                                        .font(.system(size: 11))
                                        .foregroundColor(readFilter == .all ? .textTertiary : .accentSkyBlue)
                                    Text(readFilter == .all ? "Filter" : readFilter.pillLabel)
                                        .font(Typo.meta)
                                        .tracking(0.5)
                                        .foregroundColor(readFilter == .all ? .textPrimary : .accentSkyBlue)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.textTertiary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(readFilter == .all ? Color.bgCardHover : Color.accentSkyBlue.opacity(0.12))
                                .clipShape(Capsule())
                                .fixedSize()
                            }
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
                if gmailService.isLoading && gmailService.emails.isEmpty {
                    // Shimmer skeleton while initial load
                    ForEach(0..<6, id: \.self) { _ in
                        EmailSkeletonRow()
                    }
                } else if filteredEmails.isEmpty {
                    EmptyStateView(
                        icon: readFilter == .unread ? "envelope.open" : "tray",
                        title: "No Emails",
                        subtitle: readFilter == .unread ? "You're all caught up" :
                                  readFilter == .read ? "No read emails" :
                                  selectedTab > 0 ? "Nothing in this category" : "Your inbox is empty"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
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
                            SwipeableEmailRow(
                                email: email,
                                accountColor: accountColor(for: email),
                                onTap: { selectedEmail = email },
                                onDelete: { Task { await gmailService.deleteEmail(email.id) } },
                                onToggleRead: { Task { await gmailService.toggleRead(email.id) } }
                            )
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

        // Filter by read/unread
        switch readFilter {
        case .unread:
            result = result.filter { !$0.isRead }
        case .read:
            result = result.filter { $0.isRead }
        case .all:
            break
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

// MARK: - Skeleton Loading Row

private struct EmailSkeletonRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Avatar placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
                .frame(width: 44, height: 44)
                .overlay(ShimmerView().cornerRadius(8))

            VStack(alignment: .leading, spacing: 8) {
                // Sender + time
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.clear)
                        .frame(width: 120, height: 14)
                        .overlay(ShimmerView().cornerRadius(4))
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.clear)
                        .frame(width: 50, height: 12)
                        .overlay(ShimmerView().cornerRadius(4))
                }
                // Subject
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.clear)
                    .frame(height: 14)
                    .overlay(ShimmerView().cornerRadius(4))
                // Snippet
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.clear)
                    .frame(width: 200, height: 12)
                    .overlay(ShimmerView().cornerRadius(4))
            }
        }
        .padding(20)
        .background(Color.bgEmailRow)
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Swipeable Email Row

private struct SwipeableEmailRow: View {
    let email: Email
    let accountColor: Color
    let onTap: () -> Void
    let onDelete: () -> Void
    let onToggleRead: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isSwiped = false

    private let swipeThreshold: CGFloat = 80
    private let actionWidth: CGFloat = 80

    var body: some View {
        ZStack(alignment: .center) {
            // Background actions revealed on swipe
            HStack(spacing: 0) {
                // Left action (swipe right → toggle read)
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: email.isRead ? "envelope.badge.fill" : "envelope.open.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text(email.isRead ? "Unread" : "Read")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .frame(width: actionWidth)
                }
                .frame(maxWidth: max(offset, 0), maxHeight: .infinity)
                .background(Color.accentSkyBlue)

                Spacer()

                // Right action (swipe left → delete)
                HStack {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Delete")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .frame(width: actionWidth)
                    Spacer()
                }
                .frame(maxWidth: max(-offset, 0), maxHeight: .infinity)
                .background(Color.accentPink)
            }
            .cornerRadius(8)
            .padding(.horizontal, 16)

            // Foreground email row
            EmailRowView(email: email, accountColor: accountColor)
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            // Only allow horizontal swipes
                            if abs(value.translation.width) > abs(value.translation.height) {
                                offset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            let dragWidth = value.translation.width

                            if dragWidth > swipeThreshold {
                                // Swiped right → toggle read
                                triggerAction(isDelete: false)
                            } else if dragWidth < -swipeThreshold {
                                // Swiped left → delete
                                triggerAction(isDelete: true)
                            } else {
                                // Snap back
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    offset = 0
                                }
                            }
                        }
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    if offset == 0 {
                        onTap()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = 0
                        }
                    }
                }
        }
    }

    private func triggerAction(isDelete: Bool) {
        let targetOffset: CGFloat = isDelete ? -UIScreen.main.bounds.width : UIScreen.main.bounds.width

        withAnimation(.easeIn(duration: 0.2)) {
            offset = targetOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if isDelete {
                onDelete()
            } else {
                onToggleRead()
            }
            // Reset after action
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                offset = 0
            }
        }
    }
}
