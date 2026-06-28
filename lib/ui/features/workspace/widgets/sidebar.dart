import 'dart:io';

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
    required this.onNewFolder,
    required this.onDeleteFile,
    this.section = ProjectSidebarSection.files,
  });

  final WhiskFile file;
  final List<WhiskFile> files;
  final EnvironmentKind environment;
  final ValueChanged<WhiskFile> onOpenFile;
  final ValueChanged<String> onNewFile;
  final ValueChanged<String> onNewFolder;
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
              onNewFolder: onNewFolder,
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
    required this.onNewFolder,
    required this.onDeleteFile,
  });

  final ProjectSidebarSection section;
  final EnvironmentKind environment;
  final WhiskFile file;
  final List<WhiskFile> files;
  final ValueChanged<WhiskFile> onOpenFile;
  final ValueChanged<String> onNewFile;
  final ValueChanged<String> onNewFolder;
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
        onNewFolder: onNewFolder,
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

class _FilesSection extends StatefulWidget {
  const _FilesSection({
    required this.environment,
    required this.file,
    required this.files,
    required this.onOpenFile,
    required this.onNewFile,
    required this.onNewFolder,
    required this.onDeleteFile,
  });

  final EnvironmentKind environment;
  final WhiskFile file;
  final List<WhiskFile> files;
  final ValueChanged<WhiskFile> onOpenFile;
  final ValueChanged<String> onNewFile;
  final ValueChanged<String> onNewFolder;
  final ValueChanged<WhiskFile> onDeleteFile;

  @override
  State<_FilesSection> createState() => _FilesSectionState();
}

class _FilesSectionState extends State<_FilesSection> {
  final Set<String> _expandedFolders = {};

  @override
  Widget build(BuildContext context) {
    final root = widget.files.isNotEmpty ? widget.files.first.projectRoot : null;
    final topFolders = widget.files.where((f) => f.isDirectory).toList();
    final rootFiles = widget.files.where((f) => !f.isDirectory).where((f) {
      if (root == null) return true;
      final relative = f.path.substring(root.length).replaceFirst(RegExp(r'^[\\/]'), '');
      return !relative.contains(Platform.pathSeparator);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionLabel('Files'),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'file') _handleNewFile(context);
                if (value == 'folder') _handleNewFolder(context);
              },
              offset: const Offset(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: kBorder),
              ),
              color: const Color(0xFF22262E),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'file',
                  height: 36,
                  child: Row(
                    children: [
                      Icon(Icons.note_add_outlined, size: 16, color: kTextSecondary),
                      SizedBox(width: 8),
                      Text('New File', style: TextStyle(color: kTextPrimary, fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'folder',
                  height: 36,
                  child: Row(
                    children: [
                      Icon(Icons.create_new_folder_outlined, size: 16, color: kTextSecondary),
                      SizedBox(width: 8),
                      Text('New Folder', style: TextStyle(color: kTextPrimary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
              child: IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'New',
                color: kTextSecondary,
                onPressed: null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const _SearchBox(),
        const SizedBox(height: 12),
        for (final folder in topFolders) ...[
          _FolderRow(
            folder: folder,
            expanded: _expandedFolders.contains(folder.path),
            selected: widget.file.path == folder.path,
            onToggle: () => setState(() {
              if (_expandedFolders.contains(folder.path)) {
                _expandedFolders.remove(folder.path);
              } else {
                _expandedFolders.add(folder.path);
              }
            }),
            onDelete: widget.file.projectRoot != null
                ? () => _handleDeleteFile(context, folder)
                : null,
            onAddFile: () => _handleNewFileInFolder(context, folder),
            onAddFolder: () => _handleNewFolderInFolder(context, folder),
          ),
          if (_expandedFolders.contains(folder.path))
            for (final child in widget.files.where((f) =>
                !f.isDirectory && f.path.startsWith(folder.path + Platform.pathSeparator)))
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: _FileRow(
                  icon: _iconFor(child),
                  label: child.name,
                  detail: '',
                  selected: widget.file.path == child.path,
                  onTap: () => widget.onOpenFile(child),
                  onDelete: widget.file.projectRoot != null
                      ? () => _handleDeleteFile(context, child)
                      : null,
                ),
              ),
        ],
        for (final projectFile in rootFiles)
          _FileRow(
            icon: _iconFor(projectFile),
            label: projectFile.name,
            detail: '',
            selected: widget.file.path == projectFile.path,
            onTap: () => widget.onOpenFile(projectFile),
            onDelete: widget.file.projectRoot != null
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
        widget.onNewFile(fileName.trim());
      }
    });
  }

  void _handleNewFolder(BuildContext context) {
    showDialog<String>(
      context: context,
      builder: (context) => const GlassInputDialog(
        title: 'Create New Folder',
        hintText: 'folder-name',
        confirmLabel: 'Create',
      ),
    ).then((folderName) {
      if (folderName != null && folderName.trim().isNotEmpty) {
        widget.onNewFolder(folderName.trim());
      }
    });
  }

  void _handleNewFileInFolder(BuildContext context, WhiskFile folder) {
    final root = folder.projectRoot;
    if (root == null) return;
    final folderPath = folder.path;
    showDialog<String>(
      context: context,
      builder: (context) => const GlassInputDialog(
        title: 'Create New File',
        hintText: 'filename.tex',
        confirmLabel: 'Create',
      ),
    ).then((fileName) {
      if (fileName != null && fileName.trim().isNotEmpty) {
        final relativePath = folderPath.substring(root.length);
        widget.onNewFile('$relativePath${Platform.pathSeparator}${fileName.trim()}');
      }
    });
  }

  void _handleNewFolderInFolder(BuildContext context, WhiskFile folder) {
    final root = folder.projectRoot;
    if (root == null) return;
    final folderPath = folder.path;
    showDialog<String>(
      context: context,
      builder: (context) => const GlassInputDialog(
        title: 'Create New Folder',
        hintText: 'folder-name',
        confirmLabel: 'Create',
      ),
    ).then((folderName) {
      if (folderName != null && folderName.trim().isNotEmpty) {
        final relativePath = folderPath.substring(root.length);
        widget.onNewFolder('$relativePath${Platform.pathSeparator}${folderName.trim()}');
      }
    });
  }

  void _handleDeleteFile(BuildContext context, WhiskFile target) {
    showDialog<bool>(
      context: context,
      builder: (context) => GlassConfirmDialog(
        title: 'Delete',
        message:
            'Are you sure you want to delete ${target.name}? This action cannot be undone.',
        confirmLabel: 'Delete',
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        widget.onDeleteFile(target);
      }
    });
  }

  IconData _iconFor(WhiskFile file) {
    if (file.isImage) return Icons.image_outlined;
    if (file.isPdf) return Icons.picture_as_pdf_outlined;
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

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.folder,
    required this.expanded,
    required this.selected,
    required this.onToggle,
    this.onDelete,
    this.onAddFile,
    this.onAddFolder,
  });

  final WhiskFile folder;
  final bool expanded;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onAddFile;
  final VoidCallback? onAddFolder;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onToggle,
        onSecondaryTapUp: (details) => _showContextMenu(context, details.globalPosition),
        child: Container(
          height: 40,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? kGlassHighlight : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: selected ? kBorder : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(
                expanded ? Icons.folder_open : Icons.folder_outlined,
                size: 18,
                color: kAccentBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  folder.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? kTextPrimary : kTextSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => _showAddMenu(context),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.add, size: 16, color: kTextMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fill,
      items: const [
        PopupMenuItem(value: 'file', height: 32, child: Text('New File', style: TextStyle(fontSize: 13))),
        PopupMenuItem(value: 'folder', height: 32, child: Text('New Folder', style: TextStyle(fontSize: 13))),
      ],
    ).then((value) {
      if (value == 'file') onAddFile?.call();
      if (value == 'folder') onAddFolder?.call();
    });
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: kBorder),
      ),
      color: const Color(0xFF22262E),
      items: [
        PopupMenuItem(
          value: 'delete',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: kDangerRed),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: kDangerRed, fontSize: 13)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'delete') onDelete?.call();
    });
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
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        onSecondaryTapUp: onDelete != null
            ? (details) => _showContextMenu(context, details.globalPosition)
            : null,
        child: Container(
          height: 36,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? kGlassHighlight : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: selected ? kBorder : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: iconColor ?? (selected ? kAccentBlue : kTextSecondary),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? kTextPrimary : kTextSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: kBorder),
      ),
      color: const Color(0xFF22262E),
      items: [
        PopupMenuItem(
          value: 'delete',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: kDangerRed),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: kDangerRed, fontSize: 13)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'delete') onDelete?.call();
    });
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
