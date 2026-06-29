import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whisk/domain/models/recent_project.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class DashboardContent extends StatelessWidget {
  const DashboardContent({
    super.key,
    required this.recentProjects,
    required this.onOpenDraftWorkspace,
    required this.onOpenProject,
    required this.onOpenRecentProject,
    required this.onRemoveRecentProject,
    required this.onOpenLocalCollaboration,
    required this.onJoinSharedWorkspace,
    this.pinnedProjects = const [],
    this.onTogglePin,
    this.openProjects = const [],
    this.onSwitchProject,
    this.onAbout,
  });

  final List<RecentProject> recentProjects;
  final ValueChanged<int> onOpenDraftWorkspace;
  final VoidCallback onOpenProject;
  final ValueChanged<RecentProject> onOpenRecentProject;
  final ValueChanged<String> onRemoveRecentProject;
  final VoidCallback onOpenLocalCollaboration;
  final Future<bool> Function(String invite) onJoinSharedWorkspace;
  final List<String> pinnedProjects;
  final ValueChanged<String>? onTogglePin;
  final List<String> openProjects;
  final ValueChanged<String>? onSwitchProject;
  final VoidCallback? onAbout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _NavbarFrame(onAbout: onAbout),
          const SizedBox(height: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionLabel('Nuevo'),
                          const SizedBox(height: 12),
                          _NewProjectGrid(
                            onOpenDraftWorkspace: onOpenDraftWorkspace,
                            onOpenProject: onOpenProject,
                          ),
                          const SizedBox(height: 32),
                          const _SectionLabel('Recientes'),
                          const SizedBox(height: 12),
                          _RecentProjectsGrid(
                            projects: recentProjects,
                            onOpenRecentProject: onOpenRecentProject,
                            onRemoveRecentProject: onRemoveRecentProject,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 260,
                      child: _CollaborationPanel(
                        recentProjects: recentProjects,
                        onJoinSharedWorkspace: onJoinSharedWorkspace,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavbarFrame extends StatelessWidget {
  const _NavbarFrame({this.onAbout});

  final VoidCallback? onAbout;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          _NavBarDropdown(
            label: 'About',
            items: [
              _NavBarMenuItem(
                icon: Icons.info_outline,
                label: 'About Whisk',
                onTap: onAbout,
              ),
            ],
          ),
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: kTextMuted, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        style: const TextStyle(
                          color: kTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Buscar proyectos, comandos...',
                          hintStyle: TextStyle(
                            color: kTextMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBarDropdown extends StatelessWidget {
  const _NavBarDropdown({required this.label, required this.items});

  final String label;
  final List<_NavBarMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_NavBarMenuItem>(
      onSelected: (item) => item.onTap?.call(),
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: kBorder),
      ),
      color: const Color(0xFF22262E),
      itemBuilder: (context) => items
          .map(
            (item) => PopupMenuItem<_NavBarMenuItem>(
              value: item,
              height: 36,
              child: Row(
                children: [
                  Icon(item.icon, size: 16, color: kTextSecondary),
                  const SizedBox(width: 8),
                  Text(
                    item.label,
                    style: const TextStyle(color: kTextPrimary, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: kTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more, size: 16, color: kTextMuted),
          ],
        ),
      ),
    );
  }
}

class _NavBarMenuItem {
  const _NavBarMenuItem({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: kAccentBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: kTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _NewProjectGrid extends StatelessWidget {
  const _NewProjectGrid({
    required this.onOpenDraftWorkspace,
    required this.onOpenProject,
  });

  final ValueChanged<int> onOpenDraftWorkspace;
  final VoidCallback onOpenProject;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 12.0;
        final count = 4;
        final totalSpacing = spacing * (count - 1);
        final cardWidth = (constraints.maxWidth - totalSpacing) / count;
        return Row(
          children: [
            _ProjectCard(
              width: cardWidth,
              icon: Icons.functions,
              label: 'LaTeX',
              color: kAccentBlue,
              onTap: () => onOpenDraftWorkspace(0),
            ),
            SizedBox(width: spacing),
            _ProjectCard(
              width: cardWidth,
              icon: Icons.description_outlined,
              label: 'Typst',
              color: kSuccessGreen,
              onTap: () => onOpenDraftWorkspace(1),
            ),
            SizedBox(width: spacing),
            _ProjectCard(
              width: cardWidth,
              icon: Icons.account_tree_outlined,
              label: 'Mermaid',
              color: kAccentAmber,
              onTap: () => onOpenDraftWorkspace(2),
            ),
            SizedBox(width: spacing),
            _ProjectCard(
              width: cardWidth,
              icon: Icons.folder_open_outlined,
              label: 'Open Folder',
              color: const Color(0xFF5A6570),
              onTap: onOpenProject,
            ),
          ],
        );
      },
    );
  }
}

class _ProjectCard extends StatefulWidget {
  const _ProjectCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final double width;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final t = _animation.value;
          return Transform.translate(
            offset: Offset(0, -3 * t),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: widget.width,
                  height: 130,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.15 + 0.08 * t),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.3 + 0.2 * t),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: widget.color, size: 32),
                      const SizedBox(height: 10),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: kTextPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecentProjectsGrid extends StatelessWidget {
  const _RecentProjectsGrid({
    required this.projects,
    required this.onOpenRecentProject,
    required this.onRemoveRecentProject,
  });

  final List<RecentProject> projects;
  final ValueChanged<RecentProject> onOpenRecentProject;
  final ValueChanged<String> onRemoveRecentProject;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: kGlassHighlight.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            'No hay proyectos recientes',
            style: TextStyle(color: kTextMuted, fontSize: 14),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final project in projects)
          _RecentProjectCard(
            project: project,
            onTap: () => onOpenRecentProject(project),
            onRemove: () => onRemoveRecentProject(project.path),
          ),
      ],
    );
  }
}

class _RecentProjectCard extends StatelessWidget {
  const _RecentProjectCard({
    required this.project,
    required this.onTap,
    required this.onRemove,
  });

  final RecentProject project;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  static const _cardWidth = 160.0;

  @override
  Widget build(BuildContext context) {
    final thumbPath = _renderThumbnailPath();
    if (thumbPath != null) {
      return _buildThumbnailPreview(context, thumbPath);
    }
    return _buildFallback(context);
  }

  Widget _buildThumbnailPreview(BuildContext context, String path) {
    return SizedBox(
      width: _cardWidth,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onSecondaryTapUp: (details) => _showContextMenu(context, details.globalPosition),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 200,
                  width: _cardWidth,
                  child: Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                project.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                project.type,
                style: TextStyle(color: _colorForType(project.type), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    final color = _colorForType(project.type);
    final icon = _iconForType(project.type);
    return SizedBox(
      width: _cardWidth,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onSecondaryTapUp: (details) => _showContextMenu(context, details.globalPosition),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 220,
                width: _cardWidth,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Icon(icon, color: color, size: 40),
              ),
              const SizedBox(height: 8),
              Text(
                project.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
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
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx + 1, position.dy + 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: kBorder),
      ),
      color: const Color(0xFF22262E),
      items: [
        PopupMenuItem(
          value: 'open',
          height: 36,
          child: Row(
            children: [
              const Icon(Icons.open_in_new, size: 16, color: kTextSecondary),
              const SizedBox(width: 8),
              const Text('Open', style: TextStyle(color: kTextPrimary, fontSize: 13)),
            ],
          ),
        ),
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
      if (value == 'open') onTap();
      if (value == 'remove') onRemove();
    });
  }

  String? _renderThumbnailPath() {
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

class _CollaborationPanel extends StatelessWidget {
  const _CollaborationPanel({
    required this.recentProjects,
    required this.onJoinSharedWorkspace,
  });

  final List<RecentProject> recentProjects;
  final Future<bool> Function(String invite) onJoinSharedWorkspace;

  Future<void> _joinWorkspace(BuildContext context) async {
    final invite = await showDialog<String>(
      context: context,
      builder: (context) => const _JoinSharedWorkspaceDialog(),
    );
    if (invite == null || invite.trim().isEmpty) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final joined = await onJoinSharedWorkspace(invite.trim());
    if (!context.mounted) return;
    if (!joined) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to join shared workspace')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: kAccentBlue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Colaboración',
              style: TextStyle(
                color: kTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _joinWorkspace(context),
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Unirse'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kTextPrimary,
              side: const BorderSide(color: kTextMuted),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _JoinSharedWorkspaceDialog extends StatefulWidget {
  const _JoinSharedWorkspaceDialog();

  @override
  State<_JoinSharedWorkspaceDialog> createState() =>
      _JoinSharedWorkspaceDialogState();
}

class _JoinSharedWorkspaceDialogState
    extends State<_JoinSharedWorkspaceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF22262E),
      title: const Text(
        'Join shared workspace',
        style: TextStyle(color: kTextPrimary),
      ),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          style: const TextStyle(color: kTextPrimary),
          decoration: const InputDecoration(
            labelText: 'Invite',
            labelStyle: TextStyle(color: kTextMuted),
            hintText: 'Paste collaboration invite',
            hintStyle: TextStyle(color: kTextMuted),
            border: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: kTextMuted),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            final invite = _controller.text.trim();
            if (invite.isEmpty) return;
            Navigator.of(context).pop(invite);
          },
          icon: const Icon(Icons.link),
          label: const Text('Join'),
        ),
      ],
    );
  }
}
