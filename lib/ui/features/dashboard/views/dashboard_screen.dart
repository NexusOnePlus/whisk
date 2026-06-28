import 'package:flutter/material.dart';
import 'package:whisk/domain/models/recent_project.dart';
import 'package:whisk/ui/core/ambient_glow_painter.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/features/workspace/widgets/workspace_rail.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.recentProjects,
    required this.onOpenDraftWorkspace,
    required this.onOpenProject,
    required this.onOpenLocalCollaboration,
    required this.onJoinSharedWorkspace,
    this.activeWorkspaceTitle,
    this.onResumeActiveWorkspace,
  });

  final List<RecentProject> recentProjects;
  final ValueChanged<int> onOpenDraftWorkspace;
  final VoidCallback onOpenProject;
  final VoidCallback onOpenLocalCollaboration;
  final Future<bool> Function(String invite) onJoinSharedWorkspace;
  final String? activeWorkspaceTitle;
  final VoidCallback? onResumeActiveWorkspace;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBlack,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, _) {
                          return CustomPaint(
                            painter: AmbientGlowPainter(
                          animationValue: _glowController.value,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Row(
              children: [
                const WorkspaceRail(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _NavbarFrame(),
                        const SizedBox(height: 6),
                        Expanded(child: _ContentFrame(dashboard: this)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavbarFrame extends StatelessWidget {
  const _NavbarFrame();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: const Color(0xFF181818),
          child: Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.5,
              child: const TextField(
                style: TextStyle(color: kTextPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  hintStyle: TextStyle(color: kTextMuted),
                  prefixIcon:
                      Icon(Icons.search, color: kTextMuted, size: 20),
                  border: InputBorder.none,
                  filled: true,
                  fillColor: Color(0xFF22262E),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentFrame extends StatelessWidget {
  const _ContentFrame({required this.dashboard});

  final _DashboardScreenState dashboard;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: const Color(0xFF181818),
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
                      onOpenDraftWorkspace:
                          dashboard.widget.onOpenDraftWorkspace,
                      onOpenProject:
                          dashboard.widget.onOpenProject,
                    ),
                    const SizedBox(height: 32),
                    const _SectionLabel('Recientes'),
                    const SizedBox(height: 12),
                    _RecentProjectsGrid(
                      projects: dashboard.widget.recentProjects,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 260,
                child: _CollaborationPanel(
                  recentProjects: dashboard.widget.recentProjects,
                  onJoinSharedWorkspace:
                      dashboard.widget.onJoinSharedWorkspace,
                ),
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
        color: kTextPrimary,
        fontSize: 35,
        fontWeight: FontWeight.w400,
      ),
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
  const _RecentProjectsGrid({required this.projects});

  final List<RecentProject> projects;

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
          _RecentProjectCard(project: project),
      ],
    );
  }
}

class _RecentProjectCard extends StatelessWidget {
  const _RecentProjectCard({required this.project});

  final RecentProject project;

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(project.type);
    final icon = _iconForType(project.type);
    return SizedBox(
      width: 160,
      height: 100,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        project.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kTextPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  project.type,
                  style: TextStyle(color: color, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  void _createWorkspace(BuildContext context) {
    if (recentProjects.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF22262E),
          title: const Text(
            'No hay proyectos recientes',
            style: TextStyle(color: kTextPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _PickRecentForSharingDialog(
        projects: recentProjects,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Colaboración',
          style: TextStyle(
            color: kTextPrimary,
            fontSize: 35,
            fontWeight: FontWeight.w400,
          ),
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
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _createWorkspace(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Crear'),
            style: FilledButton.styleFrom(
              backgroundColor: kAccentBlue,
              foregroundColor: Colors.white,
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

class _PickRecentForSharingDialog extends StatelessWidget {
  const _PickRecentForSharingDialog({required this.projects});

  final List<RecentProject> projects;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF22262E),
      title: const Text(
        'Elige un proyecto',
        style: TextStyle(color: kTextPrimary),
      ),
      content: SizedBox(
        width: 360,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: projects.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final project = projects[index];
            return ListTile(
              leading: Icon(
                _iconForType(project.type),
                color: _colorForType(project.type),
              ),
              title: Text(
                project.name,
                style: const TextStyle(color: kTextPrimary),
              ),
              subtitle: Text(
                project.type,
                style: const TextStyle(color: kTextMuted),
              ),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Compartir no implementado aun'),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
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
