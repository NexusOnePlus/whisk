import 'package:flutter/material.dart';
import 'package:whisk/domain/models/whisk_file.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class EditorTabBar extends StatelessWidget {
  const EditorTabBar({
    super.key,
    required this.file,
    required this.openFiles,
    required this.onSelectFile,
    this.onCloseFile,
  });

  final WhiskFile file;
  final List<WhiskFile> openFiles;
  final ValueChanged<WhiskFile> onSelectFile;
  final ValueChanged<WhiskFile>? onCloseFile;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            onClose: onCloseFile != null ? () => onCloseFile!(tabFile) : null,
          );
        },
      ),
    );
  }

  IconData _iconFor(WhiskFile file) {
    return switch (file.extension) {
      '.tex' => Icons.science_outlined,
      '.bib' => Icons.book_outlined,
      '.sty' || '.cls' => Icons.tune_outlined,
      '.typ' => Icons.code_outlined,
      '.md' => Icons.notes_outlined,
      '.mmd' => Icons.account_tree_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }
}

class FileTabPill extends StatefulWidget {
  const FileTabPill({
    super.key,
    required this.label,
    this.icon,
    this.active = false,
    this.accent,
    this.onTap,
    this.onClose,
  });

  final String label;
  final IconData? icon;
  final bool active;
  final Color? accent;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  @override
  State<FileTabPill> createState() => _FileTabPillState();
}

class _FileTabPillState extends State<FileTabPill> {
  var _hovering = false;

  @override
  Widget build(BuildContext context) {
    final onClose = widget.onClose;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: widget.onTap,
        child: Container(
          height: 26,
          constraints: const BoxConstraints(maxWidth: 180),
          padding: EdgeInsets.only(
            left: 10,
            right: onClose != null && _hovering ? 4 : 10,
          ),
          decoration: BoxDecoration(
            color: widget.active
                ? kGlassHighlight
                : kAppBlack.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.active ? (widget.accent ?? kBorder) : kBorder,
            ),
            gradient: widget.active
                ? LinearGradient(
                    colors: [
                      (widget.accent ?? kAccentBlue).withValues(alpha: 0.22),
                      kGlassBase,
                    ],
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: widget.accent ?? kTextSecondary, size: 14),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.active ? kTextPrimary : kTextSecondary,
                    fontSize: 12,
                    fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (onClose != null && _hovering) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: kGlassHighlight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.close, size: 12, color: kTextMuted),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
