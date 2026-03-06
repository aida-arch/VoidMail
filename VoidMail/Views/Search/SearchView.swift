import SwiftUI

struct SearchView: View {
    @StateObject private var gmailService = GmailService.shared
    @State private var searchText = ""
    @State private var selectedEmail: Email?
    @State private var isSearching = false
    @State private var digestText: String?
    @State private var isLoadingDigest = false

    private let recentTags = ["Attachments", "Starred", "Unread", "This Week", "From: Sarah"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgDeep.ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: Header
                    ScreenHeader(
                        metaLeft: "INDEX 01",
                        metaRight: "\(gmailService.emails.count) TOTAL",
                        title: "Search"
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // MARK: Search Field
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.textTertiary)
                        TextField("Search emails...", text: $searchText)
                            .font(Typo.body)
                            .foregroundColor(.textPrimary)
                            .tint(.textPrimary)
                            .onSubmit { isSearching = true }

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                isSearching = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.textTertiary)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.bgCard)
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    if searchText.isEmpty {
                        // MARK: Recent Tags
                        VStack(alignment: .leading, spacing: 12) {
                            Text("RECENT")
                                .sectionLabel()
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(recentTags, id: \.self) { tag in
                                        TagChip(label: tag)
                                            .onTapGesture {
                                                searchText = tag
                                                isSearching = true
                                            }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 24)

                        // MARK: AI Digest
                        VoidCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14))
                                        .foregroundColor(.accentSkyBlue)
                                    Text("AI DIGEST")
                                        .font(Typo.mono)
                                        .foregroundColor(.accentSkyBlue)
                                        .tracking(1)
                                }

                                HStack(spacing: 20) {
                                    digestStat(value: "\(gmailService.emails.filter { !$0.isRead }.count)", label: "UNREAD")
                                    digestStat(value: "\(gmailService.emails.filter { $0.isStarred }.count)", label: "STARRED")
                                    digestStat(value: "\(gmailService.emails.filter { !$0.attachments.isEmpty }.count)", label: "FILES")
                                }

                                // Gemini Digest
                                if isLoadingDigest {
                                    HStack(spacing: 8) {
                                        ProgressView().tint(.accentSkyBlue)
                                        Text("ANALYZING...")
                                            .font(Typo.mono)
                                            .foregroundColor(.accentSkyBlue)
                                            .tracking(1)
                                    }
                                    .padding(.top, 4)
                                } else if let digest = digestText {
                                    Text(digest)
                                        .font(Typo.subhead)
                                        .foregroundColor(.textSecondary)
                                        .lineSpacing(4)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        Spacer()
                    } else {
                        // MARK: Results
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                let results = searchResults
                                if results.isEmpty {
                                    EmptyStateView(
                                        icon: "magnifyingglass",
                                        title: "No Results",
                                        subtitle: "Try a different search term"
                                    )
                                    .padding(.top, 40)
                                } else {
                                    ForEach(results) { email in
                                        EmailRowView(email: email)
                                            .contentShape(Rectangle())
                                            .onTapGesture { selectedEmail = email }
                                    }
                                }
                            }
                            .padding(.bottom, 120)
                        }
                        .padding(.top, 12)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedEmail) { email in
                EmailDetailView(email: email)
            }
            .task {
                isLoadingDigest = true
                let emails = gmailService.emails
                let summaryEmails = emails.prefix(10).map { e in
                    (from: e.from.displayName, subject: e.subject, snippet: e.snippet, isRead: e.isRead)
                }
                digestText = await GeminiService.shared.generateInboxDigest(emails: summaryEmails)
                isLoadingDigest = false
            }
        }
    }

    private func digestStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.textPrimary)
            Text(label)
                .font(Typo.mono)
                .foregroundColor(.textTertiary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var searchResults: [Email] {
        gmailService.emails.filter {
            $0.subject.localizedCaseInsensitiveContains(searchText) ||
            $0.from.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.snippet.localizedCaseInsensitiveContains(searchText) ||
            $0.body.localizedCaseInsensitiveContains(searchText)
        }
    }
}
