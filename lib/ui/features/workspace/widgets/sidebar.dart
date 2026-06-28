import 'package:flutter/material.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/domain/models/whisk_file.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/core/empty_section.dart';
import 'package:whisk/ui/core/glass_dialogs.dart';

enum ProjectSidebarSection { files, search, diagnostics }

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
    return Container(
      width: 260,
        child: Column(
          children: [
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
      ProjectSidebarSection.search => const _SearchSection(),
      ProjectSidebarSection.diagnostics => const EmptySection(
        icon: Icons.bug_report_outlined,
        title: 'No diagnostics',
        message: 'Render or analyze the active file to populate this panel.',
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
            onDelete: projectFile.projectRoot != null
                ? () => _handleDeleteFile(context, projectFile)
                : null,
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
        message:
            'Are you sure you want to delete ${target.name}? This action cannot be undone.',
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

class _SearchSection extends StatelessWidget {
  const _SearchSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            autofocus: true,
            style: const TextStyle(color: kTextPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search files...',
              hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: kTextMuted, size: 19),
              filled: true,
              fillColor: kGlassHighlight,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kAccentBlue),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, color: kTextMuted, size: 28),
                  SizedBox(height: 12),
                  Text(
                    'Search across all project files',
                    style: TextStyle(color: kTextMuted, fontSize: 12),
                  ),
                ],
              ),
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
                  hoverColor: kDangerRed.withValues(alpha: 0.1),
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


