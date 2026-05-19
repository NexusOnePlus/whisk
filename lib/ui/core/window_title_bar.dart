import 'package:flutter/material.dart';
import 'package:whisk/ui/core/glass_panel.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:window_manager/window_manager.dart';

class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: 999,
      opacity: 0.9,
      blur: 24,
      child: Container(
        height: 38,
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
            width: 42,
            height: 38,
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
