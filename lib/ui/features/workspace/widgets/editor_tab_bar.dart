import 'package:flutter/material.dart';
import 'package:whisk/domain/models/whisk_file.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class EditorTabBar extends StatelessWidget {
  const EditorTabBar({
    super.key,
    required this.file,
    required this.openFiles,
    required this.onSelectFile,
  });

  final WhiskFile file;
  final List<WhiskFile> openFiles;
  final ValueChanged<WhiskFile> onSelectFile;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: openFiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final tabFile = openFiles[index];
          final active = tabFile.path == file.path;
          return FileTabPill(
            icon: _iconFor(tabFile),
            label: tabFile.isDirty ? '${tabFile.name} *' : tabFile.name,
            active: active,
            accent: active ? kAccentBlue : null,
            onTap: () => onSelectFile(tabFile),
          );
        },
      ),
    );
  }

  IconData _iconFor(WhiskFile file) {
    return switch (file.extension) {
      '.tex' => Icons.functions,
      '.bib' => Icons.book_outlined,
      '.sty' || '.cls' => Icons.tune_outlined,
      '.typ' => Icons.description_outlined,
      '.md' => Icons.notes_outlined,
      '.mmd' => Icons.account_tree_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }
}

class FileTabPill extends StatelessWidget {
  const FileTabPill({
    super.key,
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
        height: 28,
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10),
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
              Icon(icon, color: accent ?? kTextSecondary, size: 14),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? kTextPrimary : kTextSecondary,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
