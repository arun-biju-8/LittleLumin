import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/parent/parent_theme.dart';
import '../screens/parent/notifications_page.dart';

class GlobalHeader extends StatefulWidget implements PreferredSizeWidget {
  final BuildContext? context;
  final bool showBack;
  final ScrollController? scrollController;
  final VoidCallback? onLogoTap;
  final VoidCallback? onBellTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onBackTap;
  final String? title;

  const GlobalHeader({
    super.key,
    this.context,
    this.showBack = false,
    this.scrollController,
    this.onLogoTap,
    this.onBellTap,
    this.onAvatarTap,
    this.onBackTap,
    this.title,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  State<GlobalHeader> createState() => _GlobalHeaderState();
}

class _GlobalHeaderState extends State<GlobalHeader> {
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _attachScrollListener();
  }

  @override
  void didUpdateWidget(covariant GlobalHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      _attachScrollListener();
    }
  }

  void _attachScrollListener() {
    if (widget.scrollController != null) {
      widget.scrollController!.addListener(_onScroll);
      if (widget.scrollController!.hasClients) {
        _isScrolled = widget.scrollController!.offset > 20;
      }
    }
  }

  void _onScroll() {
    if (widget.scrollController != null && widget.scrollController!.hasClients) {
      final scrolled = widget.scrollController!.offset > 20;
      if (scrolled != _isScrolled) {
        setState(() {
          _isScrolled = scrolled;
        });
      }
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  void _handleLogoTap(BuildContext ctx) {
    if (widget.onLogoTap != null) {
      widget.onLogoTap!();
      return;
    }
    // Default navigate to Home
    try {
      Navigator.pushNamedAndRemoveUntil(ctx, '/home', (r) => false);
    } catch (_) {
      Navigator.of(ctx).popUntil((route) => route.isFirst);
    }
  }

  void _handleBellTap(BuildContext ctx) {
    if (widget.onBellTap != null) {
      widget.onBellTap!();
      return;
    }
    Navigator.push(
      ctx,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  void _handleAvatarTap(BuildContext ctx) {
    if (widget.onAvatarTap != null) {
      widget.onAvatarTap!();
      return;
    }
    try {
      Navigator.pushNamed(ctx, '/profile');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.context ?? context;
    final topPadding = MediaQuery.of(context).padding.top;
    final totalHeight = 64.0 + topPadding;
    String displayName = 'Parent';
    try {
      displayName = FirebaseAuth.instance.currentUser?.displayName ?? 'Parent';
    } catch (_) {
      displayName = 'Parent';
    }
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P';

    return AnimatedContainer(
      key: const ValueKey('global_header_container'),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      height: totalHeight,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: topPadding,
      ),
      decoration: BoxDecoration(
        color: _isScrolled ? Colors.white : Colors.transparent,
        boxShadow: _isScrolled
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : const [],
      ),
      child: SizedBox(
        height: 64,
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Back button (optional) + Logo + LittleLumin title
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showBack) ...[
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: ParentColors.textPrimary,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () {
                        if (widget.onBackTap != null) {
                          widget.onBackTap!();
                        } else {
                          Navigator.pop(ctx);
                        }
                      },
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),
                  ],
                  GestureDetector(
                    onTap: () => _handleLogoTap(ctx),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Small Celestial Logo
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: ParentColors.primaryGradient,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.title ?? 'LittleLumin',
                          style: ParentTypography.title.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ParentColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Right: Notification Bell with Badge + Parent Avatar
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Bell Icon with badge
                  IconButton(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications_none_rounded,
                          color: ParentColors.textPrimary,
                          size: 24,
                        ),
                        Positioned(
                          right: 1,
                          top: 1,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: ParentColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    tooltip: 'Notifications',
                    onPressed: () => _handleBellTap(ctx),
                  ),
                  const SizedBox(width: 8),

                  // Parent Avatar
                  GestureDetector(
                    onTap: () => _handleAvatarTap(ctx),
                    child: Container(
                      width: 36,
                      height: 36,
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: ParentColors.primaryGradient,
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: ParentColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
    );
  }
}
