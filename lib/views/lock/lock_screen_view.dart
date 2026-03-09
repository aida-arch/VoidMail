import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';

class LockScreenView extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreenView({super.key, required this.onUnlocked});

  @override
  State<LockScreenView> createState() => _LockScreenViewState();
}

class _LockScreenViewState extends State<LockScreenView>
    with SingleTickerProviderStateMixin {
  static const String _correctPin = '1478';

  final LocalAuthentication _localAuth = LocalAuthentication();
  String _enteredPin = '';
  bool _isError = false;
  bool _biometricAvailable = false;
  bool _isFaceId = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
      }
    });
    // Small delay to let the UI render first, then check biometrics
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _checkBiometrics();
    });
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (canCheck && isDeviceSupported) {
        final availableBiometrics =
            await _localAuth.getAvailableBiometrics();
        if (mounted) {
          setState(() {
            _biometricAvailable = availableBiometrics.isNotEmpty;
            _isFaceId = availableBiometrics.contains(BiometricType.face);
          });
        }

        // Auto-trigger biometric seamlessly after UI is ready
        if (_biometricAvailable && mounted) {
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) _authenticateWithBiometric();
        }
      }
    } catch (e) {
      // Biometrics not available, PIN only
    }
  }

  Future<void> _authenticateWithBiometric() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access VoidMail',
        biometricOnly: true,
      );
      if (authenticated) {
        widget.onUnlocked();
      }
    } catch (e) {
      // Fall back to PIN
    }
  }

  void _onDigitPressed(String digit) {
    HapticFeedback.lightImpact();

    if (_enteredPin.length >= 4) return;

    setState(() {
      _isError = false;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _validatePin();
    }
  }

  void _onDeletePressed() {
    HapticFeedback.lightImpact();
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _isError = false;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _validatePin() {
    if (_enteredPin == _correctPin) {
      HapticFeedback.mediumImpact();
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward();
      setState(() {
        _isError = true;
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _enteredPin = '';
            _isError = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VoidColors.bgDeep,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Lock icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: VoidColors.bgSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isError
                          ? VoidColors.error.withValues(alpha: 0.5)
                          : VoidColors.border,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _isError ? Icons.lock_outline : Icons.lock_outline,
                    color: _isError
                        ? VoidColors.error
                        : VoidColors.textPrimary,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  'VOIDMAIL',
                  style: Typo.metaLabel.copyWith(
                    fontSize: 14,
                    letterSpacing: 6,
                    color: VoidColors.textTertiary,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Enter PIN',
                  style: Typo.headline.copyWith(
                    color: VoidColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 32),

                // PIN dots
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    final shake = _shakeAnimation.value;
                    final offset =
                        shake * 12 * (shake < 0.5 ? 1 : -1) * (1 - shake);
                    return Transform.translate(
                      offset: Offset(
                        offset *
                            20 *
                            ((_shakeController.value * 8).round().isOdd
                                ? 1
                                : -1),
                        0,
                      ),
                      child: child,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isFilled = index < _enteredPin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: isFilled ? 16 : 14,
                        height: isFilled ? 16 : 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isError
                              ? VoidColors.error
                              : isFilled
                                  ? VoidColors.textPrimary
                                  : Colors.transparent,
                          border: Border.all(
                            color: _isError
                                ? VoidColors.error
                                : isFilled
                                    ? VoidColors.textPrimary
                                    : VoidColors.border,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Error text
                const SizedBox(height: 16),
                AnimatedOpacity(
                  opacity: _isError ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    'Incorrect PIN',
                    style: Typo.caption.copyWith(
                      color: VoidColors.error,
                      fontSize: 13,
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // Number pad
                _buildNumberPad(),

                const SizedBox(height: 16),

                // Bottom row: biometric / 0 / delete
                _buildBottomRow(),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        _buildDigitRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildDigitRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildDigitRow(['7', '8', '9']),
      ],
    );
  }

  Widget _buildDigitRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((digit) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _PinButton(
            label: digit,
            onTap: () => _onDigitPressed(digit),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Biometric button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _biometricAvailable
              ? _PinButton(
                  icon: _isFaceId ? Icons.face : Icons.fingerprint,
                  onTap: _authenticateWithBiometric,
                )
              : const SizedBox(width: 72, height: 72),
        ),
        // 0
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _PinButton(
            label: '0',
            onTap: () => _onDigitPressed('0'),
          ),
        ),
        // Delete
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _PinButton(
            icon: Icons.backspace_outlined,
            onTap: _onDeletePressed,
            isSmallIcon: true,
          ),
        ),
      ],
    );
  }
}

class _PinButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isSmallIcon;

  const _PinButton({
    this.label,
    this.icon,
    required this.onTap,
    this.isSmallIcon = false,
  });

  @override
  State<_PinButton> createState() => _PinButtonState();
}

class _PinButtonState extends State<_PinButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isPressed
              ? VoidColors.bgCardHover
              : VoidColors.bgSurface,
          border: Border.all(
            color: _isPressed
                ? VoidColors.borderHighlight
                : VoidColors.border,
            width: 1,
          ),
        ),
        child: Center(
          child: widget.label != null
              ? Text(
                  widget.label!,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    color: VoidColors.textPrimary,
                    letterSpacing: 0,
                  ),
                )
              : Icon(
                  widget.icon,
                  color: VoidColors.textSecondary,
                  size: widget.isSmallIcon ? 22 : 28,
                ),
        ),
      ),
    );
  }
}
