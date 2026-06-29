import 'dart:async';

import 'package:flutter/material.dart';
import 'package:whisk/ui/core/glass_panel.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:window_manager/window_manager.dart';

class WindowTitleBar extends StatefulWidget {
  const WindowTitleBar({super.key});

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _slideAnim;
  Timer? _hideTimer;

  static const _pillWidth = 120.0;
  static const _triggerHeight = 5.0;
  static const _hoverZoneHeight = 52.0;
  static const _pillHeight = 38.0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnim = Tween<double>(begin: -_pillHeight, end: 12).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  void _onEnter() {
    _hideTimer?.cancel();
    _animCtrl.forward();
  }

  void _onExit() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 100), () {
      _animCtrl.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _pillWidth,
      height: _hoverZoneHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: MouseRegion(
                onEnter: (_) => _onEnter(),
                onExit: (_) => _onExit(),
                child: Container(
                  width: _pillWidth * 0.55,
                  height: _triggerHeight,
                  decoration: BoxDecoration(
                    color: kBorder.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                    border: Border(
                      left: BorderSide(
                        color: kBorder.withValues(alpha: 0.25),
                      ),
                      right: BorderSide(
                        color: kBorder.withValues(alpha: 0.25),
                      ),
                      bottom: BorderSide(
                        color: kBorder.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _slideAnim,
            builder: (context, _) {
              return Transform.translate(
                offset: Offset(0, _slideAnim.value),
                child: MouseRegion(
                  onEnter: (_) => _onEnter(),
                  onExit: (_) => _onExit(),
                  child: GlassPanel(
                    borderRadius: 999,
                    opacity: _animCtrl.isAnimating || _animCtrl.value > 0
                        ? 0.9
                        : 0.0,
                    blur: 24,
                    child: Container(
                      height: _pillHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: kBorder),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _WindowButton(
                              icon: Icons.remove,
                              tooltip: 'Minimize',
                              onPressed: windowManager.minimize,
                            ),
                            _WindowButton(
                              icon: Icons.crop_square,
                              tooltip: 'Maximize',
                              onPressed: () async {
                                if (await windowManager.isMaximized()) {
                                  await windowManager.unmaximize();
                                } else {
                                  await windowManager.maximize();
                                }
                              },
                            ),
                            _WindowButton(
                              icon: Icons.close,
                              tooltip: 'Close',
                              danger: true,
                              onPressed: windowManager.close,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 36,
            height: 34,
            child: Icon(
              icon,
              size: 16,
              color: danger ? const Color(0xFFFF6673) : kTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
