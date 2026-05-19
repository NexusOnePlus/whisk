import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/features/dashboard/widgets/dashboard_card.dart';
import 'package:whisk/ui/features/workspace/widgets/workspace_rail.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpenDraftWorkspace});

  final VoidCallback onOpenDraftWorkspace;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
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
                                onOpenDraftWorkspace: onOpenDraftWorkspace,
                              )
                            : _WideDashboard(
                                onOpenDraftWorkspace: onOpenDraftWorkspace,
                              ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Project Dashboard',
                style: TextStyle(
                  color: kTextPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Create, reopen and collaborate across renderable projects.',
                style: TextStyle(color: kTextSecondary, fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: kPanel,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: kBorder),
            ),
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
      ],
    );
  }
}

class _WideDashboard extends StatelessWidget {
  const _WideDashboard({required this.onOpenDraftWorkspace});

  final VoidCallback onOpenDraftWorkspace;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 260,
          child: _ProjectActions(onOpenDraftWorkspace: onOpenDraftWorkspace),
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
  const _CompactDashboard({required this.onOpenDraftWorkspace});

  final VoidCallback onOpenDraftWorkspace;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProjectActions(onOpenDraftWorkspace: onOpenDraftWorkspace),
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
  const _ProjectActions({required this.onOpenDraftWorkspace});

  final VoidCallback onOpenDraftWorkspace;

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
            title: 'LaTeX Project',
            subtitle: 'Papers, reports and equations',
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
          const _CreateProjectRow(
            icon: Icons.folder_open_outlined,
            title: 'Open Folder',
            subtitle: 'Use an existing workspace',
          ),
        ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kPanelRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
          ),
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
        ),
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
          _ProjectRow(
            title: 'Thesis Draft',
            subtitle: 'LaTeX · local',
            status: 'editing',
            accent: kAccentBlue,
          ),
          _ProjectRow(
            title: 'Research Notes',
            subtitle: 'Typst · cloud ready',
            status: 'synced',
            accent: kSuccessGreen,
          ),
          _ProjectRow(
            title: 'Architecture Flow',
            subtitle: 'Mermaid · shared',
            status: '2 peers',
            accent: kAccentAmber,
          ),
        ],
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
  });

  final String title;
  final String subtitle;
  final String status;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: kPanelRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
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

class _RecentFileRow extends StatelessWidget {
  const _RecentFileRow({required this.name, required this.project});

  final String name;
  final String project;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, color: kTextSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kTextPrimary),
            ),
          ),
          Text(
            project,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: kTextMuted, fontSize: 12),
          ),
        ],
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

class _PeerRow extends StatelessWidget {
  const _PeerRow({required this.name, required this.detail});

  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: kPanelRaised,
            child: Icon(Icons.person_outline, color: kTextSecondary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  detail,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kTextMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
