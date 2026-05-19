import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:whisk/ui/core/glass_panel.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/features/dashboard/widgets/dashboard_card.dart';
import 'package:whisk/ui/features/workspace/widgets/workspace_rail.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.onOpenDraftWorkspace,
    required this.onOpenLatexProject,
  });

  final VoidCallback onOpenDraftWorkspace;
  final VoidCallback onOpenLatexProject;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
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
            // Ambient glowing background circles
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _glowController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _AmbientGlowPainter(
                      animationValue: _glowController.value,
                    ),
                  );
                },
              ),
            ),
            Row(
              children: [
                const WorkspaceRail(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 900;
                      return SingleChildScrollView(
                        padding: EdgeInsets.all(compact ? 18 : 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _DashboardHeader(),
                            const SizedBox(height: 24),
                            compact
                                ? _CompactDashboard(
                                    onOpenDraftWorkspace: widget.onOpenDraftWorkspace,
                                    onOpenLatexProject: widget.onOpenLatexProject,
                                  )
                                : _WideDashboard(
                                    onOpenDraftWorkspace: widget.onOpenDraftWorkspace,
                                    onOpenLatexProject: widget.onOpenLatexProject,
                                  ),
                          ],
                        ),
                      );
                    },
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

class _AmbientGlowPainter extends CustomPainter {
  _AmbientGlowPainter({required this.animationValue});

  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          kAccentBlue.withOpacity(0.12),
          kAccentBlue.withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width * 0.3 + 50 * math.sin(animationValue * 2 * math.pi),
            size.height * 0.4 + 60 * math.cos(animationValue * 2 * math.pi),
          ),
          radius: size.width * 0.35,
        ),
      );

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          kAccentAmber.withOpacity(0.08),
          kAccentAmber.withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width * 0.7 + 60 * math.cos(animationValue * 2 * math.pi),
            size.height * 0.6 + 50 * math.sin(animationValue * 2 * math.pi),
          ),
          radius: size.width * 0.4,
        ),
      );

    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          kSuccessGreen.withOpacity(0.06),
          kSuccessGreen.withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width * 0.5 + 80 * math.sin((animationValue + 0.5) * 2 * math.pi),
            size.height * 0.2 + 40 * math.cos((animationValue + 0.5) * 2 * math.pi),
          ),
          radius: size.width * 0.3,
        ),
      );

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint3);
  }

  @override
  bool shouldRepaint(covariant _AmbientGlowPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getGreeting()}, Editor',
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Create, reopen and collaborate across renderable projects.',
                style: TextStyle(color: kTextSecondary, fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: GlassPanel(
            borderRadius: 999,
            opacity: 0.5,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: const Row(
                children: [
                  Icon(Icons.search, color: kTextMuted, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Search projects, files, peers...',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: kTextMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WideDashboard extends StatelessWidget {
  const _WideDashboard({
    required this.onOpenDraftWorkspace,
    required this.onOpenLatexProject,
  });

  final VoidCallback onOpenDraftWorkspace;
  final VoidCallback onOpenLatexProject;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 260,
          child: _ProjectActions(
            onOpenDraftWorkspace: onOpenDraftWorkspace,
            onOpenLatexProject: onOpenLatexProject,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 2,
          child: Column(
            children: const [
              _OpenProjectsCard(),
              SizedBox(height: 18),
              _RecentFilesCard(),
            ],
          ),
        ),
        const SizedBox(width: 18),
        const SizedBox(width: 280, child: _CollaborationCard()),
      ],
    );
  }
}

class _CompactDashboard extends StatelessWidget {
  const _CompactDashboard({
    required this.onOpenDraftWorkspace,
    required this.onOpenLatexProject,
  });

  final VoidCallback onOpenDraftWorkspace;
  final VoidCallback onOpenLatexProject;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProjectActions(
          onOpenDraftWorkspace: onOpenDraftWorkspace,
          onOpenLatexProject: onOpenLatexProject,
        ),
        const SizedBox(height: 16),
        const _OpenProjectsCard(),
        const SizedBox(height: 16),
        const _RecentFilesCard(),
        const SizedBox(height: 16),
        const _CollaborationCard(),
      ],
    );
  }
}

class _ProjectActions extends StatelessWidget {
  const _ProjectActions({
    required this.onOpenDraftWorkspace,
    required this.onOpenLatexProject,
  });

  final VoidCallback onOpenDraftWorkspace;
  final VoidCallback onOpenLatexProject;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'New Project',
      trailing: IconButton(
        tooltip: 'Create project',
        onPressed: () {},
        icon: const Icon(Icons.add),
        color: kTextPrimary,
      ),
      child: Column(
        children: [
          _CreateProjectRow(
            icon: Icons.functions,
            title: 'LaTeX Draft',
            subtitle: 'Start from a sample .tex file',
            onTap: onOpenDraftWorkspace,
          ),
          const _CreateProjectRow(
            icon: Icons.description_outlined,
            title: 'Typst Project',
            subtitle: 'Fast structured documents',
          ),
          const _CreateProjectRow(
            icon: Icons.account_tree_outlined,
            title: 'Mermaid Project',
            subtitle: 'Diagrams and flows',
          ),
          _CreateProjectRow(
            icon: Icons.folder_open_outlined,
            title: 'Open LaTeX Folder',
            subtitle: 'Load main.tex or first .tex file',
            onTap: onOpenLatexProject,
          ),
        ],
      ),
    );
  }
}

class _HoverableCard extends StatefulWidget {
  const _HoverableCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(12),
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  State<_HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<_HoverableCard> with SingleTickerProviderStateMixin {
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
        builder: (context, child) {
          final transform = Matrix4.translationValues(0, -3 * _animation.value, 0);
          final opacity = 0.4 + 0.2 * _animation.value;
          final borderColor = Color.lerp(kBorder, kAccentBlue.withOpacity(0.5), _animation.value)!;

          return Transform(
            transform: transform,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  margin: widget.margin,
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    color: kGlassHighlight.withOpacity(opacity),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                    boxShadow: _animation.value > 0
                        ? [
                            BoxShadow(
                              color: kAccentBlue.withOpacity(0.08 * _animation.value),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: widget.child,
                ),
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _CreateProjectRow extends StatelessWidget {
  const _CreateProjectRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _HoverableCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: kAccentBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kTextMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.arrow_forward,
              color: kTextSecondary,
              size: 18,
            ),
        ],
      ),
    );
  }
}

class _OpenProjectsCard extends StatelessWidget {
  const _OpenProjectsCard();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Open Projects',
      trailing: const Icon(Icons.open_in_new, color: kTextSecondary, size: 18),
      child: Column(
        children: const [
          _SectionLabel('LaTeX'),
          _ProjectRow(
            title: 'Thesis Draft',
            subtitle: 'local',
            status: 'editing',
            accent: kAccentBlue,
          ),
          SizedBox(height: 12),
          _SectionLabel('Typst'),
          _ProjectRow(
            title: 'Research Notes',
            subtitle: 'cloud ready',
            status: 'synced',
            accent: kSuccessGreen,
          ),
          SizedBox(height: 12),
          _SectionLabel('Mermaid'),
          _ProjectRow(
            title: 'Architecture Flow',
            subtitle: 'shared',
            status: '2 peers',
            accent: kAccentAmber,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: kTextMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.accent,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String status;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _HoverableCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kTextMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            status,
            style: const TextStyle(color: kTextSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RecentFilesCard extends StatelessWidget {
  const _RecentFilesCard();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Recently Edited',
      child: Column(
        children: const [
          _RecentFileRow(name: 'main.tex', project: 'Thesis Draft'),
          _RecentFileRow(name: 'outline.typ', project: 'Research Notes'),
          _RecentFileRow(name: 'system.mmd', project: 'Architecture Flow'),
        ],
      ),
    );
  }
}

class _RecentFileRow extends StatefulWidget {
  const _RecentFileRow({super.key, required this.name, required this.project});

  final String name;
  final String project;

  @override
  State<_RecentFileRow> createState() => _RecentFileRowState();
}

class _RecentFileRowState extends State<_RecentFileRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: _isHovered ? kGlassHighlight.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              color: _isHovered ? kAccentBlue : kTextSecondary,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _isHovered ? kTextPrimary : kTextSecondary,
                  fontWeight: _isHovered ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Text(
              widget.project,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kTextMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollaborationCard extends StatelessWidget {
  const _CollaborationCard();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Collaboration',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _PeerRow(name: 'Local instance', detail: 'current window'),
          _PeerRow(name: 'Second perspective', detail: 'open another instance'),
          SizedBox(height: 12),
          Text(
            'Future sessions should support multiple windows and even two local identities for testing presence.',
            style: TextStyle(color: kTextSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _PeerRow extends StatefulWidget {
  const _PeerRow({super.key, required this.name, required this.detail});

  final String name;
  final String detail;

  @override
  State<_PeerRow> createState() => _PeerRowState();
}

class _PeerRowState extends State<_PeerRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _isHovered ? kGlassHighlight.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _isHovered ? kAccentBlue.withOpacity(0.15) : kGlassHighlight,
              child: Icon(
                Icons.person_outline,
                color: _isHovered ? kAccentBlue : kTextSecondary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _isHovered ? kTextPrimary : kTextSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    widget.detail,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kTextMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
