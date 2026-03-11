import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

/// Screen Header - Meta label + massive display title
class ScreenHeader extends StatelessWidget {
  final String metaLabel;
  final String title;
  final List<Widget>? trailing;

  const ScreenHeader({
    super.key,
    required this.metaLabel,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                metaLabel.toUpperCase(),
                style: Typo.metaLabel,
              ),
              const Spacer(),
              if (trailing != null) ...trailing!,
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title.toUpperCase(),
            style: Typo.displayTitle,
          ),
        ],
      ),
    );
  }
}

/// Filter Chip Bar - Horizontal scrolling pill buttons
class FilterChipBar extends StatelessWidget {
  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelected;

  const FilterChipBar({
    super.key,
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isActive = filter == selected;
          return GestureDetector(
            onTap: () => onSelected(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? VoidColors.textPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isActive ? VoidColors.textPrimary : VoidColors.border,
                  width: 0.5,
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? VoidColors.textInverse
                      : VoidColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Date Divider - "TODAY" label with line
class DateDivider extends StatelessWidget {
  final String label;

  const DateDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: Typo.metaLabel.copyWith(fontSize: 11),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 0.5,
              color: VoidColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section Divider
class SectionDivider extends StatelessWidget {
  final String label;

  const SectionDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Typo.sectionLabel,
          ),
          const SizedBox(height: 8),
          Container(
            height: 0.5,
            color: VoidColors.border,
          ),
        ],
      ),
    );
  }
}

/// VoidCard - 8px radius, 20px padding card container
class VoidCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;

  const VoidCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color ?? VoidColors.bgCard,
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }
}

/// MonochromeFAB - Circular compose button with spring animations
class MonochromeFAB extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const MonochromeFAB({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<MonochromeFAB> createState() => _MonochromeFABState();
}

class _MonochromeFABState extends State<MonochromeFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _isVisible = true);
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              widget.icon,
              color: VoidColors.bgDeep,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom Nav Bar - Floating pill navigation with matched geometry
class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItem(Icons.mail_outline, Icons.mail, 'Inbox'),
    _NavItem(Icons.calendar_month_outlined, Icons.calendar_month, 'Calendar'),
    _NavItem(Icons.search_outlined, Icons.search, 'Search'),
    _NavItem(Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: VoidColors.bgCard,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_items.length, (index) {
          return _buildNavItem(index);
        }),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final item = _items[index];
    final isSelected = index == selectedIndex;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 25 : 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? VoidColors.textPrimary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Transform.scale(
            scale: isSelected ? 1.05 : 1.0,
            child: Icon(
              isSelected ? item.activeIcon : item.icon,
              key: ValueKey('${item.label}_$isSelected'),
              color: isSelected
                  ? VoidColors.textPrimary
                  : VoidColors.textPrimary.withValues(alpha: 0.4),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem(this.icon, this.activeIcon, this.label);
}

/// Initials Avatar - Rounded square with monospace initials
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? backgroundColor;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.backgroundColor,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? VoidColors.bgDeep,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
            color: VoidColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Unread Dot - Pulsing green indicator
class UnreadDot extends StatefulWidget {
  final double size;

  const UnreadDot({super.key, this.size = 8});

  @override
  State<UnreadDot> createState() => _UnreadDotState();
}

class _UnreadDotState extends State<UnreadDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_controller.value * 0.3),
          child: Opacity(
            opacity: 1.0 - (_controller.value * 0.3),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: const BoxDecoration(
                color: VoidColors.accentGreen,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Toggle Row - Icon + label + toggle switch
class ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ToggleRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: VoidColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Typo.body),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Tag Chip - Small label pills
class TagChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isActive;

  const TagChip({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? VoidColors.textPrimary : VoidColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? VoidColors.textPrimary : VoidColors.border,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isActive
                    ? VoidColors.textInverse
                    : VoidColors.textSecondary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? VoidColors.textInverse
                    : VoidColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quote Block - Left border + italic text
class QuoteBlock extends StatelessWidget {
  final String text;

  const QuoteBlock({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: VoidColors.border,
            width: 3,
          ),
        ),
      ),
      child: Text(
        text,
        style: Typo.body.copyWith(
          fontStyle: FontStyle.italic,
          color: VoidColors.textSecondary,
        ),
      ),
    );
  }
}

/// Empty State View
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: VoidColors.textTertiary),
          const SizedBox(height: 16),
          Text(title, style: Typo.headline),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Typo.subhead,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// VoidButton - Primary/secondary/ghost styles
enum VoidButtonStyle { primary, secondary, ghost }

class VoidButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final VoidButtonStyle style;
  final IconData? icon;
  final bool isLoading;

  const VoidButton({
    super.key,
    required this.label,
    this.onTap,
    this.style = VoidButtonStyle.primary,
    this.icon,
    this.isLoading = false,
  });

  @override
  State<VoidButton> createState() => _VoidButtonState();
}

class _VoidButtonState extends State<VoidButton> {
  bool _isPressed = false;

  Color get _bgColor {
    switch (widget.style) {
      case VoidButtonStyle.primary:
        return VoidColors.textPrimary;
      case VoidButtonStyle.secondary:
        return VoidColors.bgCard;
      case VoidButtonStyle.ghost:
        return Colors.transparent;
    }
  }

  Color get _textColor {
    switch (widget.style) {
      case VoidButtonStyle.primary:
        return VoidColors.textInverse;
      case VoidButtonStyle.secondary:
        return VoidColors.textPrimary;
      case VoidButtonStyle.ghost:
        return VoidColors.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(24),
            border: widget.style == VoidButtonStyle.ghost
                ? Border.all(color: VoidColors.border)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading) ...[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _textColor,
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: _textColor),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AI Summary Card - Collapsible AI summary (matches reference)
class AISummaryCard extends StatefulWidget {
  final String? summary;

  const AISummaryCard({
    super.key,
    this.summary,
  });

  @override
  State<AISummaryCard> createState() => _AISummaryCardState();
}

class _AISummaryCardState extends State<AISummaryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoidColors.bgDeep,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: VoidColors.accentSkyBlue,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI SUMMARY',
                  style: Typo.metaLabel.copyWith(
                    color: VoidColors.accentSkyBlue,
                  ),
                ),
                const Spacer(),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: VoidColors.textTertiary,
                ),
              ],
            ),
          ),
          if (_isExpanded && widget.summary != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.summary!,
              style: Typo.subhead.copyWith(
                color: VoidColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shimmer View - Loading skeleton animation
class ShimmerLine extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLine({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
  });

  @override
  State<ShimmerLine> createState() => _ShimmerLineState();
}

class _ShimmerLineState extends State<ShimmerLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-0.5 + 2.0 * _controller.value, 0),
              colors: const [
                VoidColors.bgCard,
                VoidColors.bgCardHover,
                VoidColors.bgCard,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shimmer Email Row - Skeleton loader for email list
class ShimmerEmailRow extends StatelessWidget {
  const ShimmerEmailRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerLine(width: 40, height: 40, borderRadius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ShimmerLine(width: 120, height: 14),
                    const Spacer(),
                    ShimmerLine(width: 50, height: 12, borderRadius: 2),
                  ],
                ),
                const SizedBox(height: 8),
                const ShimmerLine(width: 200, height: 14),
                const SizedBox(height: 6),
                const ShimmerLine(width: double.infinity, height: 12),
                const SizedBox(height: 4),
                const ShimmerLine(width: 160, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// InAppNotificationBanner moved to lib/views/shared/in_app_notification_banner.dart
