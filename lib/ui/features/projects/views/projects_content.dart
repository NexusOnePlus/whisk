import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whisk/data/services/project_tags_service.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

enum SortMode { name, type, pinned }

class ProjectsContent extends StatefulWidget {
  const ProjectsContent({
    super.key,
    required this.openProjects,
    required this.pinnedProjects,
    this.activeProjectTitle,
    this.onSwitchProject,
    this.onTogglePin,
  });

  final List<String> openProjects;
  final List<String> pinnedProjects;
  final String? activeProjectTitle;
  final ValueChanged<String>? onSwitchProject;
  final ValueChanged<String>? onTogglePin;

  @override
  State<ProjectsContent> createState() => _ProjectsContentState();
}

class _ProjectsContentState extends State<ProjectsContent> {
  String _filter = '';
  String? _tagFilter;
  SortMode _sort = SortMode.name;
  final _tagsService = ProjectTagsService.instance;

  List<String> get _allProjects {
    final all = <String>{...widget.pinnedProjects, ...widget.openProjects}.toList();
    switch (_sort) {
      case SortMode.name:
        all.sort();
      case SortMode.type:
        all.sort((a, b) => _typeOf(a).compareTo(_typeOf(b)));
      case SortMode.pinned:
        return [...widget.pinnedProjects, ...widget.openProjects.where((p) => !widget.pinnedProjects.contains(p))];
    }
    return all;
  }

  String _typeOf(String path) {
    final name = path.split(Platform.pathSeparator).last.toLowerCase();
    if (name.endsWith('.tex')) return 'latex';
    if (name.endsWith('.typ')) return 'typst';
    if (name.endsWith('.mmd')) return 'mermaid';
    return 'other';
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: kAccentBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Projects',
                style: TextStyle(
                  color: kTextPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              _SortDropdown(
                value: _sort,
                onChanged: (v) => setState(() => _sort = v),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 280,
                child: TextField(
                  style: const TextStyle(color: kTextPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: kTextMuted, size: 18),
                    filled: true,
                    fillColor: kGlassHighlight,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            ],
          ),
          if (_allTags.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _TagChip(
                    label: 'All',
                    color: kTextMuted,
                    selected: _tagFilter == null,
                    onTap: () => setState(() => _tagFilter = null),
                  ),
                  const SizedBox(width: 6),
                  for (final tag in _allTags) ...[
                    _TagChip(
                      label: tag,
                      color: kAccentAmber,
                      selected: _tagFilter == tag,
                      onTap: () => setState(() => _tagFilter = tag),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Expanded(
            child: _filteredProjects.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open, color: kTextMuted.withValues(alpha: 0.4), size: 40),
                        const SizedBox(height: 12),
                        Text(
                          _filter.isNotEmpty || _tagFilter != null
                              ? 'No matching projects'
                              : 'No projects yet',
                          style: const TextStyle(color: kTextMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final path in _filteredProjects)
                        _ProjectThumbnailCard(
                          path: path,
                          isPinned: widget.pinnedProjects.contains(path),
                          tags: _tagsService.tagsFor(path),
                          onTap: widget.onSwitchProject != null
                              ? () => widget.onSwitchProject!(path)
                              : null,
                          onTogglePin: widget.onTogglePin != null
                              ? () => widget.onTogglePin!(path)
                              : null,
                          onAddTag: (tag) => _tagsService.addTag(path, tag),
                          onRemoveTag: (tag) => _tagsService.removeTag(path, tag),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.value, required this.onChanged});

  final SortMode value;
  final ValueChanged<SortMode> onChanged;

  String _labelFor(SortMode mode) => switch (mode) {
    SortMode.name => 'Name',
    SortMode.type => 'Type',
    SortMode.pinned => 'Pinned first',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SortMode>(
      onSelected: onChanged,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: kBorder),
      ),
      color: const Color(0xFF22262E),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: kGlassHighlight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _labelFor(value),
              style: const TextStyle(color: kTextPrimary, fontSize: 12),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 14, color: kTextMuted),
          ],
        ),
      ),
      itemBuilder: (context) => [
        for (final mode in SortMode.values)
          PopupMenuItem(
            value: mode,
            height: 36,
            child: Row(
              children: [
                if (mode == value)
                  Icon(Icons.check, size: 14, color: kAccentBlue)
                else
                  const SizedBox(width: 14),
                const SizedBox(width: 8),
                Text(
                  _labelFor(mode),
                  style: TextStyle(
                    color: mode == value ? kAccentBlue : kTextPrimary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProjectThumbnailCard extends StatefulWidget {
  const _ProjectThumbnailCard({
    required this.path,
    required this.isPinned,
    required this.tags,
    this.onTap,
    this.onTogglePin,
    this.onAddTag,
    this.onRemoveTag,
  });

  final String path;
  final bool isPinned;
  final List<String> tags;
  final VoidCallback? onTap;
  final VoidCallback? onTogglePin;
  final ValueChanged<String>? onAddTag;
  final ValueChanged<String>? onRemoveTag;

  @override
  State<_ProjectThumbnailCard> createState() => _ProjectThumbnailCardState();
}

class _ProjectThumbnailCardState extends State<_ProjectThumbnailCard> {
  bool _hovered = false;

  static const _cardWidth = 160.0;
  static const _cardHeight = 230.0;

  @override
  Widget build(BuildContext context) {
    final name = widget.path.split(Platform.pathSeparator).last;
    final type = _typeOf(widget.path);
    final color = _colorForType(type);
    final thumbPath = _findThumbnail();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: (details) => _showContextMenu(context, details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: _hovered ? (Matrix4.identity()..setTranslationRaw(0, -2, 0)) : Matrix4.identity(),
          width: _cardWidth,
          height: _cardHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: thumbPath != null
                      ? Image.file(File(thumbPath), fit: BoxFit.cover, alignment: Alignment.topCenter)
                      : Container(
                          color: color.withValues(alpha: 0.1),
                          child: Icon(_iconForType(type), color: color, size: 40),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          kAppBlack.withValues(alpha: 0.9),
                          kAppBlack.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kTextPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black87),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          type,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            shadows: const [
                              Shadow(blurRadius: 3, color: Colors.black87),
                            ],
                          ),
                        ),
                        if (widget.tags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final tag in widget.tags)
                                _TagChip(
                                  label: tag,
                                  color: kAccentAmber,
                                  selected: false,
                                  onTap: () => widget.onRemoveTag?.call(tag),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.isPinned)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(
                      Icons.push_pin,
                      size: 14,
                      color: kAccentAmber.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _findThumbnail() {
    for (final env in ['latex', 'typst', 'mermaid']) {
      final candidate = '${widget.path}${Platform.pathSeparator}.whisk'
          '${Platform.pathSeparator}build${Platform.pathSeparator}$env'
          '${Platform.pathSeparator}thumb.png';
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  String _typeOf(String path) {
    final name = path.split(Platform.pathSeparator).last.toLowerCase();
    if (name.endsWith('.tex')) return 'latex';
    if (name.endsWith('.typ')) return 'typst';
    if (name.endsWith('.mmd')) return 'mermaid';
    return 'folder';
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

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: kBorder)),
      color: const Color(0xFF22262E),
      items: [
        PopupMenuItem(value: 'open', height: 36, child: Row(children: [const Icon(Icons.open_in_new, size: 16, color: kTextSecondary), const SizedBox(width: 8), const Text('Open', style: TextStyle(color: kTextPrimary, fontSize: 13))])),
        PopupMenuItem(value: 'pin', height: 36, child: Row(children: [Icon(widget.isPinned ? Icons.push_pin_outlined : Icons.push_pin, size: 16, color: kTextSecondary), const SizedBox(width: 8), Text(widget.isPinned ? 'Unpin' : 'Pin', style: const TextStyle(color: kTextPrimary, fontSize: 13))])),
        PopupMenuItem(value: 'tag', height: 36, child: Row(children: [const Icon(Icons.label_outline, size: 16, color: kTextSecondary), const SizedBox(width: 8), const Text('Add tag', style: TextStyle(color: kTextPrimary, fontSize: 13))])),
      ],
    ).then((value) {
      if (!context.mounted) return;
      if (value == 'open') widget.onTap?.call();
      if (value == 'pin') widget.onTogglePin?.call();
      if (value == 'tag') _showAddTagDialog(context);
    });
  }

  void _showAddTagDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF22262E),
        title: const Text('Add Tag', style: TextStyle(color: kTextPrimary, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: kTextPrimary),
          decoration: const InputDecoration(hintText: 'Tag name', hintStyle: TextStyle(color: kTextMuted)),
          onSubmitted: (v) { if (v.trim().isNotEmpty) { widget.onAddTag?.call(v.trim()); Navigator.of(context).pop(); } },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel', style: TextStyle(color: kTextMuted))),
          FilledButton(
            onPressed: () { if (controller.text.trim().isNotEmpty) { widget.onAddTag?.call(controller.text.trim()); Navigator.of(context).pop(); } },
            style: FilledButton.styleFrom(backgroundColor: kAccentBlue),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.color, required this.selected, required this.onTap});

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
        ),
      ),
    );
  }
}
