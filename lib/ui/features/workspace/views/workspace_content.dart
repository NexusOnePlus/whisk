import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whisk/data/services/invite_codec.dart';
import 'package:whisk/data/services/settings_service.dart';
import 'package:whisk/domain/models/render_result.dart';
import 'package:whisk/ui/core/ambient_glow_painter.dart';
import 'package:whisk/ui/features/editor/logic/whisk_editor_controller.dart';
import 'package:whisk/ui/features/editor/models/editor_selection_range.dart';
import 'package:whisk/ui/features/workspace/view_models/workspace_view_model.dart';
import 'package:whisk/ui/features/workspace/widgets/editor_content_frame.dart';
import 'package:whisk/ui/features/workspace/widgets/editor_navbar.dart';
import 'package:whisk/ui/features/workspace/widgets/join_invite_dialog.dart';
import 'package:whisk/ui/features/workspace/widgets/log_viewer_dialog.dart';

class WorkspaceContent extends StatefulWidget {
  const WorkspaceContent({
    super.key,
    required this.viewModel,
    this.onCloseWorkspace,
    this.openProjects = const [],
    this.pinnedProjects = const [],
    this.onCloseProject,
    this.onTogglePin,
    this.onSwitchProject,
    this.onAbout,
  });

  final WorkspaceViewModel viewModel;
  final VoidCallback? onCloseWorkspace;
  final List<String> openProjects;
  final List<String> pinnedProjects;
  final VoidCallback? onCloseProject;
  final ValueChanged<String>? onTogglePin;
  final ValueChanged<String>? onSwitchProject;
  final VoidCallback? onAbout;

  @override
  State<WorkspaceContent> createState() => _WorkspaceContentState();
}

class _WorkspaceContentState extends State<WorkspaceContent>
    with SingleTickerProviderStateMixin {
  late final WhiskEditorController _controller;
  late final FocusNode _editorFocusNode;
  late final TextEditingController _findController;
  late final FocusNode _findFocusNode;
  late final AnimationController _glowController;
  bool _findOpen = false;
  int _findCursor = 0;
  List<int> _findMatches = const [];
  int _revealRevision = 0;
  int? _revealOffset;
  Timer? _renderDebounce;

  WorkspaceViewModel get viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    LogBuffer.writeln(
      LogCategory.system,
      '[${DateTime.now().toString().substring(11, 19)}] Initializing WorkspaceContent UI...',
    );
    _glowController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
    _controller = WhiskEditorController(
      text: viewModel.activeFile.content,
      environmentId: viewModel.selectedEnvironment.id,
    );
    _editorFocusNode = FocusNode();
    _findController = TextEditingController();
    _findFocusNode = FocusNode();
    _controller.addListener(() {});
    viewModel.addListener(_onViewModelChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) viewModel.renderActiveFile();
    });
  }

  @override
  void didUpdateWidget(covariant WorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.viewModel, oldWidget.viewModel)) {
      oldWidget.viewModel.removeListener(_onViewModelChanged);
      widget.viewModel.addListener(_onViewModelChanged);
      _controller.setTextFromModel(viewModel.activeFile.content);
      _controller.setEnvironment(viewModel.selectedEnvironment.id);
      setState(() {});
    }
  }

  @override
  void dispose() {
    LogBuffer.writeln(
      LogCategory.system,
      '[${DateTime.now().toString().substring(11, 19)}] Disposing WorkspaceContent UI...',
    );
    _renderDebounce?.cancel();
    _glowController.dispose();
    viewModel.removeListener(_onViewModelChanged);
    _controller.dispose();
    _editorFocusNode.dispose();
    _findController.dispose();
    _findFocusNode.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    final content = viewModel.activeFile.content;
    _controller.setEnvironment(viewModel.selectedEnvironment.id);
    if (_controller.text != content) {
      _controller.setTextFromModel(content);
    }
    setState(() {});
  }

  void _handleEditorChanged(String content) {
    viewModel.updateActiveContent(content);
    if (SettingsService.instance.renderOnSaveOnly) return;
    _renderDebounce?.cancel();
    _renderDebounce = Timer(const Duration(milliseconds: 800), () {
      if (mounted) viewModel.renderActiveFile();
    });
  }

  void _toggleFind() {
    setState(() {
      _findOpen = !_findOpen;
      if (_findOpen) {
        _refreshFindMatches();
      } else {
        _controller.setSecondarySelections(const []);
      }
    });
    if (_findOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _findFocusNode.requestFocus();
      });
    }
  }

  void _refreshFindMatches() {
    final query = _findController.text;
    if (query.isEmpty) {
      _findMatches = const [];
      _findCursor = 0;
      _controller.setSecondarySelections(const []);
      return;
    }
    final content = _controller.text.toLowerCase();
    final needle = query.toLowerCase();
    final matches = <int>[];
    var start = 0;
    while (start <= content.length) {
      final index = content.indexOf(needle, start);
      if (index < 0) break;
      matches.add(index);
      start = index + needle.length;
    }
    _findMatches = matches;
    if (_findCursor >= _findMatches.length) _findCursor = 0;
    _selectCurrentFindMatch();
  }

  void _moveFind(int delta) {
    if (_findMatches.isEmpty) return;
    setState(() {
      _findCursor = (_findCursor + delta) % _findMatches.length;
      if (_findCursor < 0) _findCursor += _findMatches.length;
    });
    _selectCurrentFindMatch();
  }

  void _selectCurrentFindMatch() {
    if (_findMatches.isEmpty || _findController.text.isEmpty) return;
    final start = _findMatches[_findCursor];
    final end = start + _findController.text.length;
    _controller.selection = TextSelection(baseOffset: start, extentOffset: end);
    _controller.setSecondarySelections([
      EditorSelectionRange(baseOffset: start, extentOffset: end),
    ]);
    setState(() {
      _revealOffset = start;
      _revealRevision++;
    });
  }

  void _showLogs() {
    showDialog(context: context, builder: (context) => const LogViewerDialog());
  }

  bool get _canExportPdf {
    final envId = viewModel.selectedEnvironment.id;
    return envId == 'latex' || envId == 'typst';
  }

  Future<void> _exportToPdf() async {
    final messenger = ScaffoldMessenger.of(context);

    if (viewModel.renderResult.state != RenderState.success ||
        viewModel.renderResult.pdfPath == null) {
      await viewModel.saveActiveFile();
      if (!mounted) return;
      if (viewModel.renderResult.state != RenderState.success ||
          viewModel.renderResult.pdfPath == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Compilation failed. Fix errors and try again.'),
          ),
        );
        return;
      }
    }

    final pdfPath = viewModel.renderResult.pdfPath!;
    final pdfFile = File(pdfPath);
    if (!await pdfFile.exists()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('PDF file not found')),
      );
      return;
    }

    final result = await FilePicker.saveFile(
      dialogTitle: 'Export PDF',
      fileName:
          '${viewModel.activeFile.name.replaceAll(RegExp(r'\.[^.]+$'), '')}.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (!mounted || result == null) return;

    final destFile = File(result);
    await pdfFile.copy(destFile.path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF exported successfully')),
      );
    }
  }

  Future<void> _createCollaborationInvite() async {
    final messenger = ScaffoldMessenger.of(context);
    final rawInvite = await viewModel.createCollaborationInvite();
    if (!mounted) return;
    if (rawInvite == null || rawInvite.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to create collaboration invite')),
      );
      return;
    }

    final hostName = SettingsService.instance.profileName.isNotEmpty
        ? SettingsService.instance.profileName
        : 'Host';
    final invite = InviteCodec.encode(ticket: rawInvite, hostName: hostName);

    await Clipboard.setData(ClipboardData(text: invite));
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Collaboration invite copied')),
    );
  }

  Future<void> _joinCollaborationInvite() async {
    final invite = await showDialog<String>(
      context: context,
      builder: (context) => const JoinInviteDialog(),
    );
    if (!mounted || invite == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final joined = await viewModel.joinCollaborationInvite(invite);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          joined
              ? 'Joined collaboration session'
              : 'Unable to join collaboration session',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.keyS,
          control: true,
        ): () async {
          LogBuffer.writeln(
            LogCategory.render,
            '[${DateTime.now().toString().substring(11, 19)}] Ctrl+S pressed',
          );
          _renderDebounce?.cancel();
          LogBuffer.writeln(
            LogCategory.render,
            '[${DateTime.now().toString().substring(11, 19)}] Debounce timer cancelled',
          );
          await viewModel.saveActiveFile();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _toggleFind,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            _controller.undoEdit,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            _controller.redoEdit,
      },
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            return Stack(
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
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        EditorNavbar(
                          onCloseWorkspace: widget.onCloseWorkspace ?? () {},
                          onCreateInvite: _createCollaborationInvite,
                          onJoinInvite: _joinCollaborationInvite,
                          onExportPdf: _canExportPdf ? _exportToPdf : null,
                          canExportPdf: _canExportPdf,
                          onAbout: widget.onAbout,
                          onShowLogs: _showLogs,
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: EditorContentFrame(
                            viewModel: viewModel,
                            controller: _controller,
                            editorFocusNode: _editorFocusNode,
                            onEditorChanged: _handleEditorChanged,
                            revealRevision: _revealRevision,
                            revealOffset: _revealOffset,
                            findOpen: _findOpen,
                            findController: _findController,
                            findFocusNode: _findFocusNode,
                            findMatches: _findMatches,
                            findCursor: _findCursor,
                            onToggleFind: _toggleFind,
                            onRefreshFind: _refreshFindMatches,
                            onMoveFind: _moveFind,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
