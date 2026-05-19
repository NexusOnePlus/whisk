import 'dart:math' as math;

import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';
import 'package:whisk/ui/features/editor/models/editor_text_position.dart';

class WhiskEditorBuffer {
  WhiskEditorBuffer(String text)
    : _original = text,
      _pieces = [if (text.isNotEmpty) _TextPiece.original(0, text.length)] {
    _rebuildMaterializedState();
  }

  String _original;
  final StringBuffer _addBuffer = StringBuffer();
  List<_TextPiece> _pieces;
  String _text = '';
  List<int> _lineStarts = const [0];

  String get text => _text;
  int get length => _text.length;
  List<int> get lineStarts => List.unmodifiable(_lineStarts);
  int get lineCount => _lineStarts.length;

  EditorTextPosition positionForOffset(int offset) {
    final line = lineForOffset(offset);
    return EditorTextPosition(line: line, column: columnForOffset(offset));
  }

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
    final clamped = offset.clamp(0, _text.length);
    final line = lineForOffset(clamped);
    return clamped - _lineStarts[line];
  }

  int offsetForPosition(EditorTextPosition position) {
    if (_lineStarts.isEmpty) return 0;
    final line = position.line.clamp(0, _lineStarts.length - 1);
    final lineStart = _lineStarts[line];
    final lineEnd = line + 1 < _lineStarts.length
        ? _lineStarts[line + 1] - 1
        : _text.length;
    return (lineStart + position.column).clamp(lineStart, lineEnd);
  }

  String lineText(int line) {
    if (_lineStarts.isEmpty) return '';
    final safeLine = line.clamp(0, _lineStarts.length - 1);
    final start = _lineStarts[safeLine];
    var end = safeLine + 1 < _lineStarts.length
        ? _lineStarts[safeLine + 1] - 1
        : _text.length;
    if (end > start && _text.codeUnitAt(end - 1) == 13) end--;
    return _text.substring(start, end);
  }

  ({int firstLine, int lastLine}) visibleLineRange({
    required double scrollOffset,
    required double viewportHeight,
    required double lineHeight,
    int overscan = 6,
  }) {
    if (lineHeight <= 0 || lineCount == 0) {
      return (firstLine: 0, lastLine: 0);
    }
    final first = math.max(0, (scrollOffset / lineHeight).floor() - overscan);
    final last = math.min(
      lineCount - 1,
      ((scrollOffset + viewportHeight) / lineHeight).ceil() + overscan,
    );
    return (firstLine: first, lastLine: last);
  }

  EditorTextOperation replace({
    required int start,
    required int end,
    required String text,
  }) {
    final safeStart = start.clamp(0, _text.length);
    final safeEnd = end.clamp(safeStart, _text.length);
    final deleted = _text.substring(safeStart, safeEnd);
    
    _replacePieces(safeStart, safeEnd, text);
    _text = _text.replaceRange(safeStart, safeEnd, text);
    
    _updateLineStartsIncremental(
      offset: safeStart,
      deletedLength: deleted.length,
      insertedText: text,
    );
    
    return EditorTextOperation(
      offset: safeStart,
      deletedText: deleted,
      insertedText: text,
    );
  }

  void _updateLineStartsIncremental({
    required int offset,
    required int deletedLength,
    required String insertedText,
  }) {
    final oldEnd = offset + deletedLength;
    final delta = insertedText.length - deletedLength;

    final newStarts = <int>[];
    
    // 1. Keep line starts before and at the edit offset
    for (final start in _lineStarts) {
      if (start <= offset) {
        newStarts.add(start);
      }
    }

    // 2. Scan the inserted text for newlines
    for (var i = 0; i < insertedText.length; i++) {
      if (insertedText.codeUnitAt(i) == 10) {
        newStarts.add(offset + i + 1);
      }
    }

    // 3. Keep line starts after the edit, shifted by delta
    for (final start in _lineStarts) {
      if (start > oldEnd) {
        newStarts.add(start + delta);
      }
    }

    _lineStarts = newStarts;
    if (_lineStarts.isEmpty || _lineStarts[0] != 0) {
      _lineStarts.insert(0, 0);
    }
  }

  void replaceBatch(List<({int start, int end, String text})> edits) {
    final ordered = [...edits]..sort((a, b) => b.start.compareTo(a.start));
    for (final edit in ordered) {
      final currentLength = _pieceLength;
      final safeStart = edit.start.clamp(0, currentLength);
      final safeEnd = edit.end.clamp(safeStart, currentLength);
      _replacePieces(safeStart, safeEnd, edit.text);
    }
    _rebuildMaterializedState();
  }

  void apply(EditorTextOperation operation) {
    replace(
      start: operation.offset,
      end: operation.offset + operation.deletedText.length,
      text: operation.insertedText,
    );
  }

  void setText(String text) {
    _original = text;
    _addBuffer.clear();
    _pieces = [if (text.isNotEmpty) _TextPiece.original(0, text.length)];
    _rebuildMaterializedState();
  }

  void _replacePieces(int start, int end, String insertedText) {
    final before = _slicePieces(0, start);
    final after = _slicePieces(end, _pieceLength);
    final inserted = <_TextPiece>[];
    if (insertedText.isNotEmpty) {
      final addStart = _addBuffer.length;
      _addBuffer.write(insertedText);
      inserted.add(_TextPiece.add(addStart, insertedText.length));
    }
    _pieces = [...before, ...inserted, ...after];
  }

  int get _pieceLength {
    var total = 0;
    for (final piece in _pieces) {
      total += piece.length;
    }
    return total;
  }

  List<_TextPiece> _slicePieces(int start, int end) {
    if (start >= end) return const [];
    final result = <_TextPiece>[];
    var cursor = 0;
    for (final piece in _pieces) {
      final pieceStart = cursor;
      final pieceEnd = cursor + piece.length;
      if (pieceEnd <= start) {
        cursor = pieceEnd;
        continue;
      }
      if (pieceStart >= end) break;

      final localStart = math.max(start, pieceStart) - pieceStart;
      final localEnd = math.min(end, pieceEnd) - pieceStart;
      result.add(
        piece.copyWith(
          start: piece.start + localStart,
          length: localEnd - localStart,
        ),
      );
      cursor = pieceEnd;
    }
    return result;
  }

  void _rebuildMaterializedState() {
    final buffer = StringBuffer();
    final addText = _addBuffer.toString();
    for (final piece in _pieces) {
      final source = piece.source == _PieceSource.original
          ? _original
          : addText;
      buffer.write(source.substring(piece.start, piece.start + piece.length));
    }
    _text = buffer.toString();
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

enum _PieceSource { original, add }

class _TextPiece {
  const _TextPiece({
    required this.source,
    required this.start,
    required this.length,
  });

  factory _TextPiece.original(int start, int length) {
    return _TextPiece(
      source: _PieceSource.original,
      start: start,
      length: length,
    );
  }

  factory _TextPiece.add(int start, int length) {
    return _TextPiece(source: _PieceSource.add, start: start, length: length);
  }

  final _PieceSource source;
  final int start;
  final int length;

  _TextPiece copyWith({required int start, required int length}) {
    return _TextPiece(source: source, start: start, length: length);
  }
}
