import 'package:flutter/material.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.environment,
    required this.onCloseWorkspace,
  });

  final EnvironmentKind environment;
  final VoidCallback onCloseWorkspace;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.fromLTRB(12, 0, 156, 0),
      decoration: const BoxDecoration(
        color: kPanel,
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close workspace',
            onPressed: onCloseWorkspace,
            icon: const Icon(Icons.arrow_back),
            color: kTextSecondary,
          ),
          const SizedBox(width: 8),
          _FileTabPill(
            icon: environment.icon,
            label: 'main${environment.extension}',
            active: true,
            accent: kAccentBlue,
          ),
          const SizedBox(width: 8),
          const _FileTabPill(label: 'references.bib'),
          const SizedBox(width: 8),
          const _FileTabPill(label: 'diagram.mmd'),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'New tab',
            onPressed: () {},
            icon: const Icon(Icons.add),
            color: kTextSecondary,
          ),
          const Spacer(),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Split layout',
            onPressed: () {},
            icon: const Icon(Icons.view_column_outlined),
            color: kTextSecondary,
          ),
          IconButton(
            tooltip: 'More',
            onPressed: () {},
            icon: const Icon(Icons.more_horiz),
            color: kTextSecondary,
          ),
        ],
      ),
    );
  }
}

class _FileTabPill extends StatelessWidget {
  const _FileTabPill({
    required this.label,
    this.icon,
    this.active = false,
    this.accent,
  });

  final String label;
  final IconData? icon;
  final bool active;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: active ? kPanelRaised : kAppBlack,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? (accent ?? kBorder) : kBorder),
        gradient: active
            ? LinearGradient(
                colors: [
                  (accent ?? kAccentBlue).withValues(alpha: 0.22),
                  kPanelRaised,
                ],
              )
            : null,
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: accent ?? kTextSecondary, size: 15),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                color: active ? kTextPrimary : kTextSecondary,
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.close,
              size: 13,
              color: active ? kTextSecondary : kTextMuted,
            ),
          ],
        ),
      ),
    );
  }
}
