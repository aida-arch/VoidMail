import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../services/auth_service.dart';

/// Terminal-aesthetic onboarding with circuit grid, scanlines, glitch effects
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _gridController;
  late AnimationController _scanlineController;
  late AnimationController _orbitController;
  late AnimationController _pulseController;

  // Entrance states
  bool _showGrid = false;
  bool _showScanline = false;
  bool _showGlyphs = false;
  bool _showTitle = false;
  bool _showSubtitle = false;
  bool _showFeature0 = false;
  bool _showFeature1 = false;
  bool _showFeature2 = false;
  bool _showButton = false;
  bool _showFooter = false;

  // Typewriter
  String _displayedTitle = '';
  final String _fullTitle = 'VOID';
  bool _showCursor = true;
  Timer? _cursorTimer;

  // Glitch
  double _glitchOffset = 0;
  Timer? _glitchTimer;

  // Button press state
  bool _buttonPressed = false;

  @override
  void initState() {
    super.initState();

    // Grid scroll — 20 second loop
    _gridController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Scanline sweep — 4 second loop
    _scanlineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Orbiting glyphs — 30 second loop
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // Pulse breathing — 2.5 second reverse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    // Start cursor blink
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) setState(() => _showCursor = !_showCursor);
    });

    // Start animation sequence
    _startAnimations();
  }

  void _startAnimations() {
    // Phase 1: Grid and scanline
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _showGrid = true);
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showScanline = true);
    });

    // Phase 2: Orbiting glyphs
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showGlyphs = true);
    });

    // Phase 3: Title with typewriter
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showTitle = true);
    });
    _startTypewriter(delay: const Duration(milliseconds: 700));

    // Phase 4: Subtitle
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showSubtitle = true);
    });

    // Phase 5: Feature rows — staggered
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showFeature0 = true);
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _showFeature1 = true);
    });
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _showFeature2 = true);
    });

    // Phase 6: Button and footer
    Future.delayed(const Duration(milliseconds: 2300), () {
      if (mounted) setState(() => _showButton = true);
    });
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _showFooter = true);
    });

    // Start glitch loop
    _startGlitchLoop();
  }

  void _startTypewriter({required Duration delay}) {
    final chars = _fullTitle.split('');
    for (int i = 0; i < chars.length; i++) {
      Future.delayed(delay + Duration(milliseconds: i * 150), () {
        if (mounted) {
          setState(() {
            _displayedTitle = _fullTitle.substring(0, i + 1);
          });
        }
      });
    }
  }

  void _startGlitchLoop() {
    _glitchTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final burstCount = 3 + Random().nextInt(4); // 3-6 bursts
      for (int i = 0; i < burstCount; i++) {
        Future.delayed(Duration(milliseconds: i * 50), () {
          if (mounted) {
            setState(() {
              _glitchOffset = (Random().nextDouble() * 12) - 6; // -6 to 6
            });
          }
        });
      }
      // Settle back
      Future.delayed(Duration(milliseconds: burstCount * 50 + 50), () {
        if (mounted) setState(() => _glitchOffset = 0);
      });
    });
  }

  @override
  void dispose() {
    _gridController.dispose();
    _scanlineController.dispose();
    _orbitController.dispose();
    _pulseController.dispose();
    _cursorTimer?.cancel();
    _glitchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: VoidColors.bgDeep,
      body: Stack(
        children: [
          // Layer 1 — Animated circuit grid
          AnimatedOpacity(
            opacity: _showGrid ? 1.0 : 0.0,
            duration: const Duration(seconds: 1),
            child: AnimatedBuilder(
              animation: _gridController,
              builder: (context, child) {
                return CustomPaint(
                  size: screenSize,
                  painter: _CircuitGridPainter(phase: _gridController.value),
                );
              },
            ),
          ),

          // Layer 2 — Scanline sweep
          AnimatedBuilder(
            animation: _scanlineController,
            builder: (context, child) {
              return Positioned(
                top: screenSize.height * _scanlineController.value - 40,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showScanline ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          VoidColors.accentGreen.withValues(alpha: 0.08),
                          VoidColors.accentGreen.withValues(alpha: 0.15),
                          VoidColors.accentGreen.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Layer 3 — Orbiting geometric glyphs
          AnimatedOpacity(
            opacity: _showGlyphs ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 900),
            child: AnimatedScale(
              scale: _showGlyphs ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutBack,
              child: _buildOrbitingGlyphs(screenSize),
            ),
          ),

          // Layer 4 — Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(),

                // Title block
                _buildTitleBlock(),

                const SizedBox(height: 48),

                // Feature rows
                _buildFeatureRow(
                  icon: Icons.auto_awesome,
                  text: 'AI-POWERED EMAIL TRIAGE',
                  color: VoidColors.accentSkyBlue,
                  isVisible: _showFeature0,
                  index: 0,
                ),
                const SizedBox(height: 16),
                _buildFeatureRow(
                  icon: Icons.lock,
                  text: 'PRIVACY FIRST. ALWAYS.',
                  color: VoidColors.accentGreen,
                  isVisible: _showFeature1,
                  index: 1,
                ),
                const SizedBox(height: 16),
                _buildFeatureRow(
                  icon: Icons.calendar_today,
                  text: 'UNIFIED CALENDAR BUILT IN',
                  color: VoidColors.accentPink,
                  isVisible: _showFeature2,
                  index: 2,
                ),

                const SizedBox(height: 40),

                // Sign-In Button
                _buildSignInButton(auth),

                // Loading state
                if (auth.isLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: VoidColors.accentGreen,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'ESTABLISHING LINK...',
                          style: Typo.mono.copyWith(
                            color: VoidColors.accentGreen,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Error state
                if (auth.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, left: 28, right: 28),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: VoidColors.accentYellow,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            auth.error!,
                            style: Typo.mono.copyWith(
                              color: VoidColors.accentYellow,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Privacy footer
                AnimatedOpacity(
                  opacity: _showFooter ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 44),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shield,
                              size: 12,
                              color: VoidColors.accentGreen.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'YOUR EMAILS NEVER LEAVE YOUR DEVICE.',
                              style: Typo.mono.copyWith(
                                fontSize: 11,
                                color: VoidColors.textTertiary,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'END-TO-END LOCAL PROCESSING',
                          style: Typo.mono.copyWith(
                            fontSize: 11,
                            color: VoidColors.textTertiary.withValues(alpha: 0.4),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Title block with glitch typewriter + subtitle + system tag
  Widget _buildTitleBlock() {
    return Column(
      children: [
        // Glitch typewriter title
        AnimatedOpacity(
          opacity: _showTitle ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 700),
          child: AnimatedScale(
            scale: _showTitle ? 1.0 : 0.8,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pink echo
                Transform.translate(
                  offset: Offset(_glitchOffset, -2),
                  child: Text(
                    _displayedTitle,
                    style: Typo.display.copyWith(
                      fontSize: 80,
                      letterSpacing: -3,
                      color: VoidColors.accentPink.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                // Blue echo
                Transform.translate(
                  offset: Offset(-_glitchOffset, 2),
                  child: Text(
                    _displayedTitle,
                    style: Typo.display.copyWith(
                      fontSize: 80,
                      letterSpacing: -3,
                      color: VoidColors.accentSkyBlue.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                // Main title with cursor
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _displayedTitle,
                      style: Typo.display.copyWith(
                        fontSize: 80,
                        letterSpacing: -3,
                        color: VoidColors.textPrimary,
                      ),
                    ),
                    // Blinking cursor
                    AnimatedOpacity(
                      opacity: _showCursor ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 50),
                      child: Container(
                        width: 4,
                        height: 52,
                        margin: const EdgeInsets.only(left: 2),
                        color: VoidColors.accentGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Subtitle with accent bars on both sides
        AnimatedOpacity(
          opacity: _showSubtitle ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: AnimatedSlide(
            offset: _showSubtitle ? Offset.zero : const Offset(0, 0.5),
            duration: const Duration(milliseconds: 500),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulseScale = 1.0 + (_pulseController.value * 0.15);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.scale(
                      scaleX: pulseScale,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 24,
                        height: 2,
                        color: VoidColors.accentGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'MAIL, SIMPLIFIED.',
                      style: Typo.mono.copyWith(
                        color: VoidColors.textTertiary,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Transform.scale(
                      scaleX: pulseScale,
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 24,
                        height: 2,
                        color: VoidColors.accentGreen,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 8),

        // System tag
        AnimatedOpacity(
          opacity: _showSubtitle ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: Text(
            'SYS.BUILD // v1.0',
            style: Typo.mono.copyWith(
              color: VoidColors.textTertiary.withValues(alpha: 0.4),
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }

  /// Orbiting geometric glyphs with center envelope
  Widget _buildOrbitingGlyphs(Size screenSize) {
    final cx = screenSize.width / 2;
    final cy = screenSize.height * 0.28;

    return AnimatedBuilder(
      animation: _orbitController,
      builder: (context, child) {
        final rotation = _orbitController.value * 2 * pi;

        return Stack(
          children: [
            // Outer ring
            Positioned(
              left: cx - 100,
              top: cy - 100,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: VoidColors.border.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
              ),
            ),

            // Inner ring with gradient
            Positioned(
              left: cx - 70,
              top: cy - 70,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: VoidColors.accentGreen.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                ),
              ),
            ),

            // 6 orbiting shapes
            ...List.generate(6, (i) {
              final angle = rotation + (i * pi / 3); // 60 degrees apart
              const radius = 100.0;
              final x = cx + radius * cos(angle);
              final y = cy + radius * sin(angle);

              Widget shape;
              switch (i % 3) {
                case 0:
                  // Diamond
                  shape = Transform.rotate(
                    angle: pi / 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      color: VoidColors.accentPink.withValues(alpha: 0.3),
                    ),
                  );
                  break;
                case 1:
                  // Small circle
                  shape = Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: VoidColors.accentSkyBlue.withValues(alpha: 0.3),
                    ),
                  );
                  break;
                default:
                  // Plus / crosshair
                  shape = Icon(
                    Icons.add,
                    size: 10,
                    color: VoidColors.accentGreen.withValues(alpha: 0.35),
                  );
              }

              return Positioned(
                left: x - 5,
                top: y - 5,
                child: shape,
              );
            }),

            // Center icon — breathing glow + envelope
            Positioned(
              left: cx - 30,
              top: cy - 30,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: VoidColors.accentGreen.withValues(alpha: 0.06),
                    ),
                    child: Icon(
                      Icons.mail,
                      size: 26,
                      color: VoidColors.textPrimary.withValues(alpha: 0.8),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Feature row matching reference: accent bar | icon glow | mono text
  Widget _buildFeatureRow({
    required IconData icon,
    required String text,
    required Color color,
    required bool isVisible,
    required int index,
  }) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      child: AnimatedSlide(
        offset: isVisible ? Offset.zero : const Offset(-0.15, 0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              // Accent line
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 16),
              // Icon with glow
              _FeatureIcon(icon: icon, color: color, index: index),
              const SizedBox(width: 16),
              // Label
              Expanded(
                child: Text(
                  text,
                  style: Typo.mono.copyWith(
                    color: VoidColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sign in button — dark card, gradient border, pulsing glow
  Widget _buildSignInButton(AuthService auth) {
    return AnimatedOpacity(
      opacity: _showButton ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 700),
      child: AnimatedSlide(
        offset: _showButton ? Offset.zero : const Offset(0, 0.3),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutBack,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _buttonPressed = true),
            onTapUp: (_) {
              setState(() => _buttonPressed = false);
              if (!auth.isLoading) auth.signInWithGoogle();
            },
            onTapCancel: () => setState(() => _buttonPressed = false),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulseScale = 1.0 + (_pulseController.value * 0.02);
                return Stack(
                  children: [
                    // Pulsing border glow
                    AnimatedScale(
                      scale: pulseScale,
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: VoidColors.accentGreen.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Button face
                    AnimatedScale(
                      scale: _buttonPressed ? 0.96 : 1.0,
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: VoidColors.bgCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: VoidColors.accentGreen.withValues(alpha: 0.8),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Google "G" badge
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Center(
                                child: Text(
                                  'G',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'SIGN IN WITH GOOGLE',
                              style: Typo.headline.copyWith(
                                color: VoidColors.textPrimary,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsing feature icon with glow background
class _FeatureIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final int index;

  const _FeatureIcon({
    required this.icon,
    required this.color,
    required this.index,
  });

  @override
  State<_FeatureIcon> createState() => _FeatureIconState();
}

class _FeatureIconState extends State<_FeatureIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    Future.delayed(Duration(milliseconds: widget.index * 400), () {
      if (mounted) _pulseController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.3);
        return SizedBox(
          width: 32,
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow circle
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.12),
                  ),
                ),
              ),
              // Icon
              Icon(
                widget.icon,
                size: 16,
                color: widget.color,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Circuit Grid Painter — sparse nodes, proper opacity levels
class _CircuitGridPainter extends CustomPainter {
  final double phase;

  _CircuitGridPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 40.0;
    final offsetY = phase * spacing;
    final cols = (size.width / spacing).ceil() + 2;
    final rows = (size.height / spacing).ceil() + 2;

    // Vertical lines — opacity 0.25
    final vPaint = Paint()
      ..color = VoidColors.border.withValues(alpha: 0.25)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int col = 0; col <= cols; col++) {
      final x = col * spacing;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), vPaint);
    }

    // Horizontal lines with scroll — opacity 0.15
    final hPaint = Paint()
      ..color = VoidColors.border.withValues(alpha: 0.15)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int row = -1; row <= rows; row++) {
      final y = row * spacing + (offsetY % spacing);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hPaint);
    }

    // Circuit nodes at intersections — sparse, hash-based
    final greenDotPaint = Paint()
      ..color = VoidColors.accentGreen.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final blueDotPaint = Paint()
      ..color = VoidColors.accentSkyBlue.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    for (int col = 0; col <= cols; col++) {
      for (int row = -1; row <= rows; row++) {
        final x = col * spacing;
        final y = row * spacing + (offsetY % spacing);
        final hash = (col * 7 + row * 13) % 5;
        if (hash == 0) {
          canvas.drawRect(
            Rect.fromCenter(center: Offset(x, y), width: 4, height: 4),
            greenDotPaint,
          );
        } else if (hash == 2) {
          canvas.drawCircle(Offset(x, y), 1.5, blueDotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitGridPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
