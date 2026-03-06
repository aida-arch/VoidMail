import SwiftUI

// MARK: - Void Mail · Monochrome Typography
// Massive uppercase display. Tight tracking. Industrial weight.

struct Typo {
    // MARK: Display — giant screen titles
    static let display   = Font.system(size: 64, weight: .heavy)
    static let title     = Font.system(size: 42, weight: .heavy)
    static let title2    = Font.system(size: 32, weight: .heavy)
    static let title3    = Font.system(size: 24, weight: .bold)

    // MARK: Body — 15px minimum for readability
    static let headline  = Font.system(size: 17, weight: .bold)
    static let body      = Font.system(size: 16, weight: .medium)
    static let subhead   = Font.system(size: 15, weight: .regular)
    static let meta      = Font.system(size: 15, weight: .medium)

    // MARK: Monospace — 15px minimum
    static let mono      = Font.system(size: 15, weight: .regular, design: .monospaced)
    static let monoSmall = Font.system(size: 15, weight: .regular, design: .monospaced)
}

// MARK: - Legacy alias so old files still compile
typealias VoidFont = Typo

extension Typo {
    static let largeTitle   = display
    static let bodyMedium   = body
    static let callout      = subhead
    static let subheadline  = subhead
    static let footnote     = subhead
    static let caption      = meta
    static let timestamp    = mono
}

// MARK: - View Modifiers

extension View {
    /// 64pt HEAVY uppercase — screen titles ("INBOX", "SYSTEM", etc.)
    func displayTitle() -> some View {
        self
            .font(Typo.display)
            .foregroundColor(.textPrimary)
            .textCase(.uppercase)
            .tracking(-2.5)
            .lineSpacing(-10)
    }

    /// 42pt heavy — secondary screen titles
    func screenTitle() -> some View {
        self
            .font(Typo.title)
            .foregroundColor(.textPrimary)
            .textCase(.uppercase)
            .tracking(-1.5)
    }

    /// 15pt mono uppercase — meta labels ("VOIDMAIL BY NEURAL ARC", "BUILD: 0.92")
    func metaLabel() -> some View {
        self
            .font(Typo.mono)
            .foregroundColor(.textTertiary)
            .textCase(.uppercase)
            .tracking(1.5)
    }

    /// 15pt medium uppercase tracking — section dividers
    func sectionLabel() -> some View {
        self
            .font(Typo.meta)
            .foregroundColor(.textTertiary)
            .textCase(.uppercase)
            .tracking(2)
    }

    /// 15pt monospace — timestamps
    func monoTimestamp() -> some View {
        self
            .font(Typo.mono)
            .foregroundColor(.textTertiary)
    }

    // Legacy modifiers
    func voidLargeTitle() -> some View { displayTitle() }
    func voidTitle() -> some View { screenTitle() }
    func voidHeadline() -> some View {
        self.font(Typo.headline).foregroundColor(.textPrimary)
    }
    func voidBody() -> some View {
        self.font(Typo.body).foregroundColor(.textPrimary)
    }
    func voidSecondary() -> some View {
        self.font(Typo.subhead).foregroundColor(.textSecondary)
    }
    func voidCaption() -> some View {
        self.font(Typo.meta).foregroundColor(.textTertiary)
    }
}
