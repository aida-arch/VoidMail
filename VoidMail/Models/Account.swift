import Foundation
import SwiftUI

// MARK: - User Account

struct UserAccount: Identifiable, Hashable {
    let id: String
    let email: String
    let displayName: String
    let photoURL: URL?
    let provider: AccountProvider
    var isPrimary: Bool
    var label: String
    var colorTag: AccountColor

    var initials: String {
        let parts = displayName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }

    init(id: String, email: String, displayName: String, photoURL: URL?, provider: AccountProvider, isPrimary: Bool, label: String, colorTag: AccountColor = .skyBlue) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.provider = provider
        self.isPrimary = isPrimary
        self.label = label
        self.colorTag = colorTag
    }
}

// MARK: - Account Color Tag
// Users assign a color to each connected email account

enum AccountColor: String, CaseIterable, Identifiable, Codable, Hashable {
    case pink = "Pink"
    case green = "Green"
    case skyBlue = "Sky Blue"
    case yellow = "Yellow"
    case white = "White"

    var id: String { rawValue }

    var color: SwiftUI.Color {
        switch self {
        case .pink: return .accentPink
        case .green: return .accentGreen
        case .skyBlue: return .accentSkyBlue
        case .yellow: return .accentYellow
        case .white: return .textPrimary
        }
    }

    var icon: String {
        "circle.fill"
    }
}

// MARK: - Account Provider

enum AccountProvider: String, Hashable {
    case google = "Google"
    case imap = "IMAP"

    var icon: String {
        switch self {
        case .google: return "g.circle.fill"
        case .imap: return "envelope.circle.fill"
        }
    }
}

// MARK: - AI Alert

struct AIAlert: Identifiable {
    let id: String
    let type: AlertType
    let title: String
    let subtitle: String
    let emailId: String?
    let eventId: String?
    let date: Date

    enum AlertType {
        case awaitingReply
        case upcomingMeeting
        case followUp
        case newSender

        var icon: String {
            switch self {
            case .awaitingReply: return "exclamationmark.bubble.fill"
            case .upcomingMeeting: return "calendar.badge.clock"
            case .followUp: return "checkmark.circle.fill"
            case .newSender: return "person.badge.plus"
            }
        }

        var color: SwiftUI.Color {
            switch self {
            case .awaitingReply: return .accentPink
            case .upcomingMeeting: return .accentSkyBlue
            case .followUp: return .accentYellow
            case .newSender: return .accentYellow
            }
        }
    }
}
