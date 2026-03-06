import SwiftUI

// MARK: - Screen Header
// Top of every screen: mono meta bar + massive display title

struct ScreenHeader: View {
    let metaLeft: String
    let metaRight: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(metaLeft)
                    .metaLabel()
                Spacer()
                Text(metaRight)
                    .metaLabel()
            }

            Text(title)
                .displayTitle()
                .padding(.top, -6)
        }
    }
}

// MARK: - Filter Chip Bar
// Horizontal row of bordered pills; active = white fill

struct FilterChipBar: View {
    let chips: [String]
    @Binding var selected: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips.indices, id: \.self) { i in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selected = i }
                    } label: {
                        Text(chips[i])
                            .font(Typo.meta)
                            .tracking(0.5)
                            .foregroundColor(selected == i ? .textInverse : .textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selected == i ? Color.textPrimary : Color.bgCard)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

// Legacy alias
typealias PillTabBar = FilterChipBar

extension FilterChipBar {
    init(tabs: [String], selected: Binding<Int>) {
        self.init(chips: tabs, selected: selected)
    }
}

// MARK: - Date Divider
// "TODAY" ———————————————

struct DateDivider: View {
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label.uppercased())
                .font(Typo.meta)
                .foregroundColor(.textTertiary)
                .tracking(2)
            Rectangle()
                .fill(Color.border)
                .frame(height: 1)
        }
    }
}

// MARK: - Section Divider

struct SectionDivider: View {
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label.uppercased())
                .sectionLabel()
            VStack { Divider().background(Color.border) }
        }
        .padding(.vertical, 4)
    }
}

// Legacy alias
typealias SectionHeader = SectionDivider

extension SectionDivider {
    init(title: String) {
        self.init(label: title)
    }
}

// MARK: - Mail Card (Void Card)
// Dark card with 8px radius, 20px padding

struct VoidCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(Color.bgCard)
            .cornerRadius(8)
    }
}

// MARK: - Monochrome FAB
// White rounded-square, dark icon

struct MonochromeFAB: View {
    let icon: String
    let bgColor: Color
    let action: () -> Void
    @State private var isPressed = false
    @State private var appeared = false

    init(icon: String = "plus", bgColor: Color = .accentPink, action: @escaping () -> Void) {
        self.icon = icon
        self.bgColor = bgColor
        self.action = action
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3)) {
                    isPressed = false
                }
                action()
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.bgDeep)
                .frame(width: 52, height: 52)
                .background(bgColor)
                .clipShape(Circle())
                .scaleEffect(isPressed ? 0.88 : 1.0)
        }
        .scaleEffect(appeared ? 1 : 0)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4)) {
                appeared = true
            }
        }
    }
}

// Legacy alias
typealias FloatingComposeButton = MonochromeFAB

extension MonochromeFAB {
    init(action: @escaping () -> Void) {
        self.init(icon: "plus", bgColor: .accentPink, action: action)
    }
}

// MARK: - Bottom Nav Bar
// Floating pill nav bar, centered at bottom

struct BottomNavBar: View {
    @Binding var selected: Int
    let icons: [(String, String)]
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(icons.indices, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { selected = i }
                } label: {
                    ZStack {
                        // Active background pill
                        if selected == i {
                            Capsule()
                                .fill(Color.textPrimary.opacity(0.12))
                                .matchedGeometryEffect(id: "navPill", in: navNamespace)
                        }

                        Image(systemName: selected == i ? icons[i].1 : icons[i].0)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.textPrimary)
                            .opacity(selected == i ? 1.0 : 0.4)
                            .scaleEffect(selected == i ? 1.05 : 1.0)
                    }
                    .frame(width: 56, height: 44)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.bgCard)
        )
        .padding(.bottom, 28)
        .scaleEffect(appeared ? 1 : 0.8)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
                appeared = true
            }
        }
    }

    @Namespace private var navNamespace
}

// MARK: - Initials Avatar
// Monospace initials in a square

struct InitialsAvatar: View {
    let name: String
    let size: CGFloat

    init(_ name: String, size: CGFloat = 40) {
        self.name = name
        self.size = size
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(Color.bgCardHover)
                .frame(width: size, height: size)
            Text(initials)
                .font(.system(size: size * 0.35, weight: .bold, design: .monospaced))
                .foregroundColor(.textPrimary)
        }
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }
}

// Legacy alias
typealias AvatarView = InitialsAvatar

// MARK: - Unread Dot

struct UnreadDot: View {
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(Color.accentGreen)
            .frame(width: 8, height: 8)
            .scaleEffect(pulsing ? 1.3 : 1.0)
            .opacity(pulsing ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                value: pulsing
            )
            .onAppear { pulsing = true }
    }
}

// MARK: - Toggle Row

struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.textSecondary)
                .frame(width: 28)
            Text(title)
                .font(Typo.body)
                .foregroundColor(.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(.accentGreen)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(Typo.meta)
            .foregroundColor(.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.bgCard)
            .clipShape(Capsule())
    }
}

// MARK: - Quote Block (email detail)

struct QuoteBlock: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.borderHighlight)
                .frame(width: 2)
            Text(text)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(.textSecondary)
                .lineSpacing(6)
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(.textTertiary)
            Text(title.uppercased())
                .font(Typo.headline)
                .foregroundColor(.textPrimary)
                .tracking(1)
            Text(subtitle)
                .font(Typo.subhead)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Void Divider

struct VoidDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.border)
            .frame(height: 1)
    }
}

// MARK: - Void Button

struct VoidButton: View {
    let title: String
    let icon: String?
    let style: Style
    let action: () -> Void

    enum Style { case primary, secondary, ghost }

    init(_ title: String, icon: String? = nil, style: Style = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(Typo.body)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(Capsule())
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return .textPrimary
        case .secondary: return .bgCard
        case .ghost: return .clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .textInverse
        case .secondary: return .textPrimary
        case .ghost: return .textSecondary
        }
    }

}

// MARK: - AI Summary Card

struct AISummaryCard: View {
    let summary: String
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(.accentSkyBlue)
                    Text("AI SUMMARY")
                        .font(Typo.meta)
                        .foregroundColor(.accentSkyBlue)
                        .tracking(1)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                }
            }

            if isExpanded {
                Text(summary)
                    .font(Typo.subhead)
                    .foregroundColor(.textSecondary)
                    .lineSpacing(4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(Color.bgCard)
        .cornerRadius(8)
    }
}

// MARK: - Shimmer Loading

struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [.bgSurface, .bgCard, .bgSurface]),
            startPoint: .init(x: phase - 0.5, y: 0.5),
            endPoint: .init(x: phase + 0.5, y: 0.5)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 1.5
            }
        }
    }
}
