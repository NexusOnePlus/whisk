import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';

class CollaborationTextUpdate {
  const CollaborationTextUpdate({
    required this.peerId,
    required this.filePath,
    required this.operation,
  });

  final String peerId;
  final String filePath;
  final EditorTextOperation operation;
}
