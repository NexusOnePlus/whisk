import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/features/workspace/widgets/settings_dialog.dart';
import 'package:window_manager/window_manager.dart';

class WorkspaceRail extends StatefulWidget {
  const WorkspaceRail({
    super.key,
    this.activeProjectTitle,
    this.openProjects = const [],
    this.pinnedProjects = const [],
    this.onSelectProject,
    this.onSwitchProject,
    this.onCloseProject,
    this.onTogglePin,
    this.onHelp,
    this.onShowLogs,
    this.onHome,
    this.onProjects,
  });

  final String? activeProjectTitle;
  final List<String> openProjects;
  final List<String> pinnedProjects;
  final void Function(int index)? onSelectProject;
  final ValueChanged<String>? onSwitchProject;
  final VoidCallback? onCloseProject;
  final ValueChanged<String>? onTogglePin;
  final VoidCallback? onHelp;
  final VoidCallback? onShowLogs;
  final VoidCallback? onHome;
  final VoidCallback? onProjects;

  @override
  State<WorkspaceRail> createState() => _WorkspaceRailState();
}

class _WorkspaceRailState extends State<WorkspaceRail> {
  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: Container(
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
              selected: true,
              onPressed: widget.onHome ?? () {},
            ),
            _RailButton(
              icon: Icons.dashboard_outlined,
              label: 'Projects',
              onPressed: widget.onProjects ?? () {},
            ),
            _RailButton(
              icon: Icons.inventory_2_outlined,
              label: 'Packages',
              onPressed: () {},
            ),
            _RailButton(
              icon: Icons.groups_2_outlined,
              label: 'Friends',
              onPressed: () {},
            ),
            _RailButton(
              icon: Icons.feedback_outlined,
              label: 'Feedback',
              onPressed: () {},
            ),
            if (widget.activeProjectTitle != null) ...[
              const SizedBox(height: 6),
              _ActiveProjectItem(
                title: widget.activeProjectTitle!,
                isPinned: widget.pinnedProjects.contains(widget.activeProjectTitle),
                onClose: widget.onCloseProject,
                onTogglePin: widget.onTogglePin != null
                    ? () => widget.onTogglePin!(widget.activeProjectTitle!)
                    : null,
              ),
            ],
            if (widget.openProjects.isNotEmpty) ...[
              const SizedBox(height: 4),
              for (final path in widget.openProjects)
                if (path.split(RegExp(r'[\\/]')).last != widget.activeProjectTitle)
                  _PinnedProjectItem(
                    title: path.split(RegExp(r'[\\/]')).last,
                    onTap: widget.onSwitchProject != null
                        ? () => widget.onSwitchProject!(path)
                        : null,
                    onUnpin: null,
                  ),
            ],
            if (widget.pinnedProjects.isNotEmpty) ...[
              const SizedBox(height: 4),
              for (var i = 0; i < widget.pinnedProjects.length; i++)
                if (widget.pinnedProjects[i] != widget.activeProjectTitle)
                  _PinnedProjectItem(
                    title: widget.pinnedProjects[i],
                    onTap: widget.onSelectProject != null
                        ? () => widget.onSelectProject!(i)
                        : null,
                    onUnpin: widget.onTogglePin != null
                        ? () => widget.onTogglePin!(widget.pinnedProjects[i])
                        : null,
                  ),
            ],
            const Spacer(),
            Builder(
              builder: (context) => _RailButton(
                icon: Icons.help_outline,
                label: 'Help',
                onPressed: () {
                  showMenu<String>(
                    context: context,
                    position: RelativeRect.fromLTRB(70, 0, 70, 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: kBorder),
                    ),
                    color: const Color(0xFF22262E),
                    items: [
                      PopupMenuItem(
                        value: 'logs',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(Icons.terminal, size: 16, color: kTextSecondary),
                            SizedBox(width: 8),
                            Text('Logs', style: TextStyle(color: kTextPrimary, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ).then((value) {
                    if (value == 'logs') {
                      widget.onShowLogs?.call();
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            const _RailDivider(),
            const SizedBox(height: 8),
            _RailButton(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const SettingsDialog(),
                );
              },
            ),
          ],
        ),
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
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onSecondaryTapUp: (details) => _showContextMenu(context, details.globalPosition),
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
      ),
    );
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
          value: 'pin',
          height: 36,
          child: Row(
            children: [
              Icon(
                isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                size: 16,
                color: kTextSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                isPinned ? 'Unpin' : 'Pin',
                style: const TextStyle(color: kTextPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'close',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.close, size: 16, color: kDangerRed),
              const SizedBox(width: 8),
              Text('Close', style: TextStyle(color: kDangerRed, fontSize: 13)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'pin') onTogglePin?.call();
      if (value == 'close') onClose?.call();
    });
  }
}

class _PinnedProjectItem extends StatelessWidget {
  const _PinnedProjectItem({
    required this.title,
    this.onTap,
    this.onUnpin,
  });

  final String title;
  final VoidCallback? onTap;
  final VoidCallback? onUnpin;

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
          onSecondaryTapUp: (details) => _showContextMenu(context, details.globalPosition),
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
          value: 'unpin',
          height: 36,
          child: Row(
            children: [
              const Icon(Icons.push_pin_outlined, size: 16, color: kTextSecondary),
              const SizedBox(width: 8),
              const Text('Unpin', style: TextStyle(color: kTextPrimary, fontSize: 13)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'unpin') onUnpin?.call();
    });
  }
}

class _RailDivider extends StatelessWidget {
  const _RailDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 30, height: 1, color: kBorder);
  }
}
