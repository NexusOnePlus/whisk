import 'dart:async';

import 'package:flutter/material.dart';
import 'package:whisk/ui/features/editor/logic/syntax_highlighter.dart';
import 'package:whisk/ui/features/editor/logic/whisk_editor_buffer.dart';
import 'package:whisk/ui/features/editor/models/editor_selection_range.dart';
import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';
import 'package:whisk/ui/features/editor/models/editor_text_position.dart';

class WhiskEditorController extends TextEditingController {
  WhiskEditorController({
    required String text,
    required this.environmentId,
    SyntaxHighlighter? highlighter,
  }) : buffer = WhiskEditorBuffer(text),
       highlighter = highlighter ?? SyntaxHighlighter(),
       super(text: text);

  final WhiskEditorBuffer buffer;
  final SyntaxHighlighter highlighter;
  String environmentId;
  List<EditorSelectionRange> secondarySelections = const [];
  List<EditorSelectionRange> activeCursors = const [];
  final _textOperationsController =
      StreamController<List<EditorTextOperation>>.broadcast(sync: true);

  final List<EditorTextTransaction> _undoStack = [];
  final List<EditorTextTransaction> _redoStack = [];
  var _applyingHistory = false;
  var _syncingFromModel = false;
  var _applyingCursors = false;
  var _applyingRemote = false;
  String? _textBeforeComposition;
  TextSelection? _selectionBeforeComposition;

  Stream<List<EditorTextOperation>> get textOperations =>
      _textOperationsController.stream;

  @override
  void dispose() {
    _textOperationsController.close();
    super.dispose();
  }

  @override
  set value(TextEditingValue newValue) {
    final oldValue = value;
    final oldText = text;
    final isComposing =
        newValue.composing.isValid && !newValue.composing.isCollapsed;

    EditorTextOperation? operation;
    List<EditorTextOperation>? operationsToEmit;

    if (!_applyingHistory && !_syncingFromModel && !_applyingCursors) {
      if (isComposing) {
        _textBeforeComposition ??= oldText;
        _selectionBeforeComposition ??= oldValue.selection;
      } else if (_textBeforeComposition != null) {
        // Composition just finished
        final finalText = newValue.text;
        final op = _operationFromDiff(_textBeforeComposition!, finalText);
        if (op != null && activeCursors.isNotEmpty) {
          _applyWithCursors(
            primaryDelta: op,
            oldPrimarySelection: _selectionBeforeComposition!,
          );
          _textBeforeComposition = null;
          _selectionBeforeComposition = null;
          return;
        }
        _textBeforeComposition = null;
        _selectionBeforeComposition = null;
      }

      if (oldText != newValue.text) {
        operation = _operationFromDiff(oldText, newValue.text);
        if (operation != null && !isComposing) {
          if (activeCursors.isNotEmpty) {
            _applyWithCursors(
              primaryDelta: operation,
              oldPrimarySelection: oldValue.selection,
            );
            return;
          }
          _pushUndo(
            EditorTextTransaction.single(
              operation: operation,
              selectionOffsetBefore: oldValue.selection.extentOffset.clamp(
                0,
                oldText.length,
              ),
              selectionOffsetAfter: newValue.selection.extentOffset.clamp(
                0,
                newValue.text.length,
              ),
            ),
          );
          _redoStack.clear();
          operationsToEmit = [operation];
        }
      }
    }

    if (oldText != newValue.text) {
      if (!_applyingHistory &&
          !_syncingFromModel &&
          !_applyingCursors &&
          operation != null) {
        buffer.apply(operation);
      } else {
        buffer.setText(newValue.text);
      }
    }

    super.value = newValue;
    if (operationsToEmit != null) {
      _emitOperations(operationsToEmit);
    }
  }

  void setEnvironment(String id) {
    if (environmentId == id) return;
    environmentId = id;
    notifyListeners();
  }

  void setTextFromModel(String text) {
    if (this.text == text) return;
    _syncingFromModel = true;
    try {
      value = value.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange.empty,
      );
      buffer.setText(text);
      _undoStack.clear();
      _redoStack.clear();
    } finally {
      _syncingFromModel = false;
    }
  }

  void replaceRange({
    required int start,
    required int end,
    required String replacement,
  }) {
    final oldSelectionOffset = selection.extentOffset.clamp(0, text.length);
    final operation = buffer.replace(start: start, end: end, text: replacement);
    final newSelectionOffset = operation.offset + replacement.length;
    _undoStack.add(
      EditorTextTransaction.single(
        operation: operation,
        selectionOffsetBefore: oldSelectionOffset,
        selectionOffsetAfter: newSelectionOffset,
        cursorRangesBefore: activeCursors,
        cursorRangesAfter: const [],
      ),
    );
    _redoStack.clear();
    activeCursors = const [];
    _setValueFromBuffer(selectionOffset: newSelectionOffset);
    _emitOperations([operation]);
  }

  void applyRemoteOperation(EditorTextOperation operation) {
    _applyingRemote = true;
    try {
      final transformedSelection = _transformSelection(selection, operation);
      final transformedActiveCursors = [
        for (final cursor in activeCursors) _transformRange(cursor, operation),
      ];
      buffer.apply(operation);
      activeCursors = List.unmodifiable(transformedActiveCursors);
      super.value = TextEditingValue(
        text: buffer.text,
        selection: transformedSelection,
        composing: TextRange.empty,
      );
      notifyListeners();
    } finally {
      _applyingRemote = false;
    }
  }

  void setSecondarySelections(List<EditorSelectionRange> selections) {
    secondarySelections = List.unmodifiable(selections);
    notifyListeners();
  }

  void toggleActiveCursor(int offset) {
    final index = activeCursors.indexWhere((c) => c.baseOffset == offset);
    if (index >= 0) {
      activeCursors = [
        ...activeCursors.sublist(0, index),
        ...activeCursors.sublist(index + 1),
      ];
    } else {
      activeCursors = [
        ...activeCursors,
        EditorSelectionRange(baseOffset: offset, extentOffset: offset),
      ];
    }
    notifyListeners();
  }

  void clearActiveCursors() {
    if (activeCursors.isEmpty) return;
    activeCursors = const [];
    notifyListeners();
  }

  void setActiveSelections(List<EditorSelectionRange> selections) {
    activeCursors = List.unmodifiable(selections);
    notifyListeners();
  }

  void selectAll() {
    activeCursors = const [];
    value = value.copyWith(
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
      composing: TextRange.empty,
    );
    notifyListeners();
  }

  void moveSelections(
    EditorMoveDirection direction, {
    required bool expand,
    required bool byWord,
  }) {
    final primary = EditorSelectionRange(
      baseOffset: selection.baseOffset,
      extentOffset: selection.extentOffset,
    );
    final movedPrimary = _moveRange(
      primary,
      direction: direction,
      expand: expand,
      byWord: byWord,
    );
    final movedCursors = [
      for (final cursor in activeCursors)
        _moveRange(
          cursor,
          direction: direction,
          expand: expand,
          byWord: byWord,
        ),
    ];

    activeCursors = List.unmodifiable(movedCursors);
    value = value.copyWith(
      selection: TextSelection(
        baseOffset: movedPrimary.baseOffset.clamp(0, text.length),
        extentOffset: movedPrimary.extentOffset.clamp(0, text.length),
        affinity: _affinityForOffset(movedPrimary.extentOffset),
      ),
      composing: TextRange.empty,
    );
    notifyListeners();
  }

  void _applyWithCursors({
    required EditorTextOperation primaryDelta,
    required TextSelection oldPrimarySelection,
  }) {
    _applyingCursors = true;
    try {
      final primaryRange = EditorSelectionRange(
        baseOffset: oldPrimarySelection.baseOffset,
        extentOffset: oldPrimarySelection.extentOffset,
      );
      final relativeEditStart = primaryDelta.offset - primaryRange.start;
      final editRanges = <_CursorEdit>[
        _editForRange(primaryRange, primaryDelta, relativeEditStart),
        for (final cursor in activeCursors)
          _editForRange(cursor, primaryDelta, relativeEditStart),
      ]..sort((a, b) => b.offset.compareTo(a.offset));
      final uniqueEditRanges = <_CursorEdit>[];
      for (final edit in editRanges) {
        final overlapsExisting = uniqueEditRanges.any(
          (existing) =>
              edit.offset < existing.offset + existing.length &&
              existing.offset < edit.offset + edit.length,
        );
        if (!overlapsExisting) uniqueEditRanges.add(edit);
      }
      final edits = <_CursorEdit>[for (final edit in uniqueEditRanges) edit];

      final batchEdits = <({int start, int end, String text, String deleted})>[
        for (final edit in edits)
          (
            start: edit.offset,
            end: edit.offset + edit.length,
            text: primaryDelta.insertedText,
            deleted: buffer.text.substring(
              edit.offset,
              (edit.offset + edit.length).clamp(0, buffer.length),
            ),
          ),
      ];
      buffer.replaceBatch([
        for (final e in batchEdits) (start: e.start, end: e.end, text: e.text),
      ]);
      final operations = [
        for (final e in batchEdits)
          EditorTextOperation(
            offset: e.start,
            deletedText: e.deleted,
            insertedText: primaryDelta.insertedText,
          ),
      ];

      int transformedOffsetForEdit(_CursorEdit currentEdit) {
        var shifted = currentEdit.offset + primaryDelta.insertedText.length;
        for (final edit in uniqueEditRanges.reversed) {
          if (edit.offset >= currentEdit.offset) continue;
          shifted += primaryDelta.insertedText.length - edit.length;
        }
        return shifted.clamp(0, buffer.length);
      }

      final primaryEdit = _editForRange(
        primaryRange,
        primaryDelta,
        relativeEditStart,
      );
      final primaryOffset = transformedOffsetForEdit(primaryEdit);
      final newCursors = activeCursors
          .map(
            (cursor) => _editForRange(cursor, primaryDelta, relativeEditStart),
          )
          .where(
            (edit) =>
                edit.offset != primaryEdit.offset ||
                edit.length != primaryEdit.length,
          )
          .map(transformedOffsetForEdit)
          .map((o) => EditorSelectionRange(baseOffset: o, extentOffset: o))
          .toList();
      newCursors.sort((a, b) => a.baseOffset.compareTo(b.baseOffset));

      super.value = TextEditingValue(
        text: buffer.text,
        selection: TextSelection.collapsed(
          offset: primaryOffset.clamp(0, buffer.length),
        ),
        composing: TextRange.empty,
      );

      _pushUndo(
        EditorTextTransaction(
          operations: operations,
          selectionOffsetBefore: primaryRange.extentOffset.clamp(
            0,
            text.length,
          ),
          selectionOffsetAfter: primaryOffset,
          cursorRangesBefore: activeCursors,
          cursorRangesAfter: newCursors,
        ),
      );
      _redoStack.clear();
      activeCursors = newCursors;
      _emitOperations(operations);
      notifyListeners();
    } finally {
      _applyingCursors = false;
    }
  }

  _CursorEdit _editForRange(
    EditorSelectionRange range,
    EditorTextOperation primaryDelta,
    int relativeEditStart,
  ) {
    if (!range.isCollapsed) {
      return _CursorEdit(offset: range.start, length: range.end - range.start);
    }
    final offset = (range.baseOffset + relativeEditStart).clamp(
      0,
      buffer.length,
    );
    return _CursorEdit(offset: offset, length: primaryDelta.deletedText.length);
  }

  bool undoEdit() {
    if (_undoStack.isEmpty) return false;
    final transaction = _undoStack.removeLast();
    final operations = transaction.inverseOperations();
    _applyOperations(operations, emit: false);
    _redoStack.add(transaction);
    _setValueFromBuffer(
      selectionOffset: transaction.selectionOffsetBefore,
      cursorRanges: transaction.cursorRangesBefore,
    );
    _emitOperations(operations);
    return true;
  }

  bool redoEdit() {
    if (_redoStack.isEmpty) return false;
    final transaction = _redoStack.removeLast();
    final operations = transaction.operations;
    _applyOperations(operations, emit: false);
    _undoStack.add(transaction);
    _setValueFromBuffer(
      selectionOffset: transaction.selectionOffsetAfter,
      cursorRanges: transaction.cursorRangesAfter,
    );
    _emitOperations(operations);
    return true;
  }

  void _applyOperations(
    List<EditorTextOperation> operations, {
    bool emit = true,
  }) {
    final ordered = [...operations]
      ..sort((a, b) => b.offset.compareTo(a.offset));
    for (final operation in ordered) {
      buffer.apply(operation);
    }
    if (emit) _emitOperations(ordered);
  }

  void _setValueFromBuffer({
    required int selectionOffset,
    List<EditorSelectionRange> cursorRanges = const [],
  }) {
    _applyingHistory = true;
    try {
      activeCursors = [
        for (final range in cursorRanges)
          EditorSelectionRange(
            baseOffset: range.baseOffset.clamp(0, buffer.length),
            extentOffset: range.extentOffset.clamp(0, buffer.length),
          ),
      ];
      value = value.copyWith(
        text: buffer.text,
        selection: TextSelection.collapsed(
          offset: selectionOffset.clamp(0, buffer.length),
        ),
        composing: TextRange.empty,
      );
    } finally {
      _applyingHistory = false;
    }
  }

  void _pushUndo(EditorTextTransaction transaction) {
    if (_undoStack.isNotEmpty && _undoStack.last.canMergeWith(transaction)) {
      _undoStack[_undoStack.length - 1] = _undoStack.last.mergeWith(
        transaction,
      );
      return;
    }
    _undoStack.add(transaction);
  }

  void _emitOperations(List<EditorTextOperation> operations) {
    if (_applyingRemote ||
        _syncingFromModel ||
        _textOperationsController.isClosed ||
        operations.isEmpty) {
      return;
    }
    _textOperationsController.add(List.unmodifiable(operations));
  }

  TextSelection _transformSelection(
    TextSelection selection,
    EditorTextOperation operation,
  ) {
    if (!selection.isValid) return selection;
    return TextSelection(
      baseOffset: _transformOffset(selection.baseOffset, operation),
      extentOffset: _transformOffset(selection.extentOffset, operation),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  EditorSelectionRange _transformRange(
    EditorSelectionRange range,
    EditorTextOperation operation,
  ) {
    return EditorSelectionRange(
      baseOffset: _transformOffset(range.baseOffset, operation),
      extentOffset: _transformOffset(range.extentOffset, operation),
    );
  }

  int _transformOffset(int offset, EditorTextOperation operation) {
    final deletedEnd = operation.offset + operation.deletedText.length;
    final insertedEnd = operation.offset + operation.insertedText.length;
    if (offset <= operation.offset) return offset.clamp(0, buffer.length);
    if (offset >= deletedEnd) {
      final delta =
          operation.insertedText.length - operation.deletedText.length;
      return (offset + delta).clamp(0, buffer.length);
    }
    return insertedEnd.clamp(0, buffer.length);
  }

  EditorSelectionRange _moveRange(
    EditorSelectionRange range, {
    required EditorMoveDirection direction,
    required bool expand,
    required bool byWord,
  }) {
    final origin = range.extentOffset.clamp(0, text.length);
    final target = _moveOffset(origin, direction: direction, byWord: byWord);
    if (expand) {
      return EditorSelectionRange(
        baseOffset: range.baseOffset.clamp(0, text.length),
        extentOffset: target,
      );
    }
    return EditorSelectionRange(baseOffset: target, extentOffset: target);
  }

  int _moveOffset(
    int offset, {
    required EditorMoveDirection direction,
    required bool byWord,
  }) {
    return switch (direction) {
      EditorMoveDirection.left =>
        byWord
            ? _previousWordBoundary(offset)
            : (offset - 1).clamp(0, text.length),
      EditorMoveDirection.right =>
        byWord ? _nextWordBoundary(offset) : (offset + 1).clamp(0, text.length),
      EditorMoveDirection.up => _verticalOffset(offset, -1),
      EditorMoveDirection.down => _verticalOffset(offset, 1),
      EditorMoveDirection.home => _lineBoundary(offset, start: true),
      EditorMoveDirection.end => _lineBoundary(offset, start: false),
      EditorMoveDirection.pageUp => _verticalOffset(offset, -25),
      EditorMoveDirection.pageDown => _verticalOffset(offset, 25),
    };
  }

  int _lineBoundary(int offset, {required bool start}) {
    final position = buffer.positionForOffset(offset);
    if (start) {
      return buffer.lineStarts[position.line];
    } else {
      return buffer.lineStarts[position.line] +
          buffer.lineText(position.line).length;
    }
  }

  int _verticalOffset(int offset, int lineDelta) {
    final position = buffer.positionForOffset(offset);
    return buffer.offsetForPosition(
      EditorTextPosition(
        line: position.line + lineDelta,
        column: position.column,
      ),
    );
  }

  int _previousWordBoundary(int offset) {
    var cursor = offset.clamp(0, text.length);
    while (cursor > 0 && _isWhitespace(text.codeUnitAt(cursor - 1))) {
      cursor--;
    }
    while (cursor > 0 && !_isWhitespace(text.codeUnitAt(cursor - 1))) {
      cursor--;
    }
    return cursor;
  }

  int _nextWordBoundary(int offset) {
    var cursor = offset.clamp(0, text.length);
    while (cursor < text.length && !_isWhitespace(text.codeUnitAt(cursor))) {
      cursor++;
    }
    while (cursor < text.length && _isWhitespace(text.codeUnitAt(cursor))) {
      cursor++;
    }
    return cursor;
  }

  bool _isWhitespace(int codeUnit) {
    return codeUnit == 9 || codeUnit == 10 || codeUnit == 13 || codeUnit == 32;
  }

  TextAffinity _affinityForOffset(int offset) {
    final clamped = offset.clamp(0, text.length);
    if (clamped < text.length && text.codeUnitAt(clamped) == 10) {
      return TextAffinity.upstream;
    }
    return TextAffinity.downstream;
  }

  EditorTextOperation? _operationFromDiff(String oldText, String newText) {
    if (oldText == newText) return null;

    var prefix = 0;
    final minLength = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefix < minLength &&
        oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }

    var oldSuffix = oldText.length;
    var newSuffix = newText.length;
    while (oldSuffix > prefix &&
        newSuffix > prefix &&
        oldText.codeUnitAt(oldSuffix - 1) ==
            newText.codeUnitAt(newSuffix - 1)) {
      oldSuffix--;
      newSuffix--;
    }

    return EditorTextOperation(
      offset: prefix,
      deletedText: oldText.substring(prefix, oldSuffix),
      insertedText: newText.substring(prefix, newSuffix),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return TextSpan(text: text, style: style);
  }
}

class _CursorEdit {
  _CursorEdit({required this.offset, required this.length});
  final int offset;
  final int length;
}

enum EditorMoveDirection { left, right, up, down, home, end, pageUp, pageDown }
