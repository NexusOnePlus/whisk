import 'package:flutter/material.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

enum ProjectSidebarSection { files, diagnostics, comments, renders }

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.environment,
    this.section = ProjectSidebarSection.files,
  });

  final EnvironmentKind environment;
  final ProjectSidebarSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 292,
      decoration: const BoxDecoration(
        color: kPanel,
        border: Border(right: BorderSide(color: kBorder)),
      ),
      child: Column(
        children: [
          _ProjectHeader(environment: environment),
          _SidebarNav(section: section),
          Expanded(
            child: _SidebarBody(section: section, environment: environment),
          ),
          const _SidebarStatus(),
        ],
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({required this.environment});

  final EnvironmentKind environment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kPanelRaised,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: kAccentBlue.withValues(alpha: 0.45)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kAccentBlue.withValues(alpha: 0.22), kPanelRaised],
              ),
            ),
            child: Icon(environment.icon, color: kAccentBlue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${environment.name} Draft',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'sample${environment.extension}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kTextMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Collapse sidebar',
            onPressed: () {},
            icon: const Icon(Icons.keyboard_double_arrow_left),
            color: kTextSecondary,
          ),
        ],
      ),
    );
  }
}

class _SidebarNav extends StatelessWidget {
  const _SidebarNav({required this.section});

  final ProjectSidebarSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kAppBlack,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.folder_outlined,
            label: 'Files',
            tooltip: 'Files',
            active: section == ProjectSidebarSection.files,
          ),
          _NavButton(
            icon: Icons.bug_report_outlined,
            label: 'Diag',
            tooltip: 'Diagnostics',
            active: section == ProjectSidebarSection.diagnostics,
          ),
          _NavButton(
            icon: Icons.mode_comment_outlined,
            label: 'Comments',
            tooltip: 'Comments',
            active: section == ProjectSidebarSection.comments,
          ),
          _NavButton(
            icon: Icons.play_circle_outline,
            label: 'Runs',
            tooltip: 'Renders',
            active: section == ProjectSidebarSection.renders,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.active,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: active ? kPanelRaised : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? kTextPrimary : kTextMuted),
              if (active || label == 'Comments') ...[
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? kTextPrimary : kTextMuted,
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarBody extends StatelessWidget {
  const _SidebarBody({required this.section, required this.environment});

  final ProjectSidebarSection section;
  final EnvironmentKind environment;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      ProjectSidebarSection.files => _FilesSection(environment: environment),
      ProjectSidebarSection.diagnostics => const _EmptySection(
        icon: Icons.bug_report_outlined,
        title: 'No diagnostics',
        message: 'Render or analyze the active file to populate this panel.',
      ),
      ProjectSidebarSection.comments => const _EmptySection(
        icon: Icons.mode_comment_outlined,
        title: 'No comments',
        message: 'Comments will be scoped to the active file and selection.',
      ),
      ProjectSidebarSection.renders => const _EmptySection(
        icon: Icons.play_circle_outline,
        title: 'No renders yet',
        message: 'Render history and exported artifacts will appear here.',
      ),
    };
  }
}

class _FilesSection extends StatelessWidget {
  const _FilesSection({required this.environment});

  final EnvironmentKind environment;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const _SectionLabel('Files'),
        const SizedBox(height: 10),
        const _SearchBox(),
        const SizedBox(height: 12),
        _FileRow(
          icon: environment.icon,
          label: 'main${environment.extension}',
          detail: 'active source',
          selected: true,
        ),
        if (environment.id == 'latex') ...const [
          _FileRow(
            icon: Icons.article_outlined,
            label: 'references.bib',
            detail: 'bibliography',
          ),
          _FileRow(
            icon: Icons.image_outlined,
            label: 'figures',
            detail: 'assets folder',
          ),
        ],
        if (environment.id == 'typst') ...const [
          _FileRow(
            icon: Icons.style_outlined,
            label: 'theme.typ',
            detail: 'document styles',
          ),
          _FileRow(
            icon: Icons.table_chart_outlined,
            label: 'data.csv',
            detail: 'source data',
          ),
        ],
        if (environment.id == 'mermaid') ...const [
          _FileRow(
            icon: Icons.account_tree_outlined,
            label: 'system.mmd',
            detail: 'architecture graph',
          ),
          _FileRow(
            icon: Icons.schema_outlined,
            label: 'sequence.mmd',
            detail: 'interaction flow',
          ),
        ],
      ],
    );
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
        color: kPanelRaised,
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

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.icon,
    required this.label,
    required this.detail,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? kPanelRaised : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: selected ? kBorder : Colors.transparent),
      ),
      child: Row(
        children: [
          Icon(icon, color: selected ? kAccentBlue : kTextSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? kTextPrimary : kTextSecondary,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kTextMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kTextMuted, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kTextPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTextSecondary, height: 1.35),
            ),
          ],
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
        color: kAppBlack,
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
