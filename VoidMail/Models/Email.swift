import Foundation
import SwiftUI

// MARK: - Email Model

struct Email: Identifiable, Hashable {
    let id: String
    let threadId: String
    let from: Contact
    let to: [Contact]
    let cc: [Contact]
    let subject: String
    let snippet: String
    let body: String
    let date: Date
    var isRead: Bool
    var isStarred: Bool
    var isSnoozed: Bool
    var category: EmailCategory
    var labels: [String]
    let attachments: [Attachment]
    var aiSummary: String?
    var isAIPriority: Bool
    var accountEmail: String?  // Which account this email belongs to

    static func == (lhs: Email, rhs: Email) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Contact

struct Contact: Identifiable, Hashable {
    let id: String
    let name: String
    let email: String

    var displayName: String {
        name.isEmpty ? email : name
    }

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }
}

// MARK: - Email Category

enum EmailCategory: String, CaseIterable, Identifiable {
    case priority = "Priority"
    case updates = "Updates"
    case newsletters = "Newsletters"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .priority: return "bolt.fill"
        case .updates: return "bell.fill"
        case .newsletters: return "newspaper.fill"
        }
    }
}

// MARK: - Attachment

struct Attachment: Identifiable, Hashable {
    let id: String
    let name: String
    let mimeType: String
    let size: Int64
    let attachmentId: String?  // Gmail API attachment ID for downloading
    let messageId: String?     // Parent message ID for download URL

    init(id: String, name: String, mimeType: String, size: Int64, attachmentId: String? = nil, messageId: String? = nil) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.size = size
        self.attachmentId = attachmentId
        self.messageId = messageId
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var icon: String {
        if mimeType.contains("pdf") { return "doc.fill" }
        if mimeType.contains("image") { return "photo.fill" }
        if mimeType.contains("video") || mimeType.contains("mp4") { return "video.fill" }
        if mimeType.contains("audio") || mimeType.contains("mpeg") { return "waveform" }
        if mimeType.contains("spreadsheet") || mimeType.contains("csv") || mimeType.contains("excel") { return "tablecells.fill" }
        if mimeType.contains("word") || mimeType.contains("msword") || mimeType.contains("document") { return "doc.richtext.fill" }
        if mimeType.contains("presentation") || mimeType.contains("powerpoint") || mimeType.contains("pptx") { return "doc.text.image.fill" }
        if mimeType.contains("zip") || mimeType.contains("compressed") { return "doc.zipper" }
        if mimeType.contains("html") { return "globe" }
        if mimeType.contains("text/plain") || mimeType.contains("text") { return "doc.text.fill" }
        return "paperclip"
    }

    var isDownloadable: Bool {
        attachmentId != nil && messageId != nil
    }
}

// MARK: - Draft

struct Draft: Identifiable {
    let id: String
    var to: [Contact]
    var cc: [Contact]
    var bcc: [Contact]
    var subject: String
    var body: String
    var scheduledDate: Date?
    var replyToEmailId: String?
}

// MARK: - Swipe Action

enum SwipeAction: String {
    case archive = "Archive"
    case delete = "Delete"
    case snooze = "Snooze"
    case markRead = "Mark Read"
    case star = "Star"

    var icon: String {
        switch self {
        case .archive: return "archivebox.fill"
        case .delete: return "trash.fill"
        case .snooze: return "moon.fill"
        case .markRead: return "envelope.open.fill"
        case .star: return "star.fill"
        }
    }

    var color: SwiftUI.Color {
        switch self {
        case .archive: return .bgCardHover
        case .delete: return .accentPink
        case .snooze: return .accentSkyBlue
        case .markRead: return .accentGreen
        case .star: return .accentPink
        }
    }
}

