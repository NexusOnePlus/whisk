import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whisk/domain/models/collaboration_text_update.dart';
import 'package:whisk/ui/core/ambient_glow_painter.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/features/editor/logic/whisk_editor_controller.dart';
import 'package:whisk/ui/features/editor/models/editor_selection_range.dart';
import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';
import 'package:whisk/ui/features/workspace/view_models/workspace_view_model.dart';
import 'package:whisk/ui/features/workspace/widgets/editor_content_frame.dart';
import 'package:whisk/ui/features/workspace/widgets/editor_navbar.dart';
import 'package:whisk/ui/features/workspace/widgets/join_invite_dialog.dart';
import 'package:whisk/ui/features/workspace/widgets/workspace_rail.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.viewModel,
    required this.onCloseWorkspace,
    this.openProjects = const [],
    this.pinnedProjects = const [],
    this.onCloseProject,
    this.onTogglePin,
    this.onSwitchProject,
  });

  final WorkspaceViewModel viewModel;
  final VoidCallback onCloseWorkspace;
  final List<String> openProjects;
  final List<String> pinnedProjects;
  final VoidCallback? onCloseProject;
  final ValueChanged<String>? onTogglePin;
  final ValueChanged<String>? onSwitchProject;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final WhiskEditorController _controller;
  late final FocusNode _editorFocusNode;
  late final TextEditingController _findController;
  late final FocusNode _findFocusNode;
  bool _findOpen = false;
  int _findCursor = 0;
  List<int> _findMatches = const [];
  int _revealRevision = 0;
  int? _revealOffset;
  Timer? _contentSyncTimer;
  Timer? _presenceSyncTimer;
  String? _pendingContent;
  StreamSubscription? _operationSubscription;
  StreamSubscription? _remoteTextSubscription;
  late final AnimationController _glowController;

  WorkspaceViewModel get viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
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
    _operationSubscription = _controller.textOperations.listen(
      _handleLocalTextOperations,
    );
    _remoteTextSubscription = viewModel.remoteTextUpdates?.listen(
      _handleRemoteTextUpdate,
    );
    _controller.addListener(_schedulePresenceSync);
    viewModel.addListener(_onViewModelChanged);
  }

  @override
  void didUpdateWidget(covariant WorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.viewModel, oldWidget.viewModel)) {
      oldWidget.viewModel.removeListener(_onViewModelChanged);
      widget.viewModel.addListener(_onViewModelChanged);
      _controller.setTextFromModel(viewModel.activeFile.content);
      _controller.setEnvironment(viewModel.selectedEnvironment.id);
      _lastPreviewKey = null;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _flushPendingContent();
    _glowController.dispose();
    _contentSyncTimer?.cancel();
    _presenceSyncTimer?.cancel();
    _operationSubscription?.cancel();
    _remoteTextSubscription?.cancel();
    viewModel.removeListener(_onViewModelChanged);
    _controller.removeListener(_schedulePresenceSync);
    _controller.dispose();
    _editorFocusNode.dispose();
    _findController.dispose();
    _findFocusNode.dispose();
    super.dispose();
  }

  String? _lastPreviewKey;

  void _onViewModelChanged() {
    if (!mounted) return;
    if (_pendingContent != null) return;
    final content = viewModel.activeFile.content;
    _controller.setEnvironment(viewModel.selectedEnvironment.id);
    if (_controller.text != content) {
      _controller.setTextFromModel(content);
    }
    final r = viewModel.renderResult;
    final key = '${viewModel.activeFile.path}|${viewModel.selectedEnvironment.id}|${r.state}|${r.pdfPath}|${r.content}';
    if (key != _lastPreviewKey) {
      _lastPreviewKey = key;
      setState(() {});
    }
  }

  void _handleEditorChanged(String content) {
    _pendingContent = content;
    _contentSyncTimer?.cancel();
    _contentSyncTimer = Timer(const Duration(milliseconds: 250), () {
      _flushPendingContent();
    });
  }

  void _handleLocalTextOperations(List<EditorTextOperation> operations) {
    viewModel.publishLocalTextOperations(operations);
    _contentSyncTimer?.cancel();
    _pendingContent = null;
    viewModel.updateActiveContent(_controller.text);
  }

  void _handleRemoteTextUpdate(CollaborationTextUpdate update) {
    _contentSyncTimer?.cancel();
    _pendingContent = null;
    if (update.filePath == viewModel.activeFile.path) {
      _controller.applyRemoteOperation(update.operation);
      viewModel.updateActiveContentFromRemote(_controller.text);
      return;
    }
    viewModel.applyRemoteTextUpdate(update);
  }

  void _schedulePresenceSync() {
    _presenceSyncTimer?.cancel();
    _presenceSyncTimer = Timer(const Duration(milliseconds: 16), () {
      final selection = _controller.selection;
      if (!selection.isValid) return;
      viewModel.publishLocalCursor(
        offset: selection.extentOffset.clamp(0, _controller.text.length),
        selectionStart: selection.start == selection.end
            ? null
            : selection.start.clamp(0, _controller.text.length),
        selectionEnd: selection.start == selection.end
            ? null
            : selection.end.clamp(0, _controller.text.length),
      );
    });
  }

  void _flushPendingContent() {
    final content = _pendingContent;
    if (content == null) return;
    _pendingContent = null;
    if (!mounted && viewModel.activeFile.content == content) return;
    viewModel.updateActiveContent(content);
  }

  void _toggleFind() {
    final nextOpen = !_findOpen;
    setState(() {
      _findOpen = nextOpen;
      if (_findOpen) {
        _refreshFindMatches();
      } else {
        _controller.setSecondarySelections(const []);
      }
    });
    if (_findOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _findFocusNode.requestFocus();
        _findController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _findController.text.length,
        );
      });
    }
  }

  Future<void> _createCollaborationInvite() async {
    final messenger = ScaffoldMessenger.of(context);
    final invite = await viewModel.createCollaborationInvite();
    if (!mounted) return;
    if (invite == null || invite.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to create collaboration invite')),
      );
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.keyS,
          control: true,
        ): () async {
          _flushPendingContent();
          await viewModel.saveActiveFile();
          viewModel.renderActiveFile();
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
                        WorkspaceRail(
                          activeProjectTitle: viewModel.activeFile.projectRoot != null
                              ? viewModel.activeFile.projectRoot!
                                  .split(RegExp(r'[\\/]'))
                                  .last
                              : null,
                          openProjects: widget.openProjects,
                          pinnedProjects: widget.pinnedProjects,
                          onCloseProject: widget.onCloseProject,
                          onTogglePin: widget.onTogglePin,
                          onSwitchProject: widget.onSwitchProject,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                EditorNavbar(
                                  onCloseWorkspace: widget.onCloseWorkspace,
                                  onCreateInvite: _createCollaborationInvite,
                                  onJoinInvite: _joinCollaborationInvite,
                                ),
                                const SizedBox(height: 6),
                                EditorContentFrame(
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
          },
        ),
      ),
    );
  }
}


