import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/domain/models/render_result.dart';
import 'package:whisk/domain/models/whisk_file.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/core/glass_dialogs.dart';
import 'package:whisk/ui/features/workspace/widgets/build_output_panel.dart';
import 'package:whisk/ui/features/workspace/widgets/environment_status.dart';

// ignore_for_file: prefer_const_constructors

enum ProjectSidebarSection { files, search, diagnostics }

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.file,
    required this.files,
    required this.environment,
    required this.renderResult,
    required this.onOpenFile,
    required this.onNewFile,
    required this.onNewFolder,
    required this.onDeleteFile,
    required this.onRenameFile,
    this.section = ProjectSidebarSection.files,
  });

  final WhiskFile file;
  final List<WhiskFile> files;
  final EnvironmentKind environment;
  final RenderResult renderResult;
  final ValueChanged<WhiskFile> onOpenFile;
  final ValueChanged<String> onNewFile;
  final ValueChanged<String> onNewFolder;
  final ValueChanged<WhiskFile> onDeleteFile;
  final void Function(WhiskFile file, String newName) onRenameFile;
  final ProjectSidebarSection section;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Column(
        children: [
          Expanded(
            child: _SidebarBody(
              section: section,
              environment: environment,
              renderResult: renderResult,
              file: file,
              files: files,
              onOpenFile: onOpenFile,
              onNewFile: onNewFile,
              onNewFolder: onNewFolder,
              onDeleteFile: onDeleteFile,
              onRenameFile: onRenameFile,
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
    required this.renderResult,
    required this.file,
    required this.files,
    required this.onOpenFile,
    required this.onNewFile,
    required this.onNewFolder,
    required this.onDeleteFile,
    required this.onRenameFile,
  });

  final ProjectSidebarSection section;
  final EnvironmentKind environment;
  final RenderResult renderResult;
  final WhiskFile file;
  final List<WhiskFile> files;
  final ValueChanged<WhiskFile> onOpenFile;
  final ValueChanged<String> onNewFile;
  final ValueChanged<String> onNewFolder;
  final ValueChanged<WhiskFile> onDeleteFile;
  final void Function(WhiskFile file, String newName) onRenameFile;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: section.index,
      children: [
        _FilesSection(
          environment: environment,
          file: file,
          files: files,
          onOpenFile: onOpenFile,
          onNewFile: onNewFile,
          onNewFolder: onNewFolder,
          onDeleteFile: onDeleteFile,
          onRenameFile: onRenameFile,
        ),
        _SearchSection(
          files: files,
          onOpenFile: onOpenFile,
        ),
        _DiagnosticsSection(
          environment: environment,
          renderResult: renderResult,
        ),
      ],
    );
  }
}

class _DiagnosticsSection extends StatelessWidget {
  const _DiagnosticsSection({
    required this.environment,
    required this.renderResult,
  });

  final EnvironmentKind environment;
  final RenderResult renderResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: BuildOutputPanel(
            environment: environment,
            renderResult: renderResult,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 2,
          child: EnvironmentStatus(),
        ),
      ],
    );
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
    required this.onRenameFile,
  });

  final EnvironmentKind environment;
  final WhiskFile file;
  final List<WhiskFile> files;
  final ValueChanged<WhiskFile> onOpenFile;
  final ValueChanged<String> onNewFile;
  final ValueChanged<String> onNewFolder;
  final ValueChanged<WhiskFile> onDeleteFile;
  final void Function(WhiskFile file, String newName) onRenameFile;

  @override
  State<_FilesSection> createState() => _FilesSectionState();
}

class _FilesSectionState extends State<_FilesSection> {
  final Set<String> _expandedFolders = {};
  final _filterController = TextEditingController();
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _filterController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _filterController.removeListener(_onFilterChanged);
    _filterController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    setState(() => _filterQuery = _filterController.text.trim().toLowerCase());
  }

  bool _matchesFilter(String name) =>
      _filterQuery.isEmpty || name.toLowerCase().contains(_filterQuery);

  @override
  Widget build(BuildContext context) {
    final root = widget.files.isNotEmpty ? widget.files.first.projectRoot : null;
    final topFolders = widget.files.where((f) {
      if (!f.isDirectory) return false;
      if (root == null) return true;
      final relative = f.path.substring(root.length).replaceFirst(RegExp(r'^[\\/]'), '');
      return !relative.contains(Platform.pathSeparator);
    }).where((f) => _matchesFilter(f.name)).toList();
    final rootFiles = widget.files.where((f) => !f.isDirectory).where((f) {
      if (root == null) return true;
      final relative = f.path.substring(root.length).replaceFirst(RegExp(r'^[\\/]'), '');
      return !relative.contains(Platform.pathSeparator);
    }).where((f) => _matchesFilter(f.name)).toList();

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
        _SearchBox(controller: _filterController),
        const SizedBox(height: 12),
        for (final folder in topFolders)
          ..._buildFolderTree(folder, 0),
        for (final projectFile in rootFiles)
          _FileRow(
            icon: _iconFor(projectFile),
            label: projectFile.name,
            detail: '',
            filePath: projectFile.path,
            selected: widget.file.path == projectFile.path,
            onTap: () => widget.onOpenFile(projectFile),
            onDelete: widget.file.projectRoot != null
                ? () => _handleDeleteFile(context, projectFile)
                : null,
            onRename: widget.file.projectRoot != null
                ? () => _handleRenameFile(context, projectFile)
                : null,
          ),
      ],
    );
  }

  List<Widget> _buildFolderTree(WhiskFile folder, int depth) {
    final children = widget.files.where((f) {
      if (!f.path.startsWith(folder.path + Platform.pathSeparator)) return false;
      final relative = f.path.substring(folder.path.length + 1);
      return !relative.contains(Platform.pathSeparator);
    }).toList();
    final subFolders = children.where((f) => f.isDirectory).toList();
    final subFiles = children.where((f) => !f.isDirectory).toList();
    final isExpanded = _expandedFolders.contains(folder.path);

    return [
      Padding(
        padding: EdgeInsets.only(left: depth * 24.0),
        child: _FolderRow(
          folder: folder,
          expanded: isExpanded,
          selected: widget.file.path == folder.path,
          onToggle: () => setState(() {
            if (isExpanded) {
              _expandedFolders.remove(folder.path);
            } else {
              _expandedFolders.add(folder.path);
            }
          }),
          onDelete: widget.file.projectRoot != null
              ? () => _handleDeleteFile(context, folder)
              : null,
          onRename: widget.file.projectRoot != null
              ? () => _handleRenameFile(context, folder)
              : null,
          onAddFile: () => _handleNewFileInFolder(context, folder),
          onAddFolder: () => _handleNewFolderInFolder(context, folder),
        ),
      ),
      if (isExpanded) ...[
        for (final sub in subFolders)
          ..._buildFolderTree(sub, depth + 1),
          for (final file in subFiles)
          Padding(
            padding: EdgeInsets.only(left: (depth + 1) * 24.0),
            child: _FileRow(
              icon: _iconFor(file),
              label: file.name,
              detail: '',
              filePath: file.path,
              selected: widget.file.path == file.path,
              onTap: () => widget.onOpenFile(file),
              onDelete: widget.file.projectRoot != null
                  ? () => _handleDeleteFile(context, file)
                  : null,
              onRename: widget.file.projectRoot != null
                  ? () => _handleRenameFile(context, file)
                  : null,
            ),
          ),
      ],
    ];
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
        final relativePath = folderPath.substring(root.length).replaceFirst(RegExp(r'^[\\/]'), '');
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
        final relativePath = folderPath.substring(root.length).replaceFirst(RegExp(r'^[\\/]'), '');
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

  void _handleRenameFile(BuildContext context, WhiskFile target) {
    final controller = TextEditingController(text: target.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF22262E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kBorder),
        ),
        title: const Text('Rename', style: TextStyle(color: kTextPrimary, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: kTextPrimary),
          decoration: const InputDecoration(
            hintText: 'File name',
            hintStyle: TextStyle(color: kTextMuted),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty && v.trim() != target.name) {
              widget.onRenameFile(target, v.trim());
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: kTextMuted)),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty && controller.text.trim() != target.name) {
                widget.onRenameFile(target, controller.text.trim());
                Navigator.of(context).pop();
              }
            },
            style: FilledButton.styleFrom(backgroundColor: kAccentBlue),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
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
    this.selected = false,
    this.onToggle,
    this.onDelete,
    this.onRename,
    this.onAddFile,
    this.onAddFolder,
  });

  final WhiskFile folder;
  final bool expanded;
  final bool selected;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
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
              Builder(
                builder: (btnContext) => InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _showAddMenu(btnContext),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.add, size: 16, color: kTextMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final position = box != null
        ? box.localToGlobal(Offset(box.size.width, 0))
        : Offset.zero;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
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
          value: 'rename',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16, color: kTextSecondary),
              SizedBox(width: 8),
              Text('Rename', style: TextStyle(color: kTextPrimary, fontSize: 13)),
            ],
          ),
        ),
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
      if (value == 'rename') onRename?.call();
      if (value == 'delete') onDelete?.call();
    });
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.icon,
    required this.label,
    required this.detail,
    this.filePath,
    this.selected = false,
    this.onTap,
    this.onDelete,
    this.onRename,
  });

  final IconData icon;
  final String label;
  final String detail;
  final String? filePath;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;

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
                color: selected ? kAccentBlue : kTextSecondary,
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
        if (filePath != null)
          PopupMenuItem(
            value: 'reveal',
            height: 36,
            child: Row(
              children: [
                Icon(Icons.folder_open, size: 16, color: kTextSecondary),
                SizedBox(width: 8),
                Text('Reveal in file explorer', style: TextStyle(color: kTextPrimary, fontSize: 13)),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'rename',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16, color: kTextSecondary),
              SizedBox(width: 8),
              Text('Rename', style: TextStyle(color: kTextPrimary, fontSize: 13)),
            ],
          ),
        ),
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
      if (value == 'reveal' && filePath != null) {
        _revealInExplorer(filePath!);
      }
      if (value == 'rename') onRename?.call();
      if (value == 'delete') onDelete?.call();
    });
  }

  void _revealInExplorer(String path) {
    Process.run('explorer', ['/select,$path']);
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({this.controller});

  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: kTextPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Filter files...',
        hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
        prefixIcon: const Icon(Icons.search, color: kTextMuted, size: 19),
        suffixIcon: controller != null && controller!.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16, color: kTextMuted),
                onPressed: () => controller!.clear(),
              )
            : null,
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
    );
  }
}

class _SearchSection extends StatefulWidget {
  const _SearchSection({
    required this.files,
    required this.onOpenFile,
  });

  final List<WhiskFile> files;
  final ValueChanged<WhiskFile> onOpenFile;

  @override
  State<_SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends State<_SearchSection> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  List<_ContentMatch> _contentMatches = const [];
  var _isSearching = false;

  Timer? _debounce;

  static const _textExtensions = {
    '.tex', '.typ', '.md', '.mmd', '.bib', '.sty', '.cls',
    '.txt', '.json', '.yaml', '.yml', '.toml', '.xml', '.html',
    '.css', '.js', '.ts', '.py', '.rs', '.dart', '.sh', '.ps1',
  };

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    if (q == _query) return;
    _debounce?.cancel();
    setState(() {
      _query = q;
      _contentMatches = const [];
    });
    if (q.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(q));
  }

  Future<void> _runSearch(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);

    final files = widget.files.where((f) => !f.isDirectory).toList();
    final matches = <_ContentMatch>[];

    for (final f in files) {
      if (!mounted) return;

      if (f.name.toLowerCase().contains(query)) {
        matches.add(_ContentMatch(file: f, lines: const [], nameMatch: true));
      }

      if (!_isTextFile(f.extension)) continue;

      try {
        final diskFile = File(f.path);
        if (!await diskFile.exists()) continue;
        final content = await diskFile.readAsString();
        final searchLines = <_MatchLine>[];
        final lines = content.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.toLowerCase().contains(query)) {
            searchLines.add(_MatchLine(
              lineNumber: i + 1,
              text: line.trimLeft().substring(0, line.trimLeft().length.clamp(0, 120)),
            ));
          }
        }
        if (searchLines.isNotEmpty) {
          matches.add(_ContentMatch(file: f, lines: searchLines, nameMatch: false));
        }
      } catch (e) {
        dev.log('Search failed for file: $e', name: 'Sidebar');
      }
    }

    if (!mounted) return;
    setState(() {
      _contentMatches = matches;
      _isSearching = false;
    });
  }

  bool _isTextFile(String ext) => _textExtensions.contains(ext.toLowerCase());

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            focusNode: _focusNode,
            autofocus: true,
            style: const TextStyle(color: kTextPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search text in files...',
              hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: kTextMuted, size: 19),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: kTextMuted),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
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
          const SizedBox(height: 16),
          Expanded(
            child: _query.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search, color: kTextMuted, size: 28),
                        SizedBox(height: 12),
                        Text(
                          'Search file names and contents',
                          style: TextStyle(color: kTextMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : _isSearching
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _contentMatches.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off, color: kTextMuted, size: 28),
                                SizedBox(height: 12),
                                Text(
                                  'No results found',
                                  style: TextStyle(color: kTextMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _contentMatches.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final match = _contentMatches[index];
                              return _SearchResultCard(
                                match: match,
                                query: _query,
                                onTap: () {
                                  widget.onOpenFile(match.file);
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _ContentMatch {
  const _ContentMatch({
    required this.file,
    required this.lines,
    this.nameMatch = false,
  });

  final WhiskFile file;
  final List<_MatchLine> lines;
  final bool nameMatch;
}

class _MatchLine {
  const _MatchLine({required this.lineNumber, required this.text});

  final int lineNumber;
  final String text;
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.match,
    required this.query,
    required this.onTap,
  });

  final _ContentMatch match;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final file = match.file;
    final icon = _iconForExt(file.extension);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kGlassHighlight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: kAccentBlue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _HighlightedText(
                      text: file.name,
                      query: query,
                      style: const TextStyle(
                        color: kTextPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      highlightStyle: const TextStyle(
                        color: kAccentBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (match.nameMatch)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: kAccentBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'name',
                        style: TextStyle(color: kAccentBlue, fontSize: 9),
                      ),
                    ),
                ],
              ),
              if (match.lines.isNotEmpty) ...[
                const SizedBox(height: 6),
                for (final line in match.lines.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${line.lineNumber}',
                            style: const TextStyle(
                              color: kTextMuted,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const TextSpan(text: '  '),
                          _buildContentSpan(line.text, query),
                        ],
                      ),
                    ),
                  ),
                if (match.lines.length > 5)
                  Text(
                    '... and ${match.lines.length - 5} more matches',
                    style: const TextStyle(color: kTextMuted, fontSize: 10),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _buildContentSpan(String text, String query) {
    final lower = text.toLowerCase();
    final idx = lower.indexOf(query);
    if (idx < 0) {
      return TextSpan(
        text: text,
        style: const TextStyle(color: kTextSecondary, fontSize: 11, fontFamily: 'monospace'),
      );
    }
    return TextSpan(
      children: [
        if (idx > 0)
          TextSpan(text: text.substring(0, idx)),
        TextSpan(
          text: text.substring(idx, idx + query.length),
          style: const TextStyle(
            color: kAccentAmber,
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
          ),
        ),
        if (idx + query.length < text.length)
          TextSpan(text: text.substring(idx + query.length)),
      ],
      style: const TextStyle(color: kTextSecondary, fontSize: 11, fontFamily: 'monospace'),
    );
  }

  IconData _iconForExt(String ext) {
    if (ext == '.tex') return Icons.science_outlined;
    if (ext == '.typ') return Icons.code_outlined;
    if (ext == '.md') return Icons.notes_outlined;
    if (ext == '.mmd') return Icons.account_tree_outlined;
    if (ext == '.bib') return Icons.book_outlined;
    if (ext == '.sty' || ext == '.cls') return Icons.tune_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightStyle,
  });

  final String text;
  final String query;
  final TextStyle style;
  final TextStyle highlightStyle;

  @override
  Widget build(BuildContext context) {
    final lower = text.toLowerCase();
    final idx = lower.indexOf(query);
    if (idx < 0 || query.isEmpty) {
      return Text(text, style: style, overflow: TextOverflow.ellipsis);
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (idx > 0) TextSpan(text: text.substring(0, idx)),
          TextSpan(text: text.substring(idx, idx + query.length), style: highlightStyle),
          if (idx + query.length < text.length)
            TextSpan(text: text.substring(idx + query.length)),
        ],
      ),
      overflow: TextOverflow.ellipsis,
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
