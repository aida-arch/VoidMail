import Foundation
import SwiftUI
import AuthenticationServices

// MARK: - Google Auth Service
// Production OAuth flow using the Node.js backend for token exchange.
// Supports multiple Google accounts with per-account token storage.

@MainActor
class GoogleAuthService: ObservableObject {
    static let shared = GoogleAuthService()

    // MARK: - Published State

    @Published var isSignedIn = false
    @Published var currentUser: GoogleUser?
    @Published var accounts: [UserAccount] = []
    @Published var isLoading = false
    @Published var error: AuthError?
    @Published var pendingNameAccount: String?  // Set after adding a NEW account to trigger naming UI

    private let backend = BackendService.shared

    // Multi-account storage keys
    private let usersKey = "voidmail_users_v2"          // Array of GoogleUser
    private let accountColorsKey = "voidmail_account_colors"
    private let accountNamesKey = "voidmail_account_names"  // Custom display names per email

    // Legacy single-user key (for migration)
    private let legacyUserKey = "voidmail_user"

    // MARK: - Google User

    struct GoogleUser: Codable {
        let id: String
        let email: String
        let displayName: String
        let photoURL: String?
        var accessToken: String
        var refreshToken: String?
    }

    // MARK: - Auth Error

    enum AuthError: LocalizedError {
        case signInFailed(String)
        case scopesDenied
        case networkError
        case noAccessToken
        case backendUnavailable
        case unknown

        var errorDescription: String? {
            switch self {
            case .signInFailed(let msg): return "Sign in failed: \(msg)"
            case .scopesDenied: return "Required permissions were denied"
            case .networkError: return "Network error. Check your connection."
            case .noAccessToken: return "No access token available. Please sign in again."
            case .backendUnavailable: return "Backend server is not reachable. Start the server first."
            case .unknown: return "An unknown error occurred"
            }
        }
    }

    // MARK: - Required Scopes

    let requiredScopes = [
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/gmail.send",
        "https://www.googleapis.com/auth/gmail.modify",
        "https://www.googleapis.com/auth/calendar.readonly",
        "https://www.googleapis.com/auth/calendar.events",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile"
    ]

    // MARK: - All stored users (with tokens)

    private var storedUsers: [GoogleUser] = []

    // MARK: - Init — Restore Session

    init() {
        restoreSession()
    }

    private func restoreSession() {
        // Try loading multi-account data first
        if let data = UserDefaults.standard.data(forKey: usersKey),
           let users = try? JSONDecoder().decode([GoogleUser].self, from: data),
           !users.isEmpty {
            storedUsers = users
            currentUser = users.first
            isSignedIn = true
            rebuildAccounts()
            return
        }

        // Migrate from legacy single-user storage
        if let data = UserDefaults.standard.data(forKey: legacyUserKey),
           let user = try? JSONDecoder().decode(GoogleUser.self, from: data) {
            storedUsers = [user]
            currentUser = user
            isSignedIn = true
            persistAllUsers()
            rebuildAccounts()
            // Clean up legacy key
            UserDefaults.standard.removeObject(forKey: legacyUserKey)
        }
    }

    /// Rebuild the accounts array from storedUsers
    private func rebuildAccounts() {
        accounts = storedUsers.enumerated().map { index, user in
            let savedColor = loadAccountColor(for: user.email)
            let savedName = getAccountName(for: user.email)
            return UserAccount(
                id: user.id,
                email: user.email,
                displayName: user.displayName,
                photoURL: user.photoURL.flatMap { URL(string: $0) },
                provider: .google,
                isPrimary: index == 0,
                label: savedName,
                colorTag: savedColor
            )
        }
    }

    // MARK: - Account Name Persistence

    /// Update the custom display name for an account
    func updateAccountName(email: String, name: String) {
        var names = loadAllAccountNames()
        names[email] = name
        if let data = try? JSONEncoder().encode(names) {
            UserDefaults.standard.set(data, forKey: accountNamesKey)
        }
        // Update in-memory accounts
        if let index = accounts.firstIndex(where: { $0.email == email }) {
            accounts[index].label = name
        }
    }

    /// Get the custom display name for an account, or a default fallback
    func getAccountName(for email: String) -> String {
        let names = loadAllAccountNames()
        if let name = names[email], !name.isEmpty {
            return name
        }
        // Fallback: email prefix
        return email.components(separatedBy: "@").first ?? email
    }

    private func loadAllAccountNames() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: accountNamesKey),
              let names = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return names
    }

    // MARK: - Account Color Persistence

    func updateAccountColor(email: String, color: AccountColor) {
        if let index = accounts.firstIndex(where: { $0.email == email }) {
            accounts[index].colorTag = color
        }
        saveAccountColor(email: email, color: color)
    }

    private func saveAccountColor(email: String, color: AccountColor) {
        var colors = loadAllAccountColors()
        colors[email] = color.rawValue
        if let data = try? JSONEncoder().encode(colors) {
            UserDefaults.standard.set(data, forKey: accountColorsKey)
        }
    }

    private func loadAccountColor(for email: String) -> AccountColor {
        let colors = loadAllAccountColors()
        if let raw = colors[email], let color = AccountColor(rawValue: raw) {
            return color
        }
        // Default color based on account index
        let index = storedUsers.firstIndex(where: { $0.email == email }) ?? 0
        let defaults: [AccountColor] = [.skyBlue, .green, .pink, .yellow, .white]
        return defaults[min(index, defaults.count - 1)]
    }

    private func loadAllAccountColors() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: accountColorsKey),
              let colors = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return colors
    }

    private func persistAllUsers() {
        if let data = try? JSONEncoder().encode(storedUsers) {
            UserDefaults.standard.set(data, forKey: usersKey)
        }
    }

    // MARK: - Get Access Token

    /// Get access token for a specific account email. If nil, returns primary (first) account token.
    func getAccessToken(for email: String? = nil) async -> String? {
        if let email = email {
            return storedUsers.first(where: { $0.email == email })?.accessToken
        }
        return currentUser?.accessToken ?? storedUsers.first?.accessToken
    }

    /// Get all accounts and their tokens for multi-account fetching
    func getAllAccountTokens() -> [(email: String, token: String)] {
        return storedUsers.map { ($0.email, $0.accessToken) }
    }

    /// Refreshes the access token for a specific account using its stored refresh token via the backend.
    func refreshAccessToken(for email: String? = nil) async -> String? {
        let targetEmail = email ?? currentUser?.email ?? storedUsers.first?.email
        guard let targetEmail = targetEmail,
              let userIndex = storedUsers.firstIndex(where: { $0.email == targetEmail }),
              let refreshToken = storedUsers[userIndex].refreshToken else {
            error = .noAccessToken
            return nil
        }

        if let response = await backend.refreshToken(refreshToken) {
            storedUsers[userIndex].accessToken = response.tokens.access_token
            // Update currentUser if it matches
            if currentUser?.email == targetEmail {
                currentUser?.accessToken = response.tokens.access_token
            }
            persistAllUsers()
            return response.tokens.access_token
        }

        error = .noAccessToken
        return nil
    }

    // MARK: - Sign In (First Account)

    func signIn() async {
        await performOAuth(isAddingAccount: false)
    }

    // MARK: - Add Another Account

    func addAccount() async {
        await performOAuth(isAddingAccount: true)
    }

    // MARK: - Core OAuth Flow

    private func performOAuth(isAddingAccount: Bool) async {
        isLoading = true
        error = nil

        // Step 1: Check if backend is reachable
        let backendOnline = await backend.healthCheck()
        if !backendOnline {
            error = .backendUnavailable
            isLoading = false
            return
        }

        // Step 2: Get OAuth URL from backend
        guard let authURL = await backend.getAuthURL(),
              let url = URL(string: authURL) else {
            error = .signInFailed("Could not generate auth URL")
            isLoading = false
            return
        }

        // Step 3: Open ASWebAuthenticationSession
        do {
            let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                let session = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: "com.googleusercontent.apps.520426786442-3mq9486a1b5mtmo6nj6ibp78j375bpkf"
                ) { callbackURL, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let callbackURL = callbackURL {
                        continuation.resume(returning: callbackURL)
                    } else {
                        continuation.resume(throwing: AuthError.unknown)
                    }
                }
                // Force account picker when adding a new account
                session.prefersEphemeralWebBrowserSession = isAddingAccount

                var contextProvider: WebAuthContextProvider?
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    contextProvider = WebAuthContextProvider(window: window)
                    session.presentationContextProvider = contextProvider
                }

                session.start()
                _ = contextProvider
            }

            // Step 4: Parse tokens and user data from the callback URL
            guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                error = .signInFailed("Invalid callback URL")
                isLoading = false
                return
            }

            let params = Dictionary(
                uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
                    item.value.map { (item.name, $0) }
                }
            )

            if let oauthError = params["error"] {
                error = .signInFailed(oauthError)
                isLoading = false
                return
            }

            guard let accessToken = params["access_token"], !accessToken.isEmpty else {
                error = .signInFailed("No access token in callback")
                isLoading = false
                return
            }

            // Step 5: Build user from parameters
            let googleUser = GoogleUser(
                id: params["user_id"] ?? "",
                email: params["user_email"] ?? "",
                displayName: params["user_name"] ?? "",
                photoURL: params["user_picture"],
                accessToken: accessToken,
                refreshToken: params["refresh_token"]
            )

            // Step 6: Add or update account
            let isNewAccount: Bool
            if let existingIndex = storedUsers.firstIndex(where: { $0.email == googleUser.email }) {
                // Account already exists — update tokens
                storedUsers[existingIndex].accessToken = googleUser.accessToken
                if let newRefresh = googleUser.refreshToken {
                    storedUsers[existingIndex].refreshToken = newRefresh
                }
                isNewAccount = false
            } else {
                // New account — append
                storedUsers.append(googleUser)
                isNewAccount = true
            }

            currentUser = storedUsers.first
            isSignedIn = true
            persistAllUsers()
            rebuildAccounts()

            // Prompt for naming if this is a brand new account
            if isNewAccount {
                pendingNameAccount = googleUser.email
            }

        } catch {
            if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                self.error = nil
            } else {
                self.error = .signInFailed(error.localizedDescription)
            }
        }

        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        // Revoke all tokens (fire and forget)
        for user in storedUsers {
            Task {
                var request = URLRequest(url: URL(string: "\(backend.baseURL)/auth/revoke")!)
                request.httpMethod = "POST"
                request.addValue("Bearer \(user.accessToken)", forHTTPHeaderField: "Authorization")
                _ = try? await URLSession.shared.data(for: request)
            }
        }

        currentUser = nil
        storedUsers.removeAll()
        accounts.removeAll()
        isSignedIn = false
        error = nil

        // Clear persisted sessions
        UserDefaults.standard.removeObject(forKey: usersKey)
        UserDefaults.standard.removeObject(forKey: legacyUserKey)
    }

    /// Remove a specific account
    func removeAccount(email: String) {
        // Revoke token
        if let user = storedUsers.first(where: { $0.email == email }) {
            Task {
                var request = URLRequest(url: URL(string: "\(backend.baseURL)/auth/revoke")!)
                request.httpMethod = "POST"
                request.addValue("Bearer \(user.accessToken)", forHTTPHeaderField: "Authorization")
                _ = try? await URLSession.shared.data(for: request)
            }
        }

        storedUsers.removeAll { $0.email == email }

        if storedUsers.isEmpty {
            signOut()
        } else {
            currentUser = storedUsers.first
            persistAllUsers()
            rebuildAccounts()
        }
    }

    // MARK: - Refresh Token (Legacy Helper)

    func refreshTokenIfNeeded() async -> String? {
        return await getAccessToken()
    }

    /// Legacy compatibility — returns primary token
    func getAccessToken() async -> String? {
        return await getAccessToken(for: nil)
    }

    /// Legacy compatibility
    func refreshAccessToken() async -> String? {
        return await refreshAccessToken(for: nil)
    }
}

// MARK: - Web Auth Context Provider

private class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    let window: UIWindow

    init(window: UIWindow) {
        self.window = window
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return window
    }
}
