import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whisk/data/services/project_tags_service.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

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
              SizedBox(
                width: 280,
                child: TextField(
                  style: const TextStyle(color: kTextPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search projects...',
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
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = 220.0;
                      final spacing = 12.0;
                      final crossAxisCount = (constraints.maxWidth / (cardWidth + spacing)).floor().clamp(1, 10);
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: spacing,
                          crossAxisSpacing: spacing,
                          childAspectRatio: 1.4,
                        ),
                        itemCount: _filteredProjects.length,
                        itemBuilder: (context, index) {
                          final path = _filteredProjects[index];
                          final name = path.split(Platform.pathSeparator).last;
                          final isPinned = widget.pinnedProjects.contains(path);
                          final tags = _tagsService.tagsFor(path);
                          return _ProjectCard(
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatefulWidget {
  const _ProjectCard({
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
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: (details) => _showContextMenu(context, details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: _hovered ? (Matrix4.identity()..setTranslationRaw(0, -2, 0)) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: _hovered ? kGlassHighlight : kGlassHighlight.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isPinned
                  ? kAccentAmber.withValues(alpha: 0.4)
                  : _hovered ? kBorder : kBorder.withValues(alpha: 0.5),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    widget.isPinned ? Icons.push_pin : Icons.folder_outlined,
                    size: 18,
                    color: widget.isPinned ? kAccentAmber : kAccentBlue,
                  ),
                  const Spacer(),
                  if (widget.tags.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: kAccentAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${widget.tags.length}',
                        style: const TextStyle(color: kAccentAmber, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                widget.name,
                style: const TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                widget.path,
                style: const TextStyle(color: kTextMuted, fontSize: 10),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (widget.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final tag in widget.tags.take(3))
                      _TagChip(
                        label: tag,
                        color: kAccentAmber,
                        selected: false,
                        onTap: () => widget.onRemoveTag?.call(tag),
                      ),
                    if (widget.tags.length > 3)
                      Text('+${widget.tags.length - 3}', style: const TextStyle(color: kTextMuted, fontSize: 9)),
                  ],
                ),
              ],
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
