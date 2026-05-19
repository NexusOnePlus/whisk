import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';

class WhiskEditorBuffer {
  WhiskEditorBuffer(String text) : _text = text {
    _rebuildLineStarts();
  }

  String _text;
  List<int> _lineStarts = const [0];

  String get text => _text;
  int get length => _text.length;
  List<int> get lineStarts => List.unmodifiable(_lineStarts);

  int get lineCount => _lineStarts.length;

  int lineForOffset(int offset) {
    final clamped = offset.clamp(0, _text.length);
    var low = 0;
    var high = _lineStarts.length - 1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      final start = _lineStarts[middle];
      if (start == clamped) return middle;
      if (start < clamped) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return high.clamp(0, _lineStarts.length - 1);
  }

  int columnForOffset(int offset) {
    final line = lineForOffset(offset);
    return offset.clamp(0, _text.length) - _lineStarts[line];
  }

  EditorTextOperation replace({
    required int start,
    required int end,
    required String text,
  }) {
    final safeStart = start.clamp(0, _text.length);
    final safeEnd = end.clamp(safeStart, _text.length);
    final deleted = _text.substring(safeStart, safeEnd);
    _text = _text.replaceRange(safeStart, safeEnd, text);
    _rebuildLineStarts();
    return EditorTextOperation(
      offset: safeStart,
      deletedText: deleted,
      insertedText: text,
    );
  }

  void apply(EditorTextOperation operation) {
    replace(
      start: operation.offset,
      end: operation.offset + operation.deletedText.length,
      text: operation.insertedText,
    );
  }

  void setText(String text) {
    _text = text;
    _rebuildLineStarts();
  }

  void _rebuildLineStarts() {
    final starts = <int>[0];
    for (var index = 0; index < _text.length; index++) {
      if (_text.codeUnitAt(index) == 10 && index + 1 < _text.length) {
        starts.add(index + 1);
      }
    }
    _lineStarts = starts;
  }
}
