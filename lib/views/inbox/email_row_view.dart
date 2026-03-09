import 'package:flutter/material.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/components.dart';
import '../../models/email.dart';

/// Email list row with swipe gestures, avatar, and indicators
class EmailRowView extends StatefulWidget {
  final Email email;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onSwipeLeft; // Delete
  final VoidCallback onSwipeRight; // Toggle read

  const EmailRowView({
    super.key,
    required this.email,
    required this.index,
    required this.onTap,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  @override
  State<EmailRowView> createState() => _EmailRowViewState();
}

class _EmailRowViewState extends State<EmailRowView>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _isDragging = false;
  late AnimationController _entranceController;
  late Animation<double> _entranceAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    // Staggered entrance
    Future.delayed(Duration(milliseconds: 50 * widget.index), () {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entranceAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(_entranceAnimation),
        child: GestureDetector(
          onHorizontalDragStart: (_) => setState(() => _isDragging = true),
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragOffset += details.primaryDelta ?? 0;
              _dragOffset = _dragOffset.clamp(-80.0, 80.0);
            });
          },
          onHorizontalDragEnd: (details) {
            if (_dragOffset > 80) {
              widget.onSwipeRight();
            } else if (_dragOffset < -80) {
              widget.onSwipeLeft();
            }
            setState(() {
              _dragOffset = 0;
              _isDragging = false;
            });
          },
          onTap: widget.onTap,
          child: Stack(
            children: [
              // Swipe action backgrounds
              _buildSwipeBackground(),

              // Email row content
              AnimatedContainer(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                transform: Matrix4.translationValues(_dragOffset, 0, 0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: VoidColors.bgEmailRow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar with account color bar
                      _buildAvatar(),
                      const SizedBox(width: 14),

                      // Email content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sender + timestamp row
                            Row(
                              children: [
                                if (!widget.email.isRead)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: UnreadDot(size: 6),
                                  ),
                                Expanded(
                                  child: Text(
                                    widget.email.from.displayName,
                                    style: widget.email.isRead
                                        ? Typo.body.copyWith(
                                            color: VoidColors.textSecondary,
                                          )
                                        : Typo.headline.copyWith(fontSize: 16),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  widget.email.relativeDate,
                                  style: Typo.monoSmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Subject
                            Text(
                              widget.email.subject,
                              style: Typo.body.copyWith(
                                fontSize: 15,
                                color: widget.email.isRead
                                    ? VoidColors.textSecondary
                                    : VoidColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),

                            // Snippet
                            Text(
                              widget.email.snippet,
                              style: Typo.subhead.copyWith(
                                fontSize: 14,
                                color: VoidColors.textTertiary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            // Indicators row
                            if (_hasIndicators) ...[
                              const SizedBox(height: 6),
                              _buildIndicators(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasIndicators =>
      widget.email.isStarred ||
      widget.email.attachments.isNotEmpty ||
      widget.email.aiSummary != null ||
      widget.email.isAIPriority;

  Widget _buildAvatar() {
    return Stack(
      children: [
        InitialsAvatar(
          name: widget.email.from.displayName,
          size: 44,
        ),
        // Account color indicator (left edge bar)
        if (widget.email.accountEmail != null)
          Positioned(
            left: -8,
            top: 8,
            bottom: 8,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: widget.email.isRead
                    ? VoidColors.accentPink
                    : VoidColors.accentYellow,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIndicators() {
    return Row(
      children: [
        if (widget.email.isStarred)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(
              Icons.star,
              size: 14,
              color: VoidColors.accentYellow,
            ),
          ),
        if (widget.email.attachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.attach_file,
                  size: 14,
                  color: VoidColors.textTertiary,
                ),
                Text(
                  '${widget.email.attachments.length}',
                  style: Typo.caption,
                ),
              ],
            ),
          ),
        if (widget.email.aiSummary != null)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(
              Icons.auto_awesome,
              size: 14,
              color: VoidColors.accentSkyBlue,
            ),
          ),
        if (widget.email.isAIPriority)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: VoidColors.accentPink.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'AI PRIORITY',
              style: Typo.caption.copyWith(
                fontSize: 10,
                color: VoidColors.accentPink,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSwipeBackground() {
    return Positioned.fill(
      child: Row(
        children: [
          // Right swipe - toggle read (sky blue)
          Expanded(
            child: Container(
              color: _dragOffset > 0
                  ? VoidColors.accentSkyBlue
                  : Colors.transparent,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 24),
              child: _dragOffset > 30
                  ? const Icon(
                      Icons.mark_email_read,
                      color: Colors.white,
                      size: 24,
                    )
                  : null,
            ),
          ),
          // Left swipe - delete (pink)
          Expanded(
            child: Container(
              color: _dragOffset < 0
                  ? VoidColors.accentPink
                  : Colors.transparent,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: _dragOffset < -30
                  ? const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 24,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
