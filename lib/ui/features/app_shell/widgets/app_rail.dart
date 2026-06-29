import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

enum RailTab { home, projects }

class AppRail extends StatelessWidget {
  const AppRail({
    super.key,
    this.activeProjectTitle,
    this.openProjects = const [],
    this.pinnedProjects = const [],
    required this.selectedTab,
    this.isInWorkspace = false,
    required this.onSelectTab,
    this.onSwitchProject,
    this.onTogglePin,
    this.onSettings,
  });

  final String? activeProjectTitle;
  final List<String> openProjects;
  final List<String> pinnedProjects;
  final RailTab selectedTab;
  final bool isInWorkspace;
  final ValueChanged<RailTab> onSelectTab;
  final ValueChanged<String>? onSwitchProject;
  final ValueChanged<String>? onTogglePin;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      color: kAppBlack,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          _RailMark(),
          const SizedBox(height: 18),
          const _RailDivider(),
          const SizedBox(height: 10),
          _RailButton(
            icon: Icons.home_outlined,
            label: 'Home',
            selected: !isInWorkspace && selectedTab == RailTab.home,
            onPressed: () => onSelectTab(RailTab.home),
          ),
          _RailButton(
            icon: Icons.dashboard_outlined,
            label: 'Projects',
            selected: !isInWorkspace && selectedTab == RailTab.projects,
            onPressed: () => onSelectTab(RailTab.projects),
          ),
          if (activeProjectTitle != null) ...[
            const SizedBox(height: 6),
            _ActiveProjectPill(
              title: activeProjectTitle!,
              isPinned: pinnedProjects.contains(activeProjectTitle),
              isActive: isInWorkspace,
              onTogglePin: onTogglePin != null
                  ? () => onTogglePin!(activeProjectTitle!)
                  : null,
            ),
          ],
          if (openProjects.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final path in openProjects)
              if (path.split(RegExp(r'[\\/]')).last != activeProjectTitle)
                _ProjectPill(
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
            onPressed: onSettings ?? () {},
          ),
        ],
      ),
    );
  }
}

class _RailMark extends StatelessWidget {
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
    final fg = selected ? kTextPrimary : kTextSecondary;
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
              border: Border.all(color: selected ? kBorder : Colors.transparent),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: fg, size: 18),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
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
  Widget build(BuildContext context) => Container(width: 30, height: 1, color: kBorder);
}

class _ActiveProjectPill extends StatelessWidget {
  const _ActiveProjectPill({
    required this.title,
    required this.isPinned,
    required this.isActive,
    this.onTogglePin,
  });

  final String title;
  final bool isPinned;
  final bool isActive;
  final VoidCallback? onTogglePin;

  @override
  Widget build(BuildContext context) {
    final initial = title.isNotEmpty ? title[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? kAccentBlue.withValues(alpha: 0.25)
              : kAccentBlue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? kAccentBlue.withValues(alpha: 0.5)
                : kAccentBlue.withValues(alpha: 0.2),
          ),
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
                style: TextStyle(
                  color: isActive ? kTextPrimary : kTextSecondary,
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
    );
  }
}

class _ProjectPill extends StatelessWidget {
  const _ProjectPill({required this.title, this.onTap});

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
