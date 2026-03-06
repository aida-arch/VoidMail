import SwiftUI

// MARK: - Void Mail · Dark Brutalist Color System
// Monochrome base with surgical accent colors.

extension Color {
    // MARK: Backgrounds
    static let bgDeep           = Color(hex: "121212")
    static let bgSurface        = Color(hex: "1E1E1E")
    static let bgCard           = Color(hex: "2A2A2A")
    static let bgCardHover      = Color(hex: "333333")
    static let bgEmailRow       = Color(hex: "222222")

    // MARK: Text
    static let textPrimary      = Color(hex: "E6E6E6")
    static let textSecondary    = Color(hex: "999999")
    static let textTertiary     = Color(hex: "666666")
    static let textInverse      = Color(hex: "121212")

    // MARK: Borders
    static let border           = Color(hex: "333333")
    static let borderHighlight  = Color(hex: "4D4D4D")

    // MARK: Accents
    static let accentPink       = Color(hex: "FF99CC")   // Priority, starred, urgent
    static let accentGreen      = Color(hex: "33CC33")   // Success, unread, active, confirmed
    static let accentSkyBlue    = Color(hex: "87CEEB")   // AI features, informational, pending
    static let accentYellow     = Color(hex: "FFFF00")   // Warnings, follow-ups, attention
    static let accentSand       = Color(hex: "DDD9C4")   // Calendar entry button

    // MARK: Legacy aliases
    static let voidBackground       = bgDeep
    static let voidSurface          = bgSurface
    static let voidSurfaceHover     = bgCardHover
    static let voidSurfaceElevated  = bgCard
    static let voidTextPrimary      = textPrimary
    static let voidTextSecondary    = textSecondary
    static let voidTextTertiary     = textTertiary
    static let voidAccent           = accentSkyBlue
    static let voidAccentSoft       = bgCard
    static let voidSuccess          = accentGreen
    static let voidWarning          = accentYellow
    static let voidError            = accentPink
    static let voidPurple           = accentPink
    static let voidOrange           = accentYellow
    static let voidDivider          = border
    static let voidBorder           = border
    static let categoryBlue         = accentSkyBlue
    static let categoryPurple       = accentPink
    static let categoryGreen        = accentGreen
    static let categoryOrange       = accentYellow
    static let categoryPink         = accentPink
    static let categoryYellow       = accentYellow
}

// MARK: - Hex Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
