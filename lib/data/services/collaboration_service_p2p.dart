import 'dart:async';
import 'package:whisk/data/services/collaboration_service.dart';
import 'package:whisk/domain/models/collaboration_peer.dart';
import 'package:whisk/src/rust/api/collaboration.dart';
import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';

class CollaborationServiceP2p implements CollaborationService {
  final _peerController = StreamController<List<CollaborationPeer>>.broadcast();
  final _textController = StreamController<EditorTextOperation>.broadcast();

  CollaborationEngine? _engine;
  bool _isConnecting = false;

  @override
  Stream<List<CollaborationPeer>> get peers => _peerController.stream;

  @override
  Stream<EditorTextOperation> get remoteTextUpdates => _textController.stream;

  @override
  Future<void> connect(String workspaceId) async {
    if (_isConnecting || _engine != null) return;
    _isConnecting = true;
    try {
      _engine = CollaborationEngine();
      await _engine!.startSession();
      _peerController.add(const []);
    } finally {
      _isConnecting = false;
    }
  }

  @override
  Future<void> disconnect() async {
    _engine?.dispose();
    _engine = null;
    _peerController.add([]);
  }

  @override
  void updateLocalCursor(
    int offset, {
    int? selectionStart,
    int? selectionEnd,
  }) {}

  @override
  void broadcastTextChange(EditorTextOperation operation) {
    _engine?.applyLocalEdit(
      op: RustTextOperation(
        offset: operation.offset,
        deletedLength: operation.deletedText.length,
        insertedText: operation.insertedText,
      ),
    );
  }
}
