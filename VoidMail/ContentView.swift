import SwiftUI

struct ContentView: View {
    @StateObject private var authService = GoogleAuthService.shared
    @StateObject private var notificationManager = InAppNotificationManager()
    @State private var selectedTab = 0
    @State private var showHelixO1 = false
    @State private var showCompose = false
    @State private var showCreateEvent = false
    @AppStorage("appearance_mode") private var appearanceMode: String = "dark"

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    // 4-icon nav: (outline, filled)
    private let navIcons: [(String, String)] = [
        ("envelope", "envelope.fill"),
        ("calendar", "calendar"),
        ("magnifyingglass", "magnifyingglass"),
        ("gearshape", "gearshape.fill")
    ]

    var body: some View {
        Group {
            if authService.isSignedIn {
                mainTabView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                OnboardingView(authService: authService)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .preferredColorScheme(colorScheme)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: authService.isSignedIn)
        .inAppNotificationBanner(manager: notificationManager) { emailId in
            selectedTab = 0 // Switch to inbox
        }
        .environmentObject(notificationManager)
    }

    // MARK: - Main Tab View

    private var mainTabView: some View {
        ZStack(alignment: .bottom) {
            Color.bgDeep.ignoresSafeArea()

            // Tab content with crossfade
            Group {
                switch selectedTab {
                case 0: InboxView()
                case 1: CalendarTabView(showCreateEvent: $showCreateEvent)
                case 2: SearchView()
                case 3: SettingsView(authService: authService)
                default: InboxView()
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)

            // Bottom bar: Nav Bar + FAB on same line
            HStack(alignment: .bottom, spacing: 10) {
                Spacer()

                // Floating Nav Bar
                BottomNavBar(selected: $selectedTab, icons: navIcons)

                // Context-aware FAB next to nav bar
                if selectedTab == 0 {
                    // Compose email FAB (pink)
                    MonochromeFAB { showCompose = true }
                        .padding(.bottom, 28)
                } else if selectedTab == 1 {
                    // Calendar entry FAB (sand)
                    MonochromeFAB(icon: "plus", bgColor: .accentSand) { showCreateEvent = true }
                        .padding(.bottom, 28)
                }
            }
            .padding(.trailing, 16)
        }
        .sheet(isPresented: $showCompose) {
            ComposeView()
        }
        .sheet(isPresented: $showHelixO1) {
            HelixO1View()
        }
    }
}
