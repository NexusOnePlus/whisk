import 'dart:io';
import 'package:flutter/material.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/domain/models/whisk_file.dart';
import 'package:whisk/ui/core/glass_panel.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

enum ProjectSidebarSection { files, diagnostics, comments, renders }

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.file,
    required this.files,
    required this.environment,
    required this.onOpenFile,
    required this.onNewFile,
    required this.onDeleteFile,
    this.section = ProjectSidebarSection.files,
  });

  final WhiskFile file;
  final List<WhiskFile> files;
  final EnvironmentKind environment;
  final ValueChanged<WhiskFile> onOpenFile;
  final ValueChanged<String> onNewFile;
  final ValueChanged<WhiskFile> onDeleteFile;
  final ProjectSidebarSection section;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: 0,
      opacity: 0.7,
      blur: 28,
      child: Container(
        width: 292,
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: kBorder)),
        ),
        child: Column(
          children: [
            _ProjectHeader(environment: environment, file: file),
            _SidebarNav(section: section),
            Expanded(
              child: _SidebarBody(
                section: section,
                environment: environment,
                file: file,
                files: files,
                onOpenFile: onOpenFile,
                onNewFile: onNewFile,
                onDeleteFile: onDeleteFile,
              ),
            ),
            const _SidebarStatus(),
          ],
        ),
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({required this.environment, required this.file});

  final EnvironmentKind environment;
  final WhiskFile file;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kGlassBase.withOpacity(0.4),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: kAccentBlue.withValues(alpha: 0.3)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kAccentBlue.withValues(alpha: 0.15), Colors.transparent],
              ),
            ),
            child: Icon(environment.icon, color: kAccentBlue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.projectRoot == null
                      ? '${environment.name} Draft'
                      : file.projectRoot!.split(Platform.pathSeparator).last,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  file.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kTextMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Collapse sidebar',
            onPressed: () {},
            icon: const Icon(Icons.keyboard_double_arrow_left),
            color: kTextSecondary,
          ),
        ],
      ),
    );
  }
}

class _SidebarNav extends StatelessWidget {
  const _SidebarNav({required this.section});

  final ProjectSidebarSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kAppBlack,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.folder_outlined,
            label: 'Files',
            tooltip: 'Files',
            active: section == ProjectSidebarSection.files,
          ),
          _NavButton(
            icon: Icons.bug_report_outlined,
            label: 'Diag',
            tooltip: 'Diagnostics',
            active: section == ProjectSidebarSection.diagnostics,
          ),
          _NavButton(
            icon: Icons.mode_comment_outlined,
            label: 'Comments',
            tooltip: 'Comments',
            active: section == ProjectSidebarSection.comments,
          ),
          _NavButton(
            icon: Icons.play_circle_outline,
            label: 'Runs',
            tooltip: 'Renders',
            active: section == ProjectSidebarSection.renders,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.active,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: active ? kGlassHighlight : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? kTextPrimary : kTextMuted),
              if (active || label == 'Comments') ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? kTextPrimary : kTextMuted,
                      fontSize: 9,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    ),
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

class _SidebarBody extends StatelessWidget {
  const _SidebarBody({
    required this.section,
    required this.environment,
    required this.file,
    required this.files,
    required this.onOpenFile,
    required this.onNewFile,
    required this.onDeleteFile,
  });

  final ProjectSidebarSection section;
  final EnvironmentKind environment;
  final WhiskFile file;
  final List<WhiskFile> files;
  final ValueChanged<WhiskFile> onOpenFile;
  final ValueChanged<String> onNewFile;
  final ValueChanged<WhiskFile> onDeleteFile;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      ProjectSidebarSection.files => _FilesSection(
        environment: environment,
        file: file,
        files: files,
        onOpenFile: onOpenFile,
        onNewFile: onNewFile,
        onDeleteFile: onDeleteFile,
      ),
      ProjectSidebarSection.diagnostics => const _EmptySection(
        icon: Icons.bug_report_outlined,
        title: 'No diagnostics',
        message: 'Render or analyze the active file to populate this panel.',
      ),
      ProjectSidebarSection.comments => const _EmptySection(
        icon: Icons.mode_comment_outlined,
        title: 'No comments',
        message: 'Comments will be scoped to the active file and selection.',
      ),
      ProjectSidebarSection.renders => const _EmptySection(
        icon: Icons.play_circle_outline,
        title: 'No renders yet',
        message: 'Render history and exported artifacts will appear here.',
      ),
    };
  }
}

class _FilesSection extends StatelessWidget {
  const _FilesSection({
    required this.environment,
    required this.file,
    required this.files,
    required this.onOpenFile,
    required this.onNewFile,
    required this.onDeleteFile,
  });

  final EnvironmentKind environment;
  final WhiskFile file;
  final List<WhiskFile> files;
  final ValueChanged<WhiskFile> onOpenFile;
  final ValueChanged<String> onNewFile;
  final ValueChanged<WhiskFile> onDeleteFile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionLabel('Files'),
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              tooltip: 'New file',
              color: kTextSecondary,
              onPressed: () => _handleNewFile(context),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const _SearchBox(),
        const SizedBox(height: 12),
        for (final projectFile in files)
          _FileRow(
            icon: _iconFor(projectFile),
            label: projectFile.name,
            detail: _detailFor(projectFile),
            selected: projectFile.path == file.path,
            onTap: () => onOpenFile(projectFile),
            onDelete: projectFile.projectRoot != null ? () => _handleDeleteFile(context, projectFile) : null,
          ),
      ],
    );
  }

  void _handleNewFile(BuildContext context) {
    showDialog<String>(
      context: context,
      builder: (context) => const GlassInputDialog(
        title: 'Create New File',
        hintText: 'filename.tex',
        confirmLabel: 'Create',
      ),
    ).then((fileName) {
      if (fileName != null && fileName.trim().isNotEmpty) {
        onNewFile(fileName.trim());
      }
    });
  }

  void _handleDeleteFile(BuildContext context, WhiskFile target) {
    showDialog<bool>(
      context: context,
      builder: (context) => GlassConfirmDialog(
        title: 'Delete File',
        message: 'Are you sure you want to delete ${target.name}? This action cannot be undone.',
        confirmLabel: 'Delete',
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        onDeleteFile(target);
      }
    });
  }

  IconData _iconFor(WhiskFile file) {
    if (file.isImage) return Icons.image_outlined;
    if (file.isPdf) return Icons.picture_as_pdf_outlined;
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

  String _detailFor(WhiskFile projectFile) {
    if (projectFile.projectRoot == null) return 'draft';
    final root = projectFile.projectRoot!;
    if (!projectFile.path.startsWith(root)) return projectFile.path;
    final relative = projectFile.path.substring(root.length);
    return relative.replaceFirst(RegExp(r'^[\\/]+'), '');
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: kGlassHighlight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.search, color: kTextMuted, size: 19),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Search project files',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: kTextMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.icon,
    required this.label,
    required this.detail,
    this.selected = false,
    this.onTap,
    this.onDelete,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          height: 54,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? kGlassHighlight : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: selected ? kBorder : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? kAccentBlue : kTextSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? kTextPrimary : kTextSecondary,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kTextMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  color: kTextMuted,
                  hoverColor: kDangerRed.withOpacity(0.1),
                  tooltip: 'Delete file',
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kTextMuted, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kTextPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTextSecondary, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: kTextMuted,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SidebarStatus extends StatelessWidget {
  const _SidebarStatus();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_done_outlined, color: kSuccessGreen, size: 17),
          SizedBox(width: 8),
          Text(
            'local draft',
            style: TextStyle(color: kTextSecondary, fontSize: 12),
          ),
          Spacer(),
          Icon(Icons.sync, color: kTextMuted, size: 15),
        ],
      ),
    );
  }
}

class GlassInputDialog extends StatelessWidget {
  const GlassInputDialog({
    super.key,
    required this.title,
    required this.hintText,
    required this.confirmLabel,
    this.initialValue = '',
  });

  final String title;
  final String hintText;
  final String confirmLabel;
  final String initialValue;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: initialValue);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
      child: GlassPanel(
        borderRadius: 16,
        opacity: 0.8,
        blur: 32,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: kTextPrimary, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hintText,
                  hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
                  filled: true,
                  fillColor: kGlassBase.withOpacity(0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kAccentBlue),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: kTextMuted, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(controller.text),
                    style: TextButton.styleFrom(
                      backgroundColor: kAccentBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: Text(confirmLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassConfirmDialog extends StatelessWidget {
  const GlassConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassPanel(
        borderRadius: 16,
        opacity: 0.8,
        blur: 32,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(color: kTextSecondary, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel', style: TextStyle(color: kTextMuted, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      backgroundColor: kDangerRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: Text(confirmLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
