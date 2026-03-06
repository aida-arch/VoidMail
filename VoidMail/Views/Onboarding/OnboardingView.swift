import SwiftUI

// MARK: - Onboarding View  |  Dark Futuristic Terminal Aesthetic

struct OnboardingView: View {
    @ObservedObject var authService: GoogleAuthService

    // MARK: Entrance animation states
    @State private var showGrid = false
    @State private var showScanline = false
    @State private var showGlyphs = false
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showFeature0 = false
    @State private var showFeature1 = false
    @State private var showFeature2 = false
    @State private var showButton = false
    @State private var showFooter = false

    // MARK: Continuous animation states
    @State private var gridPhase: CGFloat = 0
    @State private var pulseScale: CGFloat = 1
    @State private var scanlineY: CGFloat = -100
    @State private var glitchOffset: CGFloat = 0
    @State private var glitchTimer: Timer?
    @State private var typewriterText = ""
    @State private var cursorVisible = true
    @State private var buttonPressed = false
    @State private var orbRotation: Double = 0
    @State private var circuitDash: CGFloat = 0

    private let fullTitle = "VOID"

    var body: some View {
        ZStack {
            // MARK: - Layer 0 — Deep background
            Color.bgDeep.ignoresSafeArea()

            // MARK: - Layer 1 — Animated circuit grid
            CircuitGridLayer(phase: gridPhase, show: showGrid)
                .ignoresSafeArea()

            // MARK: - Layer 2 — Horizontal scanline sweep
            ScanlineLayer(y: scanlineY, show: showScanline)
                .ignoresSafeArea()

            // MARK: - Layer 3 — Orbiting geometric glyphs
            GeometryReader { geo in
                let cx = geo.size.width / 2
                let cy = geo.size.height * 0.28
                OrbitalGlyphs(cx: cx, cy: cy, rotation: orbRotation, show: showGlyphs)
            }
            .ignoresSafeArea()

            // MARK: - Layer 4 — Content
            VStack(spacing: 0) {
                Spacer()

                // MARK: Title block
                VStack(spacing: 12) {
                    // Glitch typewriter title
                    ZStack {
                        // Shadow / echo layers for glitch
                        Text(typewriterText)
                            .font(Typo.display)
                            .tracking(-3)
                            .foregroundColor(.accentPink.opacity(0.4))
                            .offset(x: glitchOffset, y: -2)

                        Text(typewriterText)
                            .font(Typo.display)
                            .tracking(-3)
                            .foregroundColor(.accentSkyBlue.opacity(0.3))
                            .offset(x: -glitchOffset, y: 2)

                        // Main title
                        HStack(spacing: 0) {
                            Text(typewriterText)
                                .font(Typo.display)
                                .tracking(-3)
                                .foregroundColor(.textPrimary)

                            // Blinking cursor
                            Rectangle()
                                .fill(Color.accentGreen)
                                .frame(width: 4, height: 52)
                                .opacity(cursorVisible ? 1 : 0)
                                .offset(y: 2)
                        }
                    }
                    .opacity(showTitle ? 1 : 0)
                    .scaleEffect(showTitle ? 1 : 0.8)

                    // Subtitle with accent bar
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(Color.accentGreen)
                            .frame(width: 24, height: 2)
                            .scaleEffect(x: pulseScale, anchor: .leading)

                        Text("MAIL, SIMPLIFIED.")
                            .font(Typo.mono)
                            .foregroundColor(.textTertiary)
                            .tracking(3)

                        Rectangle()
                            .fill(Color.accentGreen)
                            .frame(width: 24, height: 2)
                            .scaleEffect(x: pulseScale, anchor: .trailing)
                    }
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 12)

                    // System tag
                    Text("SYS.BUILD" + " // " + "v1.0")
                        .font(Typo.mono)
                        .foregroundColor(.textTertiary.opacity(0.4))
                        .tracking(2)
                        .opacity(showSubtitle ? 1 : 0)
                        .padding(.top, 4)
                }

                Spacer()
                    .frame(height: 48)

                // MARK: Feature rows — staggered entrance
                VStack(spacing: 16) {
                    FeatureRow(
                        icon: "sparkles",
                        text: "AI-POWERED EMAIL TRIAGE",
                        color: .accentSkyBlue,
                        index: 0
                    )
                    .opacity(showFeature0 ? 1 : 0)
                    .offset(x: showFeature0 ? 0 : -40)

                    FeatureRow(
                        icon: "lock.shield.fill",
                        text: "PRIVACY FIRST. ALWAYS.",
                        color: .accentGreen,
                        index: 1
                    )
                    .opacity(showFeature1 ? 1 : 0)
                    .offset(x: showFeature1 ? 0 : -40)

                    FeatureRow(
                        icon: "calendar",
                        text: "UNIFIED CALENDAR BUILT IN",
                        color: .accentPink,
                        index: 2
                    )
                    .opacity(showFeature2 ? 1 : 0)
                    .offset(x: showFeature2 ? 0 : -40)
                }

                Spacer()
                    .frame(height: 40)

                // MARK: Sign-In Button
                VStack(spacing: 16) {
                    Button {
                        Task { await authService.signIn() }
                    } label: {
                        ZStack {
                            // Pulsing border glow
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.accentGreen.opacity(0.4), lineWidth: 2)
                                .scaleEffect(pulseScale * 1.02)
                                .blur(radius: 4)

                            // Button face
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.bgCard)

                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    LinearGradient(
                                        colors: [.accentGreen.opacity(0.8), .accentSkyBlue.opacity(0.5)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.5
                                )

                            HStack(spacing: 14) {
                                // Google "G" badge
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.white)
                                        .frame(width: 28, height: 28)
                                    Text("G")
                                        .font(.system(size: 16, weight: .heavy))
                                        .foregroundColor(.black)
                                }

                                Text("SIGN IN WITH GOOGLE")
                                    .font(Typo.headline)
                                    .foregroundColor(.textPrimary)
                                    .tracking(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .scaleEffect(buttonPressed ? 0.96 : 1.0)
                    }
                    .disabled(authService.isLoading)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                withAnimation(.easeInOut(duration: 0.1)) { buttonPressed = true }
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { buttonPressed = false }
                            }
                    )
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 24)
                }
                .padding(.horizontal, 28)

                // MARK: Loading state
                if authService.isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.accentGreen)
                        Text("ESTABLISHING LINK...")
                            .font(Typo.mono)
                            .foregroundColor(.accentGreen)
                            .tracking(2)
                    }
                    .padding(.top, 18)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // MARK: Error state
                if let error = authService.error {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.accentYellow)
                            .font(.system(size: 14))
                        Text(error.localizedDescription)
                            .font(Typo.mono)
                            .foregroundColor(.accentYellow)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
                    .transition(.opacity)
                }

                // MARK: Privacy footer
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 12))
                            .foregroundColor(.accentGreen.opacity(0.6))
                        Text("YOUR EMAILS NEVER LEAVE YOUR DEVICE.")
                            .font(Typo.mono)
                            .foregroundColor(.textTertiary)
                            .tracking(1)
                    }

                    Text("END-TO-END LOCAL PROCESSING")
                        .font(Typo.mono)
                        .foregroundColor(.textTertiary.opacity(0.4))
                        .tracking(1.5)
                }
                .opacity(showFooter ? 1 : 0)
                .padding(.top, 24)
                .padding(.bottom, 44)
            }
        }
        .onAppear(perform: startAnimations)
        .onDisappear { glitchTimer?.invalidate() }
    }

    // MARK: - Animation Orchestrator

    private func startAnimations() {
        // Phase 1: Grid and scanline
        withAnimation(.easeOut(duration: 1.0).delay(0.1)) {
            showGrid = true
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            showScanline = true
        }

        // Phase 2: Orbiting glyphs
        withAnimation(.spring(response: 0.9, dampingFraction: 0.6).delay(0.5)) {
            showGlyphs = true
        }

        // Phase 3: Title with typewriter
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.6)) {
            showTitle = true
        }
        startTypewriter(delay: 0.7)

        // Phase 4: Subtitle
        withAnimation(.easeOut(duration: 0.5).delay(1.4)) {
            showSubtitle = true
        }

        // Phase 5: Feature rows — staggered
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(1.6)) {
            showFeature0 = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(1.8)) {
            showFeature1 = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(2.0)) {
            showFeature2 = true
        }

        // Phase 6: Button and footer
        withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(2.3)) {
            showButton = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(2.6)) {
            showFooter = true
        }

        // MARK: Continuous loops
        // Grid scroll
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            gridPhase = 1
        }

        // Pulse breathing
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }

        // Scanline sweep
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false).delay(0.3)) {
            scanlineY = UIScreen.main.bounds.height + 100
        }

        // Orbital rotation
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            orbRotation = 360
        }

        // Cursor blink
        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            cursorVisible.toggle()
        }

        // Glitch effect
        startGlitchLoop()
    }

    // MARK: - Typewriter Effect

    private func startTypewriter(delay: Double) {
        let chars = Array(fullTitle)
        for (i, char) in chars.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + Double(i) * 0.15) {
                typewriterText.append(char)
            }
        }
    }

    // MARK: - Glitch Loop

    private func startGlitchLoop() {
        glitchTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            // Rapid glitch burst
            let burstCount = Int.random(in: 3...6)
            for i in 0..<burstCount {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                    withAnimation(.linear(duration: 0.03)) {
                        glitchOffset = CGFloat.random(in: -6...6)
                    }
                }
            }
            // Settle back
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(burstCount) * 0.05 + 0.05) {
                withAnimation(.easeOut(duration: 0.1)) {
                    glitchOffset = 0
                }
            }
        }
    }
}

// MARK: - Circuit Grid Background Layer

private struct CircuitGridLayer: View {
    let phase: CGFloat
    let show: Bool

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 40
            let cols = Int(size.width / spacing) + 2
            let rows = Int(size.height / spacing) + 2
            let offsetY = phase * spacing

            // Vertical lines
            for col in 0...cols {
                let x = CGFloat(col) * spacing
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.border.opacity(0.25)), lineWidth: 0.5)
            }

            // Horizontal lines with scroll
            for row in -1...rows {
                let y = CGFloat(row) * spacing + offsetY.truncatingRemainder(dividingBy: spacing)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.border.opacity(0.15)), lineWidth: 0.5)
            }

            // Circuit nodes at intersections
            for col in 0...cols {
                for row in -1...rows {
                    let x = CGFloat(col) * spacing
                    let y = CGFloat(row) * spacing + offsetY.truncatingRemainder(dividingBy: spacing)
                    // Only draw some nodes for a sparse circuit feel
                    let hash = (col * 7 + row * 13) % 5
                    if hash == 0 {
                        let rect = CGRect(x: x - 2, y: y - 2, width: 4, height: 4)
                        context.fill(Path(rect), with: .color(.accentGreen.opacity(0.2)))
                    } else if hash == 2 {
                        let rect = CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)
                        context.fill(Path(ellipseIn: rect), with: .color(.accentSkyBlue.opacity(0.15)))
                    }
                }
            }
        }
        .opacity(show ? 1 : 0)
    }
}

// MARK: - Scanline Sweep Layer

private struct ScanlineLayer: View {
    let y: CGFloat
    let show: Bool

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        .accentGreen.opacity(0.08),
                        .accentGreen.opacity(0.15),
                        .accentGreen.opacity(0.08),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 80)
            .position(x: UIScreen.main.bounds.width / 2, y: y)
            .opacity(show ? 1 : 0)
    }
}

// MARK: - Orbiting Geometric Glyphs

private struct OrbitalGlyphs: View {
    let cx: CGFloat
    let cy: CGFloat
    let rotation: Double
    let show: Bool

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.border.opacity(0.2), lineWidth: 0.5)
                .frame(width: 200, height: 200)
                .position(x: cx, y: cy)

            // Inner ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.accentGreen.opacity(0.15), .accentSkyBlue.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
                .frame(width: 140, height: 140)
                .position(x: cx, y: cy)

            // Orbiting shapes
            ForEach(0..<6, id: \.self) { i in
                let angle = Angle.degrees(rotation + Double(i) * 60)
                let radius: CGFloat = 100
                let x = cx + radius * CGFloat(cos(angle.radians))
                let y = cy + radius * CGFloat(sin(angle.radians))

                Group {
                    switch i % 3 {
                    case 0:
                        // Diamond
                        Rectangle()
                            .fill(Color.accentPink.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .rotationEffect(.degrees(45))
                    case 1:
                        // Small circle
                        Circle()
                            .fill(Color.accentSkyBlue.opacity(0.3))
                            .frame(width: 6, height: 6)
                    default:
                        // Crosshair
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .ultraLight))
                            .foregroundColor(.accentGreen.opacity(0.35))
                    }
                }
                .position(x: x, y: y)
            }

            // Center icon
            ZStack {
                // Breathing glow
                Circle()
                    .fill(Color.accentGreen.opacity(0.06))
                    .frame(width: 60, height: 60)

                Image(systemName: "envelope.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(.textPrimary.opacity(0.8))
            }
            .position(x: cx, y: cy)
        }
        .opacity(show ? 1 : 0)
        .scaleEffect(show ? 1 : 0.4)
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let text: String
    var color: Color = .textSecondary
    var index: Int = 0

    @State private var iconPulse: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 16) {
            // Accent line
            Rectangle()
                .fill(color.opacity(0.5))
                .frame(width: 3, height: 20)

            // Animated icon
            ZStack {
                // Glow behind icon
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                    .scaleEffect(iconPulse)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            .frame(width: 32)

            // Label
            Text(text)
                .font(Typo.mono)
                .foregroundColor(.textSecondary)
                .tracking(1)

            Spacer()
        }
        .padding(.horizontal, 32)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.4)
            ) {
                iconPulse = 1.3
            }
        }
    }
}
