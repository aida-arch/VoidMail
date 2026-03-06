import Foundation
import UIKit

// MARK: - Gmail API Service
// Interfaces with Gmail REST API using OAuth tokens from GoogleAuthService.
// Supports multi-account: fetches from all connected accounts and merges results.

@MainActor
class GmailService: ObservableObject {
    static let shared = GmailService()

    private let baseURL = "https://gmail.googleapis.com/gmail/v1/users/me"
    private let auth = GoogleAuthService.shared
    private let sound = SoundService.shared
    private let notifications = NotificationService.shared

    @Published var emails: [Email] = []
    @Published var isLoading = false
    @Published var isSyncing = false
    private var knownEmailIds: Set<String> = []

    /// Auto-refresh timer
    private var refreshTimer: Timer?
    private let autoRefreshInterval: TimeInterval = 45  // seconds

    /// In-app notification manager (set by ContentView via environmentObject)
    var inAppNotificationManager: InAppNotificationManager?

    // MARK: - Gmail API Response Models

    struct GmailListResponse: Codable {
        let messages: [MessageRef]?
        let nextPageToken: String?
        let resultSizeEstimate: Int?

        struct MessageRef: Codable {
            let id: String
            let threadId: String
        }
    }

    struct GmailMessageResponse: Codable {
        let id: String
        let threadId: String
        let labelIds: [String]?
        let snippet: String?
        let internalDate: String?
        let payload: Payload?

        struct Payload: Codable {
            let mimeType: String?
            let headers: [Header]?
            let body: Body?
            let parts: [Part]?
        }

        struct Header: Codable {
            let name: String
            let value: String
        }

        struct Body: Codable {
            let size: Int?
            let data: String?
            let attachmentId: String?
        }

        struct Part: Codable {
            let mimeType: String?
            let filename: String?
            let headers: [Header]?
            let body: Body?
            let parts: [Part]?
        }
    }

    struct ModifyRequest: Codable {
        let addLabelIds: [String]?
        let removeLabelIds: [String]?
    }

    // MARK: - Auto-Refresh

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: autoRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchEmails()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Fetch Emails (All Accounts)

    func fetchEmails(query: String? = nil) async {
        isLoading = true

        let accountTokens = auth.getAllAccountTokens()

        if accountTokens.isEmpty {
            // Fallback: try legacy single token
            if let token = await auth.getAccessToken() {
                await fetchEmailsForAccount(token: token, accountEmail: auth.currentUser?.email ?? "", query: query)
            }
            isLoading = false
            return
        }

        // Fetch from all accounts in parallel
        var allFetched: [Email] = []
        var newEmails: [(from: String, subject: String, snippet: String, id: String)] = []

        await withTaskGroup(of: [Email].self) { group in
            for (email, token) in accountTokens {
                group.addTask { [self] in
                    return await self.fetchEmailsForSingleAccount(token: token, accountEmail: email, query: query)
                }
            }

            for await accountEmails in group {
                allFetched.append(contentsOf: accountEmails)
            }
        }

        // Sort all emails by date (newest first)
        allFetched.sort { $0.date > $1.date }

        // Detect new emails for notifications
        if !knownEmailIds.isEmpty {
            for email in allFetched {
                if !knownEmailIds.contains(email.id) && !email.isRead {
                    newEmails.append((
                        from: email.from.displayName,
                        subject: email.subject,
                        snippet: email.snippet,
                        id: email.id
                    ))
                }
            }

            if !newEmails.isEmpty {
                notifications.notifyNewEmails(newEmails)
                sound.playReceiveSound()

                if let latest = newEmails.first {
                    inAppNotificationManager?.show(
                        senderName: latest.from,
                        subject: latest.subject,
                        snippet: latest.snippet,
                        emailId: latest.id
                    )
                }
            }
        }

        // Update
        knownEmailIds = Set(allFetched.map { $0.id })
        emails = allFetched

        isLoading = false

        // Run AI priority check in background
        Task {
            await checkAIPriority()
        }
    }

    /// Fetch emails for a single account (used in parallel)
    private nonisolated func fetchEmailsForSingleAccount(token: String, accountEmail: String, query: String?) async -> [Email] {
        let baseURL = "https://gmail.googleapis.com/gmail/v1/users/me"

        do {
            var urlString = "\(baseURL)/messages?maxResults=30"
            if let query = query, !query.isEmpty {
                let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
                urlString += "&q=\(encoded)"
            } else {
                urlString += "&q=in:inbox"
            }

            guard let listURL = URL(string: urlString) else { return [] }

            var listRequest = URLRequest(url: listURL)
            listRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (listData, listResponse) = try await URLSession.shared.data(for: listRequest)

            // Handle 401 — try token refresh on MainActor
            if let httpResp = listResponse as? HTTPURLResponse, httpResp.statusCode == 401 {
                let refreshedToken: String? = await {
                    await GoogleAuthService.shared.refreshAccessToken(for: accountEmail)
                }()
                if let newToken = refreshedToken {
                    listRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    let (retryData, _) = try await URLSession.shared.data(for: listRequest)
                    let retryList = try JSONDecoder().decode(GmailListResponse.self, from: retryData)
                    return await fetchMessageDetailsForAccount(retryList.messages ?? [], token: newToken, accountEmail: accountEmail)
                }
                return []
            }

            let listResult = try JSONDecoder().decode(GmailListResponse.self, from: listData)

            guard let messageRefs = listResult.messages else { return [] }

            return await fetchMessageDetailsForAccount(messageRefs, token: token, accountEmail: accountEmail)
        } catch {
            print("[GmailService] fetchEmails error for \(accountEmail): \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch message details for a list of refs, tagging with account email
    private nonisolated func fetchMessageDetailsForAccount(_ refs: [GmailListResponse.MessageRef], token: String, accountEmail: String) async -> [Email] {
        var fetchedEmails: [Email] = []

        for ref in refs {
            if var email = try? await fetchMessageDetail(id: ref.id, threadId: ref.threadId, token: token) {
                email.accountEmail = accountEmail
                fetchedEmails.append(email)
            }
        }

        return fetchedEmails
    }

    /// Legacy single-account fetch (fallback)
    private func fetchEmailsForAccount(token: String, accountEmail: String, query: String?) async {
        let fetched = await fetchEmailsForSingleAccount(token: token, accountEmail: accountEmail, query: query)

        var newEmails: [(from: String, subject: String, snippet: String, id: String)] = []
        for email in fetched {
            if !knownEmailIds.contains(email.id) && !email.isRead {
                newEmails.append((from: email.from.displayName, subject: email.subject, snippet: email.snippet, id: email.id))
            }
        }

        if !knownEmailIds.isEmpty && !newEmails.isEmpty {
            notifications.notifyNewEmails(newEmails)
            sound.playReceiveSound()
            if let latest = newEmails.first {
                inAppNotificationManager?.show(senderName: latest.from, subject: latest.subject, snippet: latest.snippet, emailId: latest.id)
            }
        }

        knownEmailIds = Set(fetched.map { $0.id })
        emails = fetched

        Task { await checkAIPriority() }
    }

    // MARK: - AI Priority Check

    private func checkAIPriority() async {
        let gemini = GeminiService.shared
        for i in emails.indices {
            let email = emails[i]
            if !email.isRead && !email.isAIPriority {
                let isPriority = await gemini.isEmailPriority(
                    subject: email.subject,
                    from: email.from.displayName,
                    snippet: email.snippet
                )
                if isPriority {
                    emails[i].isAIPriority = true
                }
            }
        }
    }

    // MARK: - Fetch Single Message Detail

    private nonisolated func fetchMessageDetail(id: String, threadId: String, token: String) async throws -> Email? {
        let baseURL = "https://gmail.googleapis.com/gmail/v1/users/me"
        guard let url = URL(string: "\(baseURL)/messages/\(id)?format=full") else { return nil }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let msg = try JSONDecoder().decode(GmailMessageResponse.self, from: data)

        return parseGmailMessage(msg)
    }

    // MARK: - Send Email

    /// Send email from a specific account. If fromEmail is nil, uses the primary account.
    func sendEmail(to: [String], subject: String, body: String, replyToMessageId: String? = nil, fromEmail: String? = nil) async -> Bool {
        let senderEmail = fromEmail ?? auth.currentUser?.email ?? ""
        let toAddress = to.joined(separator: ", ")
        return await sendEmailRaw(to: toAddress, subject: subject, body: body, replyToMessageId: replyToMessageId, fromEmail: senderEmail)
    }

    private func sendEmailRaw(to: String, subject: String, body: String, replyToMessageId: String? = nil, fromEmail: String) async -> Bool {
        guard let token = await auth.getAccessToken(for: fromEmail) else { return false }

        do {
            let rawMIME = buildRawMIME(to: to, subject: subject, body: body, replyToMessageId: replyToMessageId, fromEmail: fromEmail)
            let base64Raw = base64URLEncode(rawMIME.data(using: .utf8) ?? Data())

            let payload: [String: String] = ["raw": base64Raw]
            let jsonData = try JSONSerialization.data(withJSONObject: payload)

            guard let url = URL(string: "\(baseURL)/messages/send") else { return false }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

            let (_, response) = try await URLSession.shared.data(for: request)
            let success = (response as? HTTPURLResponse)?.statusCode == 200
            if success {
                sound.playSendSound()
            }
            return success
        } catch {
            print("[GmailService] sendEmail error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Download Attachment

    func downloadAttachment(messageId: String, attachmentId: String, accountEmail: String? = nil) async -> Data? {
        guard let token = await auth.getAccessToken(for: accountEmail) else { return nil }

        do {
            let urlString = "\(baseURL)/messages/\(messageId)/attachments/\(attachmentId)"
            guard let url = URL(string: urlString) else { return nil }

            var request = URLRequest(url: url)
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, _) = try await URLSession.shared.data(for: request)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let base64Data = json["data"] as? String else { return nil }

            return base64URLDecodeData(base64Data)
        } catch {
            print("[GmailService] downloadAttachment error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Send Email with Attachments

    func sendEmailWithAttachments(to: [String], subject: String, body: String, attachments: [(data: Data, filename: String, mimeType: String)], replyToMessageId: String? = nil, fromEmail: String? = nil) async -> Bool {
        let senderEmail = fromEmail ?? auth.currentUser?.email ?? ""
        guard let token = await auth.getAccessToken(for: senderEmail) else { return false }

        do {
            let boundary = "VoidMail_\(UUID().uuidString)"
            let toAddress = to.joined(separator: ", ")

            var mimeBody = ""
            mimeBody += "From: \(senderEmail)\r\n"
            mimeBody += "To: \(toAddress)\r\n"
            mimeBody += "Subject: \(subject)\r\n"
            mimeBody += "MIME-Version: 1.0\r\n"
            if let replyTo = replyToMessageId {
                mimeBody += "In-Reply-To: \(replyTo)\r\n"
                mimeBody += "References: \(replyTo)\r\n"
            }
            mimeBody += "Content-Type: multipart/mixed; boundary=\"\(boundary)\"\r\n"
            mimeBody += "\r\n"

            // Text body part
            mimeBody += "--\(boundary)\r\n"
            mimeBody += "Content-Type: text/plain; charset=\"UTF-8\"\r\n"
            mimeBody += "Content-Transfer-Encoding: 7bit\r\n"
            mimeBody += "\r\n"
            mimeBody += body
            mimeBody += "\r\n"

            // Attachment parts
            for attachment in attachments {
                let base64Content = attachment.data.base64EncodedString()
                mimeBody += "--\(boundary)\r\n"
                mimeBody += "Content-Type: \(attachment.mimeType); name=\"\(attachment.filename)\"\r\n"
                mimeBody += "Content-Disposition: attachment; filename=\"\(attachment.filename)\"\r\n"
                mimeBody += "Content-Transfer-Encoding: base64\r\n"
                mimeBody += "\r\n"
                mimeBody += base64Content
                mimeBody += "\r\n"
            }

            mimeBody += "--\(boundary)--\r\n"

            let base64Raw = base64URLEncode(mimeBody.data(using: .utf8) ?? Data())

            let payload: [String: String] = ["raw": base64Raw]
            let jsonData = try JSONSerialization.data(withJSONObject: payload)

            guard let url = URL(string: "\(baseURL)/messages/send") else { return false }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

            let (_, response) = try await URLSession.shared.data(for: request)
            let success = (response as? HTTPURLResponse)?.statusCode == 200
            if success {
                sound.playSendSound()
            }
            return success
        } catch {
            print("[GmailService] sendEmailWithAttachments error: \(error.localizedDescription)")
            return false
        }
    }

    private func base64URLDecodeData(_ base64URL: String) -> Data? {
        var base64 = base64URL
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }

    // MARK: - Archive Email

    func archiveEmail(_ emailId: String) async {
        // Find which account owns this email
        let accountEmail = emails.first(where: { $0.id == emailId })?.accountEmail
        guard let token = await auth.getAccessToken(for: accountEmail) else { return }

        do {
            let modifyBody = ModifyRequest(addLabelIds: nil, removeLabelIds: ["INBOX"])
            let jsonData = try JSONEncoder().encode(modifyBody)

            guard let url = URL(string: "\(baseURL)/messages/\(emailId)/modify") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

            let _ = try await URLSession.shared.data(for: request)
            emails.removeAll { $0.id == emailId }
        } catch {
            print("[GmailService] archiveEmail error: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete Email (Trash)

    func deleteEmail(_ emailId: String) async {
        let accountEmail = emails.first(where: { $0.id == emailId })?.accountEmail
        guard let token = await auth.getAccessToken(for: accountEmail) else { return }

        do {
            guard let url = URL(string: "\(baseURL)/messages/\(emailId)/trash") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let _ = try await URLSession.shared.data(for: request)
            emails.removeAll { $0.id == emailId }
        } catch {
            print("[GmailService] deleteEmail error: \(error.localizedDescription)")
        }
    }

    // MARK: - Toggle Read/Unread

    func toggleRead(_ emailId: String) async {
        if let index = emails.firstIndex(where: { $0.id == emailId }) {
            emails[index].isRead.toggle()
        }

        let accountEmail = emails.first(where: { $0.id == emailId })?.accountEmail
        guard let token = await auth.getAccessToken(for: accountEmail) else { return }
        guard let email = emails.first(where: { $0.id == emailId }) else { return }

        do {
            let modifyBody: ModifyRequest
            if email.isRead {
                modifyBody = ModifyRequest(addLabelIds: nil, removeLabelIds: ["UNREAD"])
            } else {
                modifyBody = ModifyRequest(addLabelIds: ["UNREAD"], removeLabelIds: nil)
            }

            let jsonData = try JSONEncoder().encode(modifyBody)
            guard let url = URL(string: "\(baseURL)/messages/\(emailId)/modify") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

            let _ = try await URLSession.shared.data(for: request)
        } catch {
            print("[GmailService] toggleRead error: \(error.localizedDescription)")
        }
    }

    // MARK: - Toggle Star

    func toggleStar(_ emailId: String) async {
        if let index = emails.firstIndex(where: { $0.id == emailId }) {
            emails[index].isStarred.toggle()
        }

        let accountEmail = emails.first(where: { $0.id == emailId })?.accountEmail
        guard let token = await auth.getAccessToken(for: accountEmail) else { return }
        guard let email = emails.first(where: { $0.id == emailId }) else { return }

        do {
            let modifyBody: ModifyRequest
            if email.isStarred {
                modifyBody = ModifyRequest(addLabelIds: ["STARRED"], removeLabelIds: nil)
            } else {
                modifyBody = ModifyRequest(addLabelIds: nil, removeLabelIds: ["STARRED"])
            }

            let jsonData = try JSONEncoder().encode(modifyBody)
            guard let url = URL(string: "\(baseURL)/messages/\(emailId)/modify") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

            let _ = try await URLSession.shared.data(for: request)
        } catch {
            print("[GmailService] toggleStar error: \(error.localizedDescription)")
        }
    }

    // MARK: - Sync (Pull to Refresh)

    func sync() async {
        isSyncing = true
        await fetchEmails()
        isSyncing = false
    }

    // MARK: - Parse Gmail API Response

    private nonisolated func parseGmailMessage(_ msg: GmailMessageResponse) -> Email {
        let headers = msg.payload?.headers ?? []

        let subject = headerValue("Subject", in: headers) ?? "(No Subject)"
        let fromRaw = headerValue("From", in: headers) ?? ""
        let toRaw = headerValue("To", in: headers) ?? ""
        let ccRaw = headerValue("Cc", in: headers) ?? ""
        let dateString = headerValue("Date", in: headers)

        let fromContact = parseContact(fromRaw)
        let toContacts = toRaw.split(separator: ",").map { parseContact(String($0).trimmingCharacters(in: .whitespaces)) }
        let ccContacts = ccRaw.isEmpty ? [] : ccRaw.split(separator: ",").map { parseContact(String($0).trimmingCharacters(in: .whitespaces)) }

        var emailDate = Date()
        if let dateStr = dateString {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            emailDate = formatter.date(from: dateStr) ?? Date()
        } else if let internalDate = msg.internalDate, let millis = Double(internalDate) {
            emailDate = Date(timeIntervalSince1970: millis / 1000.0)
        }

        let bodyText = extractBodyText(from: msg.payload)
        let labels = msg.labelIds ?? []
        let isRead = !labels.contains("UNREAD")
        let isStarred = labels.contains("STARRED")

        let category: EmailCategory
        if labels.contains("IMPORTANT") || labels.contains("CATEGORY_PERSONAL") {
            category = .priority
        } else if labels.contains("CATEGORY_UPDATES") || labels.contains("CATEGORY_SOCIAL") {
            category = .updates
        } else if labels.contains("CATEGORY_PROMOTIONS") {
            category = .newsletters
        } else {
            category = .priority
        }

        var attachments: [Attachment] = []
        if let parts = msg.payload?.parts {
            attachments = extractAttachments(from: parts, messageId: msg.id)
        }

        return Email(
            id: msg.id,
            threadId: msg.threadId,
            from: fromContact,
            to: toContacts,
            cc: ccContacts,
            subject: subject,
            snippet: msg.snippet ?? "",
            body: bodyText,
            date: emailDate,
            isRead: isRead,
            isStarred: isStarred,
            isSnoozed: false,
            category: category,
            labels: labels,
            attachments: attachments,
            aiSummary: nil,
            isAIPriority: false,
            accountEmail: nil  // Set by caller
        )
    }

    private nonisolated func headerValue(_ name: String, in headers: [GmailMessageResponse.Header]) -> String? {
        return headers.first(where: { $0.name.lowercased() == name.lowercased() })?.value
    }

    private nonisolated func parseContact(_ raw: String) -> Contact {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        if let angleStart = trimmed.firstIndex(of: "<"),
           let angleEnd = trimmed.firstIndex(of: ">") {
            let name = String(trimmed[trimmed.startIndex..<angleStart]).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let email = String(trimmed[trimmed.index(after: angleStart)..<angleEnd])
            return Contact(id: email, name: name, email: email)
        }

        return Contact(id: trimmed, name: "", email: trimmed)
    }

    private nonisolated func extractBodyText(from payload: GmailMessageResponse.Payload?) -> String {
        guard let payload = payload else { return "" }

        if payload.mimeType == "text/plain", let data = payload.body?.data {
            return base64URLDecode(data) ?? ""
        }

        if let parts = payload.parts {
            for part in parts {
                if part.mimeType == "text/plain", let data = part.body?.data {
                    return base64URLDecode(data) ?? ""
                }
            }
            for part in parts {
                if part.mimeType == "text/html", let data = part.body?.data {
                    let html = base64URLDecode(data) ?? ""
                    return stripHTMLTags(html)
                }
            }
            for part in parts {
                if let nested = part.parts {
                    let nestedPayload = GmailMessageResponse.Payload(
                        mimeType: part.mimeType,
                        headers: part.headers,
                        body: part.body,
                        parts: nested
                    )
                    let result = extractBodyText(from: nestedPayload)
                    if !result.isEmpty { return result }
                }
            }
        }

        if let data = payload.body?.data {
            return base64URLDecode(data) ?? ""
        }

        return ""
    }

    private nonisolated func extractAttachments(from parts: [GmailMessageResponse.Part], messageId: String) -> [Attachment] {
        var result: [Attachment] = []
        for part in parts {
            if let filename = part.filename, !filename.isEmpty {
                result.append(Attachment(
                    id: UUID().uuidString,
                    name: filename,
                    mimeType: part.mimeType ?? "application/octet-stream",
                    size: Int64(part.body?.size ?? 0),
                    attachmentId: part.body?.attachmentId,
                    messageId: messageId
                ))
            }
            if let nested = part.parts {
                result.append(contentsOf: extractAttachments(from: nested, messageId: messageId))
            }
        }
        return result
    }

    private nonisolated func base64URLDecode(_ base64URL: String) -> String? {
        var base64 = base64URL
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func base64URLEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func buildRawMIME(to: String, subject: String, body: String, replyToMessageId: String?, fromEmail: String) -> String {
        var mime = ""
        mime += "From: \(fromEmail)\r\n"
        mime += "To: \(to)\r\n"
        mime += "Subject: \(subject)\r\n"
        mime += "MIME-Version: 1.0\r\n"
        mime += "Content-Type: text/plain; charset=\"UTF-8\"\r\n"
        if let replyTo = replyToMessageId {
            mime += "In-Reply-To: \(replyTo)\r\n"
            mime += "References: \(replyTo)\r\n"
        }
        mime += "\r\n"
        mime += body
        return mime
    }

    private nonisolated func stripHTMLTags(_ html: String) -> String {
        // Simple regex-based stripping for nonisolated context
        return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
