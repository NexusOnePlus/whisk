import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/features/app_shell/view_models/app_shell_view_model.dart';
import 'package:whisk/ui/features/app_shell/widgets/about_dialog.dart' as whisk;
import 'package:whisk/ui/features/app_shell/widgets/app_rail.dart';
import 'package:whisk/ui/features/dashboard/views/dashboard_content.dart';
import 'package:whisk/ui/features/projects/views/projects_content.dart';
import 'package:whisk/ui/features/workspace/views/workspace_content.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final AppShellViewModel viewModel;
  RailTab _railTab = RailTab.home;

  @override
  void initState() {
    super.initState();
    viewModel = AppShellViewModel();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final isWorkspace = viewModel.mode == AppShellMode.workspace;

        return Scaffold(
          backgroundColor: kAppBlack,
          body: SafeArea(
            child: Row(
              children: [
                AppRail(
                  activeProjectTitle: viewModel.activeWorkspaceTitle,
                  openProjects: viewModel.openProjectPaths,
                  pinnedProjects: viewModel.pinnedProjects,
                  selectedTab: _railTab,
                  isInWorkspace: isWorkspace,
                  onSelectTab: (tab) {
                    if (isWorkspace) viewModel.closeWorkspace();
                    setState(() => _railTab = tab);
                  },
                  onSwitchProject: viewModel.switchToProject,
                  onTogglePin: viewModel.togglePinProject,
                  onSettings: _showSettings,
                ),
                Container(width: 1, color: kBorder),
                Expanded(
                  child: _buildContent(isWorkspace),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(bool isWorkspace) {
    if (isWorkspace) {
      return WorkspaceContent(
        viewModel: viewModel.workspaceViewModel!,
        onCloseWorkspace: viewModel.closeWorkspace,
        onAbout: _showAbout,
      );
    }

    switch (_railTab) {
      case RailTab.projects:
        return ProjectsContent(
          openProjects: viewModel.openProjectPaths,
          pinnedProjects: viewModel.pinnedProjects,
          activeProjectTitle: viewModel.activeWorkspaceTitle,
          onSwitchProject: viewModel.switchToProject,
          onTogglePin: viewModel.togglePinProject,
        );
      case RailTab.home:
        return DashboardContent(
          recentProjects: viewModel.recentProjects,
          onOpenDraftWorkspace: (int i) => viewModel.openDraftWorkspace(i),
          onOpenProject: viewModel.openProject,
          onOpenRecentProject: viewModel.openRecentProject,
          onRemoveRecentProject: viewModel.removeRecentProject,
          onOpenLocalCollaboration: viewModel.openLocalCollaborationDemo,
          onJoinSharedWorkspace: viewModel.joinSharedWorkspace,
          pinnedProjects: viewModel.pinnedProjects,
          onTogglePin: viewModel.togglePinProject,
          openProjects: viewModel.openProjectPaths,
          onSwitchProject: viewModel.switchToProject,
          onAbout: _showAbout,
        );
    }
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => const whisk.WhiskAboutDialog(),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (_) => const _SettingsDialog(),
    );
  }
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final dir = Platform.isWindows
        ? '${Platform.environment['APPDATA']}\\whisk'
        : '${Platform.environment['HOME']}/.config/whisk';
    final file = File('$dir${Platform.pathSeparator}settings.json');
    if (await file.exists()) {
      try {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final name = data['profileName'] as String? ?? '';
        _nameController.text = name;
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: kAccentBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.settings, color: kAccentBlue, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Settings', style: TextStyle(color: kTextPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Profile', style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            const Text('Display name for collaboration sessions', style: TextStyle(color: kTextSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: kTextPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Your name',
                hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
                filled: true,
                fillColor: kGlassHighlight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kAccentBlue)),
              ),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel', style: TextStyle(color: kTextMuted))),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(backgroundColor: kAccentBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final dir = Platform.isWindows
        ? '${Platform.environment['APPDATA']}\\whisk'
        : '${Platform.environment['HOME']}/.config/whisk';
    final d = Directory(dir);
    if (!await d.exists()) await d.create(recursive: true);
    final file = File('$dir${Platform.pathSeparator}settings.json');
    await file.writeAsString(jsonEncode({'profileName': _nameController.text.trim()}));
    if (mounted) Navigator.of(context).pop();
  }
}
