import Foundation

// MARK: - Backend Service
// Centralized API client for the VoidMail Node.js backend.
// Handles all HTTP communication, token management, and response parsing.

@MainActor
class BackendService: ObservableObject {
    static let shared = BackendService()

    /// Base URL for the Node.js backend server, read from Info.plist (set via Config.xcconfig).
    let baseURL: String = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String ?? "https://void-mail.vercel.app"

    /// Whether to route API calls through the backend (true) or directly to Google APIs (false).
    /// When the backend is running, set this to true for production-grade auth flow.
    @Published var useBackend: Bool = false

    // MARK: - Auth Endpoints

    /// Gets the Google OAuth URL from the backend.
    func getAuthURL() async -> String? {
        guard let data = await get("/auth/google") else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["authUrl"] as? String
    }

    /// Exchanges an authorization code for tokens via the backend.
    func exchangeCode(_ code: String, redirectUri: String? = nil) async -> AuthTokenResponse? {
        var body: [String: Any] = ["code": code]
        if let uri = redirectUri { body["redirect_uri"] = uri }
        guard let data = await post("/auth/google/token", body: body) else { return nil }
        return try? JSONDecoder().decode(AuthTokenResponse.self, from: data)
    }

    /// Refreshes an expired access token via the backend.
    func refreshToken(_ refreshToken: String) async -> RefreshTokenResponse? {
        let body: [String: Any] = ["refresh_token": refreshToken]
        guard let data = await post("/auth/google/refresh", body: body) else { return nil }
        return try? JSONDecoder().decode(RefreshTokenResponse.self, from: data)
    }

    /// Gets the current user's profile.
    func getMe(token: String) async -> BackendUser? {
        guard let data = await get("/auth/me", token: token) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let user = json["user"] as? [String: Any] else { return nil }
        return BackendUser(
            id: user["id"] as? String ?? "",
            email: user["email"] as? String ?? "",
            name: user["name"] as? String ?? "",
            picture: user["picture"] as? String
        )
    }

    // MARK: - Gmail Endpoints

    /// Fetches inbox messages from the backend Gmail proxy.
    func fetchMessages(token: String, query: String? = nil, maxResults: Int = 20) async -> Data? {
        var path = "/api/gmail/messages?maxResults=\(maxResults)"
        if let q = query, !q.isEmpty {
            let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
            path += "&q=\(encoded)"
        }
        return await get(path, token: token)
    }

    /// Sends an email via the backend.
    func sendMessage(token: String, to: String, subject: String, body: String, replyToMessageId: String? = nil, threadId: String? = nil) async -> Bool {
        var payload: [String: Any] = [
            "to": to,
            "subject": subject,
            "body": body
        ]
        if let replyId = replyToMessageId { payload["replyToMessageId"] = replyId }
        if let tid = threadId { payload["threadId"] = tid }
        let data = await post("/api/gmail/messages/send", body: payload, token: token)
        return data != nil
    }

    /// Modify message labels (star, read, archive).
    func modifyMessage(token: String, messageId: String, addLabels: [String]? = nil, removeLabels: [String]? = nil) async -> Bool {
        var body: [String: Any] = [:]
        if let add = addLabels { body["addLabelIds"] = add }
        if let remove = removeLabels { body["removeLabelIds"] = remove }
        let data = await post("/api/gmail/messages/\(messageId)/modify", body: body, token: token)
        return data != nil
    }

    /// Trash a message.
    func deleteMessage(token: String, messageId: String) async -> Bool {
        let data = await delete("/api/gmail/messages/\(messageId)", token: token)
        return data != nil
    }

    // MARK: - Calendar Endpoints

    /// Fetches calendar events from the backend.
    func fetchEvents(token: String, timeMin: String? = nil, timeMax: String? = nil) async -> Data? {
        var path = "/api/calendar/events?"
        if let min = timeMin { path += "timeMin=\(min)&" }
        if let max = timeMax { path += "timeMax=\(max)&" }
        return await get(path, token: token)
    }

    /// Creates a calendar event via the backend.
    func createEvent(token: String, summary: String, start: String, end: String, conferenceRequest: Bool = false) async -> Data? {
        let body: [String: Any] = [
            "summary": summary,
            "start": start,
            "end": end,
            "conferenceRequest": conferenceRequest
        ]
        return await post("/api/calendar/events", body: body, token: token)
    }

    /// Gets today's events.
    func todayEvents(token: String) async -> Data? {
        return await get("/api/calendar/today", token: token)
    }

    // MARK: - Helix-o1 AI Endpoints

    /// Summarize an email via Helix-o1.
    func helixSummarize(subject: String, body: String, from: String) async -> String? {
        let payload: [String: Any] = ["subject": subject, "body": body, "from": from]
        guard let data = await post("/api/helix/summarize", body: payload) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["summary"] as? String
    }

    /// Generate an AI draft via Helix-o1.
    func helixDraft(context: String, replyTo: [String: Any]? = nil) async -> String? {
        var payload: [String: Any] = ["context": context]
        if let reply = replyTo { payload["replyTo"] = reply }
        guard let data = await post("/api/helix/draft", body: payload) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["draft"] as? String
    }

    /// Get smart reply suggestions via Helix-o1.
    func helixSmartReplies(from: String, subject: String, body: String) async -> [String] {
        let payload: [String: Any] = ["from": from, "subject": subject, "body": body]
        guard let data = await post("/api/helix/smart-replies", body: payload) else { return [] }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let replies = json["replies"] as? [String] else { return [] }
        return replies
    }

    /// Generate inbox digest via Helix-o1.
    func helixDigest(emails: [[String: Any]]) async -> String? {
        let payload: [String: Any] = ["emails": emails]
        guard let data = await post("/api/helix/digest", body: payload) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["digest"] as? String
    }

    /// Chat with Helix-o1.
    func helixChat(message: String, context: String? = nil) async -> String? {
        var payload: [String: Any] = ["message": message]
        if let ctx = context { payload["context"] = ctx }
        guard let data = await post("/api/helix/chat", body: payload) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["reply"] as? String
    }

    /// Check Helix-o1 AI status.
    func helixStatus() async -> Bool {
        guard let data = await get("/api/helix/status") else { return false }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return (json["status"] as? String) == "online"
    }

    // MARK: - Health Check

    func healthCheck() async -> Bool {
        guard let data = await get("/health") else { return false }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return (json["status"] as? String) == "ok"
    }

    // MARK: - HTTP Helpers

    private func get(_ path: String, token: String? = nil) async -> Data? {
        guard let url = URL(string: "\(baseURL)\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        if let t = token { request.addValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        return try? await URLSession.shared.data(for: request).0
    }

    private func post(_ path: String, body: [String: Any], token: String? = nil) async -> Data? {
        guard let url = URL(string: "\(baseURL)\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        if let t = token { request.addValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return try? await URLSession.shared.data(for: request).0
    }

    private func delete(_ path: String, token: String? = nil) async -> Data? {
        guard let url = URL(string: "\(baseURL)\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 15
        if let t = token { request.addValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        return try? await URLSession.shared.data(for: request).0
    }

    // MARK: - Response Models

    struct AuthTokenResponse: Codable {
        let user: BackendUser
        let tokens: Tokens

        struct Tokens: Codable {
            let access_token: String
            let refresh_token: String?
            let expiry_date: Int64?
            let token_type: String?
            let scope: String?
        }
    }

    struct RefreshTokenResponse: Codable {
        let tokens: Tokens

        struct Tokens: Codable {
            let access_token: String
            let expiry_date: Int64?
            let token_type: String?
        }
    }

    struct BackendUser: Codable {
        let id: String
        let email: String
        let name: String
        let picture: String?
    }
}
