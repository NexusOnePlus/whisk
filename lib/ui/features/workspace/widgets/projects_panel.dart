import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class ProjectsPanel extends StatefulWidget {
  const ProjectsPanel({
    super.key,
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
  State<ProjectsPanel> createState() => _ProjectsPanelState();
}

class _ProjectsPanelState extends State<ProjectsPanel> {
  String _filter = '';
  final _tagController = TextEditingController();
  final Map<String, List<String>> _projectTags = {};

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  List<String> get _allProjects {
    final all = <String>{...widget.pinnedProjects, ...widget.openProjects};
    return all.toList()..sort();
  }

  List<String> get _allTags {
    final tags = <String>{};
    for (final tagsList in _projectTags.values) {
      tags.addAll(tagsList);
    }
    return tags.toList()..sort();
  }

  List<String> _filteredProjects(String? tagFilter) {
    var projects = _allProjects;
    if (_filter.isNotEmpty) {
      projects = projects.where((p) {
        final name = p.split(Platform.pathSeparator).last.toLowerCase();
        return name.contains(_filter.toLowerCase());
      }).toList();
    }
    if (tagFilter != null) {
      projects = projects.where((p) {
        final tags = _projectTags[p] ?? [];
        return tags.contains(tagFilter);
      }).toList();
    }
    return projects;
  }

  void _addTagToProject(String path, String tag) {
    setState(() {
      _projectTags.putIfAbsent(path, () => []);
      if (!_projectTags[path]!.contains(tag)) {
        _projectTags[path]!.add(tag);
      }
    });
  }

  void _removeTagFromProject(String path, String tag) {
    setState(() {
      _projectTags[path]?.remove(tag);
      if (_projectTags[path]?.isEmpty ?? false) {
        _projectTags.remove(path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2228),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorder),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: kAccentBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.dashboard_outlined, color: kAccentBlue, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'Projects',
            style: TextStyle(
              color: kTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 450,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
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
            if (_allTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 28,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _TagChip(
                      label: 'All',
                      color: kTextMuted,
                      selected: true,
                      onTap: () {},
                    ),
                    for (final tag in _allTags)
                      _TagChip(
                        label: tag,
                        color: kAccentAmber,
                        selected: false,
                        onTap: () {},
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _filteredProjects(null).isEmpty
                  ? const Center(
                      child: Text(
                        'No projects found',
                        style: TextStyle(color: kTextMuted, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filteredProjects(null).length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final path = _filteredProjects(null)[index];
                        final name = path.split(Platform.pathSeparator).last;
                        final isPinned = widget.pinnedProjects.contains(path);
                        final tags = _projectTags[path] ?? [];
                        return _ProjectRow(
                          name: name,
                          path: path,
                          isPinned: isPinned,
                          tags: tags,
                          onTap: () {
                            widget.onSwitchProject?.call(path);
                            Navigator.of(context).pop();
                          },
                          onTogglePin: () => widget.onTogglePin?.call(path),
                          onAddTag: (tag) => _addTagToProject(path, tag),
                          onRemoveTag: (tag) => _removeTagFromProject(path, tag),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(color: kTextMuted)),
        ),
      ],
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
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
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: kGlassHighlight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: [
              Icon(
                isPinned ? Icons.push_pin : Icons.folder_outlined,
                size: 16,
                color: isPinned ? kAccentAmber : kTextSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: kTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      path,
                      style: const TextStyle(
                        color: kTextMuted,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final tag in tags)
                            _TagChip(
                              label: tag,
                              color: kAccentAmber,
                              selected: false,
                              onTap: () => onRemoveTag?.call(tag),
                            ),
                          GestureDetector(
                            onTap: () => _showAddTagDialog(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: kTextMuted.withValues(alpha: 0.3)),
                              ),
                              child: Icon(Icons.add, size: 10, color: kTextMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 16,
                  color: isPinned ? kAccentAmber : kTextMuted,
                ),
                onPressed: onTogglePin,
                constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
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
          decoration: const InputDecoration(
            hintText: 'Tag name',
            hintStyle: TextStyle(color: kTextMuted),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              onAddTag?.call(v.trim());
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
              if (controller.text.trim().isNotEmpty) {
                onAddTag?.call(controller.text.trim());
                Navigator.of(context).pop();
              }
            },
            style: FilledButton.styleFrom(backgroundColor: kAccentBlue),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
