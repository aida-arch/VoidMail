import SwiftUI

struct SettingsView: View {
    @ObservedObject var authService: GoogleAuthService
    @State private var blockTrackers = true
    @State private var readReceipts = true
    @State private var smartNotifications = true
    @State private var aiSummaries = true
    @State private var showSignOutConfirm = false
    @State private var signatureEnabled = true
    @State private var accountSignatures: [String: String] = [:]
    @State private var editingSignatureAccount: String? = nil
    @AppStorage("appearance_mode") private var appearanceMode: String = "dark"
    @State private var showNamePrompt = false
    @State private var newAccountName = ""
    @State private var namingEmail: String? = nil
    @State private var editingNameEmail: String? = nil
    @State private var editNameText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgDeep.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: Screen Header
                        ScreenHeader(
                            metaLeft: "VOIDMAIL",
                            metaRight: "BUILD: 1.1",
                            title: "Settings"
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // MARK: Accounts
                        systemSection(title: "ACCOUNTS") {
                            ForEach(authService.accounts) { account in
                                accountRow(account)
                            }

                            Button {
                                Task { await authService.addAccount() }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.textPrimary)
                                    Text("Add Account")
                                        .font(Typo.body)
                                        .foregroundColor(.textPrimary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }

                        // MARK: Preferences
                        systemSection(title: "PREFERENCES") {
                            ToggleRow(icon: "bell.badge.fill", title: "Smart Notifications", isOn: $smartNotifications)
                            VoidDivider().padding(.horizontal, 16)
                            ToggleRow(icon: "sparkles", title: "AI Summaries", isOn: $aiSummaries)
                        }

                        // MARK: Email Signature (Per-Account)
                        systemSection(title: "EMAIL SIGNATURES") {
                            ToggleRow(icon: "signature", title: "Enable Signatures", isOn: $signatureEnabled)

                            if signatureEnabled {
                                ForEach(authService.accounts) { account in
                                    VoidDivider().padding(.horizontal, 16)

                                    VStack(alignment: .leading, spacing: 8) {
                                        Button {
                                            withAnimation(.spring(response: 0.3)) {
                                                if editingSignatureAccount == account.email {
                                                    editingSignatureAccount = nil
                                                } else {
                                                    editingSignatureAccount = account.email
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 10) {
                                                Circle()
                                                    .fill(account.colorTag.color)
                                                    .frame(width: 8, height: 8)
                                                Text(account.email)
                                                    .font(Typo.mono)
                                                    .foregroundColor(.textSecondary)
                                                    .lineLimit(1)
                                                Spacer()
                                                Image(systemName: editingSignatureAccount == account.email ? "chevron.up" : "chevron.down")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.textTertiary)
                                            }
                                        }

                                        if editingSignatureAccount == account.email {
                                            let binding = Binding<String>(
                                                get: { accountSignatures[account.email] ?? UserDefaults.standard.string(forKey: "voidmail_signature_\(account.email)") ?? "Sent from VoidMail" },
                                                set: { newValue in
                                                    accountSignatures[account.email] = newValue
                                                    UserDefaults.standard.set(newValue, forKey: "voidmail_signature_\(account.email)")
                                                }
                                            )
                                            TextEditor(text: binding)
                                                .font(Typo.subhead)
                                                .foregroundColor(.textPrimary)
                                                .scrollContentBackground(.hidden)
                                                .background(Color.bgDeep)
                                                .frame(minHeight: 80, maxHeight: 140)
                                                .cornerRadius(8)
                                                .transition(.opacity.combined(with: .move(edge: .top)))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                }
                            }
                        }

                        // MARK: Privacy & Security
                        systemSection(title: "PRIVACY & SECURITY") {
                            ToggleRow(icon: "shield.checkered", title: "Block Trackers", isOn: $blockTrackers)
                            VoidDivider().padding(.horizontal, 16)
                            ToggleRow(icon: "eye.fill", title: "Read Receipts", isOn: $readReceipts)
                            VoidDivider().padding(.horizontal, 16)

                            NavigationLink {
                                encryptionView
                            } label: {
                                settingsNavRow(icon: "lock.fill", title: "Encryption")
                            }
                        }

                        // MARK: Appearance
                        systemSection(title: "APPEARANCE") {
                            VStack(spacing: 12) {
                                HStack(spacing: 14) {
                                    Image(systemName: "moon.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.textSecondary)
                                        .frame(width: 28)
                                    Text("Theme")
                                        .font(Typo.body)
                                        .foregroundColor(.textPrimary)
                                    Spacer()
                                }

                                Picker("Appearance", selection: $appearanceMode) {
                                    Text("Dark").tag("dark")
                                    Text("Light").tag("light")
                                    Text("System").tag("system")
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        // MARK: About
                        systemSection(title: "ABOUT") {
                            NavigationLink {
                                AboutView()
                            } label: {
                                settingsNavRow(icon: "info.circle", title: "About VoidMail")
                            }
                        }

                        // MARK: Sign Out
                        Button {
                            showSignOutConfirm = true
                        } label: {
                            Text("SIGN OUT")
                                .font(Typo.body)
                                .tracking(1)
                                .foregroundColor(.bgDeep)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.accentPink)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 120)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear { loadSignatures() }
            .alert("Sign Out", isPresented: $showSignOutConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    authService.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out of all accounts?")
            }
            .alert("Name This Account", isPresented: $showNamePrompt) {
                TextField("e.g. Work, Personal", text: $newAccountName)
                    .textInputAutocapitalization(.words)
                Button("Save") {
                    if let email = namingEmail, !newAccountName.trimmingCharacters(in: .whitespaces).isEmpty {
                        authService.updateAccountName(email: email, name: newAccountName.trimmingCharacters(in: .whitespaces))
                    }
                    newAccountName = ""
                    namingEmail = nil
                    authService.pendingNameAccount = nil
                }
                Button("Skip", role: .cancel) {
                    newAccountName = ""
                    namingEmail = nil
                    authService.pendingNameAccount = nil
                }
            } message: {
                if let email = namingEmail {
                    Text("Give \(email) a short name so it's easy to recognize.")
                }
            }
            .alert("Rename Account", isPresented: Binding(
                get: { editingNameEmail != nil },
                set: { if !$0 { editingNameEmail = nil } }
            )) {
                TextField("Account name", text: $editNameText)
                    .textInputAutocapitalization(.words)
                Button("Save") {
                    if let email = editingNameEmail, !editNameText.trimmingCharacters(in: .whitespaces).isEmpty {
                        authService.updateAccountName(email: email, name: editNameText.trimmingCharacters(in: .whitespaces))
                    }
                    editingNameEmail = nil
                    editNameText = ""
                }
                Button("Cancel", role: .cancel) {
                    editingNameEmail = nil
                    editNameText = ""
                }
            } message: {
                Text("Enter a short display name for this account.")
            }
            .onChange(of: authService.pendingNameAccount) { _, newValue in
                if let email = newValue {
                    namingEmail = email
                    newAccountName = ""
                    showNamePrompt = true
                }
            }
        }
    }

    // MARK: - System Section

    private func systemSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionDivider(label: title)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                content()
            }
            .padding(.vertical, 4)
            .background(Color.bgCard)
            .cornerRadius(8)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Account Row

    private func accountRow(_ account: UserAccount) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                // Color indicator circle
                Circle()
                    .fill(account.colorTag.color)
                    .frame(width: 12, height: 12)

                InitialsAvatar("G", size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(account.label)
                            .font(Typo.body)
                            .foregroundColor(.textPrimary)
                        Button {
                            editingNameEmail = account.email
                            editNameText = account.label
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.textTertiary)
                        }
                    }
                    Text(account.email)
                        .font(Typo.mono)
                        .foregroundColor(.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                if account.isPrimary {
                    Text("PRIMARY")
                        .font(Typo.mono)
                        .foregroundColor(.textPrimary)
                        .tracking(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            // Color picker row
            HStack(spacing: 10) {
                Text("COLOR")
                    .font(Typo.mono)
                    .foregroundColor(.textTertiary)
                    .tracking(1)

                Spacer()

                ForEach(AccountColor.allCases) { color in
                    Button {
                        authService.updateAccountColor(email: account.email, color: color)
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(account.colorTag == color ? Color.textPrimary : Color.clear, lineWidth: 2)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.bgCard, lineWidth: account.colorTag == color ? 2 : 0)
                                    .padding(1)
                            )
                    }
                }
            }
            .padding(.leading, 26)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Nav Row

    private func settingsNavRow(icon: String, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.textSecondary)
                .frame(width: 28)
            Text(title)
                .font(Typo.body)
                .foregroundColor(.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Load Signatures

    private func loadSignatures() {
        for account in authService.accounts {
            let key = "voidmail_signature_\(account.email)"
            accountSignatures[account.email] = UserDefaults.standard.string(forKey: key) ?? "Sent from VoidMail"
        }
    }

    // MARK: - Encryption View

    private var encryptionView: some View {
        ZStack {
            Color.bgDeep.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundColor(.textSecondary)
                    .padding(.top, 40)

                Text("ENCRYPTION")
                    .font(Typo.title3)
                    .foregroundColor(.textPrimary)
                    .tracking(2)

                Text("Your emails are encrypted on-device.\nNo data is stored on our servers.")
                    .font(Typo.subhead)
                    .foregroundColor(.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        ZStack {
            Color.bgDeep.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)

                    // Logo
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundColor(.textPrimary)

                    // Title
                    Text("VoidMail")
                        .font(Typo.title2)
                        .foregroundColor(.textPrimary)
                        .tracking(-0.5)

                    Text("Version 1.1")
                        .font(Typo.mono)
                        .foregroundColor(.textTertiary)
                        .tracking(1)

                    VoidDivider()
                        .padding(.horizontal, 40)

                    // Crafted by
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CRAFTED BY NEURAL ARC")
                            .font(Typo.meta)
                            .foregroundColor(.accentSkyBlue)
                            .tracking(2)

                        Text("Neural Arc is a forward-thinking technology company specializing in intelligent software solutions. Powered by the Helium AI engine, Neural Arc builds products that blend cutting-edge artificial intelligence with elegant user experiences. Our mission is to redefine how people interact with technology \u{2014} making it intuitive, powerful, and human-centered. VoidMail is our flagship communication platform, designed to bring clarity to your inbox through smart automation, privacy-first architecture, and a beautifully minimal interface.")
                            .font(Typo.subhead)
                            .foregroundColor(.textSecondary)
                            .lineSpacing(6)
                    }
                    .padding(20)
                    .background(Color.bgCard)
                    .cornerRadius(8)
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 40)

                    Text("\u{00A9} 2025 Neural Arc. All rights reserved.")
                        .font(Typo.mono)
                        .foregroundColor(.textTertiary)
                        .tracking(0.5)
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: 40)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
