import 'package:flutter/material.dart';
import 'package:whisk/ui/core/glass_panel.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:window_manager/window_manager.dart';

class WorkspaceRail extends StatelessWidget {
  const WorkspaceRail({super.key});

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: GlassPanel(
        borderRadius: 0,
        opacity: 0.9,
        blur: 40,
        child: Container(
          width: 74,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: kBorder)),
          ),
          child: Column(
            children: [
              const _RailMark(),
              const SizedBox(height: 18),
              const _RailDivider(),
              const SizedBox(height: 14),
              _RailButton(
                icon: Icons.home_outlined,
                tooltip: 'Home',
                selected: true,
                onPressed: () {},
              ),
              _RailButton(
                icon: Icons.dashboard_outlined,
                tooltip: 'Projects',
                onPressed: () {},
              ),
              _RailButton(
                icon: Icons.inventory_2_outlined,
                tooltip: 'Packages',
                onPressed: () {},
              ),
              _RailButton(
                icon: Icons.groups_2_outlined,
                tooltip: 'Friends',
                onPressed: () {},
              ),
              _RailButton(
                icon: Icons.feedback_outlined,
                tooltip: 'Feedback',
                onPressed: () {},
              ),
              const Spacer(),
              _RailButton(
                icon: Icons.help_outline,
                tooltip: 'Help',
                onPressed: () {},
              ),
              const SizedBox(height: 10),
              const _RailDivider(),
              const SizedBox(height: 10),
              _RailButton(
                icon: Icons.settings_outlined,
                tooltip: 'Settings',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailMark extends StatelessWidget {
  const _RailMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: kGlassHighlight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccentBlue.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: kAccentBlue.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Icon(Icons.auto_awesome, color: kAccentBlue, size: 22),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? kTextPrimary : kTextSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected ? kGlassHighlight : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? kBorder : Colors.transparent,
                ),
              ),
              child: Icon(icon, color: foreground, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailDivider extends StatelessWidget {
  const _RailDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 30, height: 1, color: kBorder);
  }
}
