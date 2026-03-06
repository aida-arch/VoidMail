import Foundation

// MARK: - Helix-o1 AI Service (powered by Gemini)
// Powers all AI features: summaries, drafts, smart replies, inbox digest

@MainActor
class GeminiService: ObservableObject {
    static let shared = GeminiService()

    private let apiKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String, !key.isEmpty else {
            fatalError("GEMINI_API_KEY not set in Info.plist — add it via Config.xcconfig")
        }
        return key
    }()
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    @Published var isProcessing = false

    // MARK: - Core API Call

    private func generateContent(prompt: String, maxTokens: Int = 500, temperature: Double = 0.7) async throws -> String {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": temperature,
                "maxOutputTokens": maxTokens,
                "topP": 0.95
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.apiError(httpResponse.statusCode, errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw GeminiError.parseError
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Email Summarization

    func summarizeEmail(subject: String, body: String, from: String) async -> String? {
        let prompt = """
        Summarize this email in 1-2 concise sentences. Focus on action items and key information. Be direct and brief.

        From: \(from)
        Subject: \(subject)
        Body:
        \(body.prefix(2000))

        Summary:
        """
        return try? await generateContent(prompt: prompt, maxTokens: 150, temperature: 0.3)
    }

    // MARK: - AI Draft Generation

    func generateDraft(
        context: String,
        replyTo: (from: String, subject: String, body: String)? = nil
    ) async -> String? {
        var prompt: String
        if let reply = replyTo {
            prompt = """
            Write a professional, concise email reply. Keep it natural and brief (3-5 sentences).

            Original email from \(reply.from):
            Subject: \(reply.subject)
            \(reply.body.prefix(1500))

            \(context.isEmpty ? "Write a thoughtful reply acknowledging the email." : "Additional context: \(context)")

            Write only the email body text. No subject line. Sign off as "Aniket".
            Reply:
            """
        } else {
            prompt = """
            Write a professional, concise email. Keep it natural and brief.

            Topic/Context: \(context.isEmpty ? "General professional email" : context)

            Write only the email body text. Sign off as "Aniket".
            Email:
            """
        }
        return try? await generateContent(prompt: prompt, maxTokens: 400, temperature: 0.7)
    }

    // MARK: - Smart Reply Suggestions

    func generateSmartReplies(to email: (from: String, subject: String, body: String)) async -> [String] {
        let prompt = """
        Given this email, suggest exactly 3 short reply options (1 sentence each, max 15 words).
        Format each on a new line, numbered 1. 2. 3.

        From: \(email.from)
        Subject: \(email.subject)
        \(email.body.prefix(1000))

        Replies:
        """
        guard let response = try? await generateContent(prompt: prompt, maxTokens: 150, temperature: 0.8) else {
            return []
        }
        return response.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { line in
                if let range = line.range(of: #"^\d+[\.\)]\s*"#, options: .regularExpression) {
                    return String(line[range.upperBound...])
                }
                return line
            }
            .prefix(3)
            .map { String($0) }
    }

    // MARK: - Inbox Digest

    func generateInboxDigest(emails: [(from: String, subject: String, snippet: String, isRead: Bool)]) async -> String? {
        let unread = emails.filter { !$0.isRead }.count
        let emailList = emails.prefix(10).enumerated().map { i, e in
            "\(i+1). From \(e.from): \"\(e.subject)\" — \(e.snippet.prefix(60))\(e.isRead ? "" : " [UNREAD]")"
        }.joined(separator: "\n")

        let prompt = """
        You are an AI email assistant. Write a brief inbox digest (3-4 sentences) for today.
        Highlight what needs attention, important action items, and any urgent messages.
        There are \(unread) unread emails out of \(emails.count) total.

        Recent emails:
        \(emailList)

        Today's digest:
        """
        return try? await generateContent(prompt: prompt, maxTokens: 200, temperature: 0.5)
    }

    // MARK: - Smart Categorization

    func categorizeEmail(subject: String, from: String, snippet: String) async -> String {
        let prompt = """
        Categorize this email into exactly one category. Reply with ONLY the category name.
        Categories: priority, updates, newsletters

        From: \(from)
        Subject: \(subject)
        Preview: \(snippet.prefix(200))

        Category:
        """
        guard let result = try? await generateContent(prompt: prompt, maxTokens: 20, temperature: 0.1) else {
            return "updates"
        }
        let lower = result.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower.contains("priority") { return "priority" }
        if lower.contains("newsletter") { return "newsletters" }
        return "updates"
    }

    // MARK: - Translate Email

    func translateEmail(body: String, to language: String) async -> String? {
        let prompt = """
        Translate the following email body to \(language). Keep the formatting and tone. Only output the translated text, no explanations.

        Email:
        \(body.prefix(3000))

        Translation:
        """
        return try? await generateContent(prompt: prompt, maxTokens: 1000, temperature: 0.3)
    }

    // MARK: - Generate Email Subject

    func generateEmailSubject(body: String) async -> String? {
        let prompt = """
        Generate a concise, professional email subject line for the following email body. Reply with ONLY the subject line, nothing else. Max 10 words.

        Email body:
        \(body.prefix(1500))

        Subject:
        """
        return try? await generateContent(prompt: prompt, maxTokens: 30, temperature: 0.5)
    }

    // MARK: - Check Email Priority

    func isEmailPriority(subject: String, from: String, snippet: String) async -> Bool {
        let prompt = """
        Is this email high priority or urgent? Reply with ONLY "yes" or "no".
        Consider: deadlines, action required, important decisions, urgent requests.

        From: \(from)
        Subject: \(subject)
        Preview: \(snippet.prefix(300))

        Priority:
        """
        guard let result = try? await generateContent(prompt: prompt, maxTokens: 10, temperature: 0.1) else {
            return false
        }
        return result.lowercased().contains("yes")
    }

    // MARK: - Errors

    enum GeminiError: LocalizedError {
        case invalidURL
        case networkError
        case apiError(Int, String)
        case parseError

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API URL"
            case .networkError: return "Network connection failed"
            case .apiError(let code, let msg): return "API error \(code): \(msg)"
            case .parseError: return "Failed to parse Gemini response"
            }
        }
    }
}
