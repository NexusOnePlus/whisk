import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whisk/data/services/project_tags_service.dart';
import 'package:whisk/domain/models/recent_project.dart';
import 'package:whisk/ui/core/ambient_glow_painter.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/features/workspace/widgets/workspace_rail.dart';

enum AppSidebarTab { home, projects, files, search, diagnostics }

class AppSidebar extends StatefulWidget {
  const AppSidebar({
    super.key,
    this.activeProjectTitle,
    this.openProjects = const [],
    this.pinnedProjects = const [],
    this.recentProjects = const [],
    this.workspaceFiles = const [],
    this.onSwitchProject,
    this.onTogglePin,
    this.onCloseProject,
    this.onOpenProject,
    this.onOpenRecentProject,
    this.onRemoveRecentProject,
    this.onOpenDraftWorkspace,
    this.onOpenFolder,
    this.onJoinSharedWorkspace,
    this.onAbout,
  });

  final String? activeProjectTitle;
  final List<String> openProjects;
  final List<String> pinnedProjects;
  final List<RecentProject> recentProjects;
  final List<dynamic> workspaceFiles;
  final ValueChanged<String>? onSwitchProject;
  final ValueChanged<String>? onTogglePin;
  final ValueChanged<String>? onCloseProject;
  final ValueChanged<RecentProject>? onOpenRecentProject;
  final ValueChanged<String>? onRemoveRecentProject;
  final ValueChanged<int>? onOpenDraftWorkspace;
  final VoidCallback? onOpenFolder;
  final Future<bool> Function(String)? onJoinSharedWorkspace;
  final VoidCallback? onAbout;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  AppSidebarTab _tab = AppSidebarTab.home;
  bool _isInWorkspace = false;

  void setWorkspaceMode(bool inWorkspace) {
    if (_isInWorkspace == inWorkspace) return;
    setState(() {
      _isInWorkspace = inWorkspace;
      if (inWorkspace) {
        _tab = AppSidebarTab.files;
      } else {
        _tab = AppSidebarTab.home;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 334,
      child: Row(
        children: [
          _RailColumn(
            activeProjectTitle: widget.activeProjectTitle,
            openProjects: widget.openProjects,
            pinnedProjects: widget.pinnedProjects,
            selectedTab: _tab,
            onSelectTab: (tab) => setState(() => _tab = tab),
            onSwitchProject: widget.onSwitchProject,
            onTogglePin: widget.onTogglePin,
            onCloseProject: widget.onCloseProject,
          ),
          Container(width: 1, color: kBorder),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_tab) {
      case AppSidebarTab.home:
        return _HomeContent(
          recentProjects: widget.recentProjects,
          onOpenRecentProject: widget.onOpenRecentProject,
          onRemoveRecentProject: widget.onRemoveRecentProject,
          onOpenDraftWorkspace: widget.onOpenDraftWorkspace,
          onOpenFolder: widget.onOpenFolder,
          onJoinSharedWorkspace: widget.onJoinSharedWorkspace,
        );
      case AppSidebarTab.projects:
        return _ProjectsContent(
          openProjects: widget.openProjects,
          pinnedProjects: widget.pinnedProjects,
          onSwitchProject: widget.onSwitchProject,
          onTogglePin: widget.onTogglePin,
        );
      case AppSidebarTab.files:
        return const _FilesPlaceholder();
      case AppSidebarTab.search:
        return const _SearchPlaceholder();
      case AppSidebarTab.diagnostics:
        return const _DiagnosticsPlaceholder();
    }
  }
}

class _RailColumn extends StatelessWidget {
  const _RailColumn({
    this.activeProjectTitle,
    this.openProjects = const [],
    this.pinnedProjects = const [],
    required this.selectedTab,
    required this.onSelectTab,
    this.onSwitchProject,
    this.onTogglePin,
    this.onCloseProject,
  });

  final String? activeProjectTitle;
  final List<String> openProjects;
  final List<String> pinnedProjects;
  final AppSidebarTab selectedTab;
  final ValueChanged<AppSidebarTab> onSelectTab;
  final ValueChanged<String>? onSwitchProject;
  final ValueChanged<String>? onTogglePin;
  final ValueChanged<String>? onCloseProject;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      color: kAppBlack,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const _RailMark(),
          const SizedBox(height: 18),
          const _RailDivider(),
          const SizedBox(height: 10),
          _RailButton(
            icon: Icons.home_outlined,
            label: 'Home',
            selected: selectedTab == AppSidebarTab.home,
            onPressed: () => onSelectTab(AppSidebarTab.home),
          ),
          _RailButton(
            icon: Icons.dashboard_outlined,
            label: 'Projects',
            selected: selectedTab == AppSidebarTab.projects,
            onPressed: () => onSelectTab(AppSidebarTab.projects),
          ),
          if (activeProjectTitle != null) ...[
            const SizedBox(height: 6),
            _ActiveProjectItem(
              title: activeProjectTitle!,
              isPinned: pinnedProjects.contains(activeProjectTitle),
              onClose: onCloseProject != null
                  ? () => onCloseProject!(activeProjectTitle!)
                  : null,
              onTogglePin: onTogglePin != null
                  ? () => onTogglePin!(activeProjectTitle!)
                  : null,
            ),
          ],
          if (openProjects.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final path in openProjects)
              if (path.split(RegExp(r'[\\/]')).last != activeProjectTitle)
                _PinnedProjectItem(
                  title: path.split(RegExp(r'[\\/]')).last,
                  onTap: onSwitchProject != null
                      ? () => onSwitchProject!(path)
                      : null,
                ),
          ],
          const Spacer(),
          const _RailDivider(),
          const SizedBox(height: 8),
          _RailButton(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onPressed: () {},
          ),
        ],
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
        border: Border.all(color: kAccentBlue.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: kAccentBlue.withValues(alpha: 0.1), blurRadius: 8),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/whisk_icon.png',
          width: 36,
          height: 36,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? kTextPrimary : kTextSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: selected ? kGlassHighlight : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? kBorder : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foreground, size: 18),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 8,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
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

class _ActiveProjectItem extends StatelessWidget {
  const _ActiveProjectItem({
    required this.title,
    required this.isPinned,
    this.onClose,
    this.onTogglePin,
  });

  final String title;
  final bool isPinned;
  final VoidCallback? onClose;
  final VoidCallback? onTogglePin;

  @override
  Widget build(BuildContext context) {
    final initial = title.isNotEmpty ? title[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: kAccentBlue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kAccentBlue.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: kAccentBlue.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: kAccentBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinnedProjectItem extends StatelessWidget {
  const _PinnedProjectItem({
    required this.title,
    this.onTap,
  });

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initial = title.isNotEmpty ? title[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: kGlassHighlight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: kAccentBlue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: kAccentBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: kTextSecondary,
                      fontSize: 8,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Home Content ---

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.recentProjects,
    this.onOpenRecentProject,
    this.onRemoveRecentProject,
    this.onOpenDraftWorkspace,
    this.onOpenFolder,
    this.onJoinSharedWorkspace,
  });

  final List<RecentProject> recentProjects;
  final ValueChanged<RecentProject>? onOpenRecentProject;
  final ValueChanged<String>? onRemoveRecentProject;
  final ValueChanged<int>? onOpenDraftWorkspace;
  final VoidCallback? onOpenFolder;
  final Future<bool> Function(String)? onJoinSharedWorkspace;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Quick start',
            style: TextStyle(
              color: kTextMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _QuickButton(
                icon: Icons.functions,
                label: 'LaTeX',
                color: kAccentBlue,
                onTap: onOpenDraftWorkspace != null ? () => onOpenDraftWorkspace!(0) : null,
              ),
              const SizedBox(width: 6),
              _QuickButton(
                icon: Icons.description_outlined,
                label: 'Typst',
                color: kSuccessGreen,
                onTap: onOpenDraftWorkspace != null ? () => onOpenDraftWorkspace!(1) : null,
              ),
              const SizedBox(width: 6),
              _QuickButton(
                icon: Icons.folder_open_outlined,
                label: 'Open',
                color: kTextSecondary,
                onTap: onOpenFolder,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Recents',
            style: TextStyle(
              color: kTextMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: recentProjects.isEmpty
              ? const Center(
                  child: Text(
                    'No recent projects',
                    style: TextStyle(color: kTextMuted, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: recentProjects.length,
                  itemBuilder: (context, index) {
                    final project = recentProjects[index];
                    return _RecentTile(
                      project: project,
                      onTap: onOpenRecentProject != null ? () => onOpenRecentProject!(project) : null,
                      onRemove: onRemoveRecentProject != null ? () => onRemoveRecentProject!(project.path) : null,
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onJoinSharedWorkspace != null ? () => _showJoinDialog(context) : null,
              icon: const Icon(Icons.link, size: 16),
              label: const Text('Join session', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: kTextSecondary,
                side: const BorderSide(color: kBorder),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  void _showJoinDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF22262E),
        title: const Text('Join session', style: TextStyle(color: kTextPrimary, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          style: const TextStyle(color: kTextPrimary),
          decoration: const InputDecoration(
            hintText: 'Paste invite',
            hintStyle: TextStyle(color: kTextMuted),
            border: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: kTextMuted)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: kTextMuted)),
          ),
          FilledButton(
            onPressed: () {
              final invite = controller.text.trim();
              if (invite.isNotEmpty) {
                Navigator.of(context).pop();
                onJoinSharedWorkspace?.call(invite);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: kAccentBlue),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.project,
    this.onTap,
    this.onRemove,
  });

  final RecentProject project;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(project.type);
    final icon = _iconForType(project.type);
    final hasThumb = _hasThumbnail();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        onSecondaryTapUp: onRemove != null
            ? (details) => _showContextMenu(context, details.globalPosition)
            : null,
        child: Container(
          height: 52,
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              if (hasThumb)
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Image.file(
                    File(_thumbnailPath()!),
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 52,
                  height: 52,
                  color: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color, size: 20),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kTextPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      project.type,
                      style: TextStyle(color: color, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasThumbnail() => _thumbnailPath() != null;

  String? _thumbnailPath() {
    final type = project.type;
    if (type == 'folder') {
      for (final env in ['latex', 'typst']) {
        final candidate = '${project.path}${Platform.pathSeparator}.whisk'
            '${Platform.pathSeparator}build${Platform.pathSeparator}$env'
            '${Platform.pathSeparator}thumb.png';
        if (File(candidate).existsSync()) return candidate;
      }
      return null;
    }
    final candidate = '${project.path}${Platform.pathSeparator}.whisk'
        '${Platform.pathSeparator}build${Platform.pathSeparator}$type'
        '${Platform.pathSeparator}thumb.png';
    if (File(candidate).existsSync()) return candidate;
    return null;
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
          value: 'remove',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.close, size: 16, color: kDangerRed),
              const SizedBox(width: 8),
              Text('Remove', style: TextStyle(color: kDangerRed, fontSize: 13)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'remove') onRemove?.call();
    });
  }

  Color _colorForType(String type) => switch (type) {
    'latex' => kAccentBlue,
    'typst' => kSuccessGreen,
    'mermaid' => kAccentAmber,
    _ => const Color(0xFF5A6570),
  };

  IconData _iconForType(String type) => switch (type) {
    'latex' => Icons.functions,
    'typst' => Icons.description_outlined,
    'mermaid' => Icons.account_tree_outlined,
    _ => Icons.folder_outlined,
  };
}

// --- Projects Content ---

class _ProjectsContent extends StatefulWidget {
  const _ProjectsContent({
    required this.openProjects,
    required this.pinnedProjects,
    this.onSwitchProject,
    this.onTogglePin,
  });

  final List<String> openProjects;
  final List<String> pinnedProjects;
  final ValueChanged<String>? onSwitchProject;
  final ValueChanged<String>? onTogglePin;

  @override
  State<_ProjectsContent> createState() => _ProjectsContentState();
}

class _ProjectsContentState extends State<_ProjectsContent> {
  String _filter = '';
  String? _tagFilter;
  final _tagsService = ProjectTagsService.instance;

  List<String> get _allProjects {
    final all = <String>{...widget.pinnedProjects, ...widget.openProjects};
    return all.toList()..sort();
  }

  List<String> get _allTags => _tagsService.allTags;

  List<String> get _filteredProjects {
    var projects = _allProjects;
    if (_filter.isNotEmpty) {
      projects = projects.where((p) {
        final name = p.split(Platform.pathSeparator).last.toLowerCase();
        return name.contains(_filter.toLowerCase());
      }).toList();
    }
    if (_tagFilter != null) {
      projects = projects.where((p) {
        final tags = _tagsService.tagsFor(p);
        return tags.contains(_tagFilter);
      }).toList();
    }
    return projects;
  }

  @override
  void initState() {
    super.initState();
    _tagsService.load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            style: const TextStyle(color: kTextPrimary, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Search...',
              hintStyle: const TextStyle(color: kTextMuted, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: kTextMuted, size: 16),
              filled: true,
              fillColor: kGlassHighlight,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kAccentBlue),
              ),
            ),
            onChanged: (v) => setState(() => _filter = v),
          ),
        ),
        if (_allTags.isNotEmpty) ...[
          SizedBox(
            height: 26,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _MiniTagChip(
                  label: 'All',
                  selected: _tagFilter == null,
                  onTap: () => setState(() => _tagFilter = null),
                ),
                const SizedBox(width: 4),
                for (final tag in _allTags) ...[
                  _MiniTagChip(
                    label: tag,
                    selected: _tagFilter == tag,
                    onTap: () => setState(() => _tagFilter = tag),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: _filteredProjects.isEmpty
              ? const Center(
                  child: Text('No projects', style: TextStyle(color: kTextMuted, fontSize: 12)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _filteredProjects.length,
                  itemBuilder: (context, index) {
                    final path = _filteredProjects[index];
                    final name = path.split(Platform.pathSeparator).last;
                    final isPinned = widget.pinnedProjects.contains(path);
                    final tags = _tagsService.tagsFor(path);
                    return _ProjectTile(
                      name: name,
                      path: path,
                      isPinned: isPinned,
                      tags: tags,
                      onTap: widget.onSwitchProject != null ? () => widget.onSwitchProject!(path) : null,
                      onTogglePin: widget.onTogglePin != null ? () => widget.onTogglePin!(path) : null,
                      onAddTag: (tag) => _tagsService.addTag(path, tag),
                      onRemoveTag: (tag) => _tagsService.removeTag(path, tag),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MiniTagChip extends StatelessWidget {
  const _MiniTagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? kAccentAmber.withValues(alpha: 0.2) : kAccentAmber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? kAccentAmber : kAccentAmber.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: kAccentAmber,
            fontSize: 9,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.name,
    required this.path,
    required this.isPinned,
    required this.tags,
    this.onTap,
    this.onTogglePin,
    this.onAddTag,
    this.onRemoveTag,
  });

  final String name;
  final String path;
  final bool isPinned;
  final List<String> tags;
  final VoidCallback? onTap;
  final VoidCallback? onTogglePin;
  final ValueChanged<String>? onAddTag;
  final ValueChanged<String>? onRemoveTag;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 48,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isPinned ? kAccentBlue.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isPinned ? Icons.push_pin : Icons.folder_outlined,
                size: 14,
                color: isPinned ? kAccentAmber : kTextSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kTextPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (tags.isNotEmpty)
                      Text(
                        tags.join(', '),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kAccentAmber, fontSize: 9),
                      ),
                  ],
                ),
              ),
              if (onTogglePin != null)
                GestureDetector(
                  onTap: onTogglePin,
                  child: Icon(
                    isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 12,
                    color: isPinned ? kAccentAmber : kTextMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Workspace placeholders (files/search/diagnostics are handled by the editor) ---

class _FilesPlaceholder extends StatelessWidget {
  const _FilesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'File explorer\n(open a project)',
        textAlign: TextAlign.center,
        style: TextStyle(color: kTextMuted, fontSize: 12),
      ),
    );
  }
}

class _SearchPlaceholder extends StatelessWidget {
  const _SearchPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Search\n(open a project)',
        textAlign: TextAlign.center,
        style: TextStyle(color: kTextMuted, fontSize: 12),
      ),
    );
  }
}

class _DiagnosticsPlaceholder extends StatelessWidget {
  const _DiagnosticsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Diagnostics\n(open a project)',
        textAlign: TextAlign.center,
        style: TextStyle(color: kTextMuted, fontSize: 12),
      ),
    );
  }
}
