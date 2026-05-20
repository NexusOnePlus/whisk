import 'package:flutter/material.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/domain/models/whisk_file.dart';
import 'package:whisk/ui/core/glass_panel.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.file,
    required this.openFiles,
    required this.environment,
    required this.onSelectFile,
    required this.onCloseWorkspace,
  });

  final WhiskFile file;
  final List<WhiskFile> openFiles;
  final EnvironmentKind environment;
  final ValueChanged<WhiskFile> onSelectFile;
  final VoidCallback onCloseWorkspace;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: 0,
      opacity: 0.8,
      blur: 32,
      child: Container(
        height: 52,
        padding: const EdgeInsets.fromLTRB(10, 4, 156, 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Close workspace',
              onPressed: onCloseWorkspace,
              icon: const Icon(Icons.arrow_back),
              color: kTextSecondary,
              iconSize: 20,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: openFiles.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tabFile = openFiles[index];
                  final active = tabFile.path == file.path;
                  return _FileTabPill(
                    icon: _iconFor(tabFile),
                    label: tabFile.isDirty ? '${tabFile.name} *' : tabFile.name,
                    active: active,
                    accent: active ? kAccentBlue : null,
                    onTap: () => onSelectFile(tabFile),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'New tab',
              onPressed: () {},
              icon: const Icon(Icons.add),
              color: kTextSecondary,
              iconSize: 19,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Split layout',
              onPressed: () {},
              icon: const Icon(Icons.view_column_outlined),
              color: kTextSecondary,
              iconSize: 19,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              tooltip: 'More',
              onPressed: () {},
              icon: const Icon(Icons.more_horiz),
              color: kTextSecondary,
              iconSize: 19,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(WhiskFile file) {
    return switch (file.extension) {
      '.tex' => environment.icon,
      '.bib' => Icons.book_outlined,
      '.sty' || '.cls' => Icons.tune_outlined,
      '.typ' => Icons.description_outlined,
      '.md' => Icons.notes_outlined,
      '.mmd' => Icons.account_tree_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }
}

class _FileTabPill extends StatelessWidget {
  const _FileTabPill({
    required this.label,
    this.icon,
    this.active = false,
    this.accent,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool active;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 25,
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: active ? kGlassHighlight : kAppBlack.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? (accent ?? kBorder) : kBorder),
          gradient: active
              ? LinearGradient(
                  colors: [
                    (accent ?? kAccentBlue).withValues(alpha: 0.22),
                    kGlassBase,
                  ],
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: accent ?? kTextSecondary, size: 13),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? kTextPrimary : kTextSecondary,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.close,
              size: 12,
              color: active ? kTextSecondary : kTextMuted,
            ),
          ],
        ),
      ),
    );
  }
}
