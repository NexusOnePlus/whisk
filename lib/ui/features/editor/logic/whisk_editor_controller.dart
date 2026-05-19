import 'package:flutter/material.dart';
import 'package:whisk/ui/features/editor/logic/syntax_highlighter.dart';
import 'package:whisk/ui/features/editor/logic/whisk_editor_buffer.dart';
import 'package:whisk/ui/features/editor/models/editor_selection_range.dart';
import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';

class WhiskEditorController extends TextEditingController {
  WhiskEditorController({
    required String text,
    required this.environmentId,
    this.highlighter = const SyntaxHighlighter(),
  }) : buffer = WhiskEditorBuffer(text),
       super(text: text);

  final WhiskEditorBuffer buffer;
  final SyntaxHighlighter highlighter;
  String environmentId;
  List<EditorSelectionRange> secondarySelections = const [];
  List<EditorSelectionRange> activeCursors = const [];

  final List<EditorTextTransaction> _undoStack = [];
  final List<EditorTextTransaction> _redoStack = [];
  var _applyingHistory = false;
  var _syncingFromModel = false;
  var _applyingCursors = false;

  @override
  set value(TextEditingValue newValue) {
    final oldValue = value;
    final oldText = text;
    if (!_applyingHistory && !_syncingFromModel && !_applyingCursors) {
      if (oldText != newValue.text) {
        final operation = _operationFromDiff(oldText, newValue.text);
        if (operation != null) {
          if (activeCursors.isNotEmpty && oldValue.selection.isCollapsed) {
            _applyWithCursors(
              primaryDelta: operation,
              oldPrimaryOffset: oldValue.selection.extentOffset,
            );
            return;
          }
          _undoStack.add(
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
        }
      }
    }
    super.value = newValue;
    if (oldText != newValue.text) {
      buffer.setText(newValue.text);
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
        cursorOffsetsBefore: _cursorOffsets,
        cursorOffsetsAfter: const [],
      ),
    );
    _redoStack.clear();
    activeCursors = const [];
    _setValueFromBuffer(selectionOffset: newSelectionOffset);
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

  void _applyWithCursors({
    required EditorTextOperation primaryDelta,
    required int oldPrimaryOffset,
  }) {
    _applyingCursors = true;
    try {
      final relativeEditStart = primaryDelta.offset - oldPrimaryOffset;
      final cursorOrigins = <int>{
        for (final c in activeCursors) c.baseOffset,
        oldPrimaryOffset,
      }.toList()..sort();
      final editStarts =
          cursorOrigins
              .map((offset) => offset + relativeEditStart)
              .map((offset) => offset.clamp(0, buffer.length))
              .toSet()
              .toList()
            ..sort();
      final edits = <_CursorEdit>[
        for (final offset in editStarts)
          _CursorEdit(offset: offset, length: primaryDelta.deletedText.length),
      ];
      edits.sort((a, b) => b.offset.compareTo(a.offset));

      final operations = <EditorTextOperation>[];
      for (final edit in edits) {
        operations.add(
          buffer.replace(
            start: edit.offset,
            end: edit.offset + edit.length,
            text: primaryDelta.insertedText,
          ),
        );
      }

      final delta =
          primaryDelta.insertedText.length - primaryDelta.deletedText.length;
      int transformedOffset(int offset) {
        var shifted = offset + primaryDelta.insertedText.length;
        for (final editOffset in editStarts) {
          if (editOffset >= offset) break;
          shifted += delta;
        }
        return shifted.clamp(0, buffer.length);
      }

      final primaryOffset = transformedOffset(oldPrimaryOffset);
      final newCursors = activeCursors
          .where((cursor) => cursor.baseOffset != oldPrimaryOffset)
          .map((cursor) => transformedOffset(cursor.baseOffset))
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

      _undoStack.add(
        EditorTextTransaction(
          operations: operations,
          selectionOffsetBefore: oldPrimaryOffset.clamp(0, text.length),
          selectionOffsetAfter: primaryOffset,
          cursorOffsetsBefore: _cursorOffsets,
          cursorOffsetsAfter: [
            for (final cursor in newCursors) cursor.baseOffset,
          ],
        ),
      );
      _redoStack.clear();
      activeCursors = newCursors;
      notifyListeners();
    } finally {
      _applyingCursors = false;
    }
  }

  bool undoEdit() {
    if (_undoStack.isEmpty) return false;
    final transaction = _undoStack.removeLast();
    _applyOperations(transaction.inverseOperations());
    _redoStack.add(transaction);
    _setValueFromBuffer(
      selectionOffset: transaction.selectionOffsetBefore,
      cursorOffsets: transaction.cursorOffsetsBefore,
    );
    return true;
  }

  bool redoEdit() {
    if (_redoStack.isEmpty) return false;
    final transaction = _redoStack.removeLast();
    _applyOperations(transaction.operations);
    _undoStack.add(transaction);
    _setValueFromBuffer(
      selectionOffset: transaction.selectionOffsetAfter,
      cursorOffsets: transaction.cursorOffsetsAfter,
    );
    return true;
  }

  void _applyOperations(List<EditorTextOperation> operations) {
    final ordered = [...operations]
      ..sort((a, b) => b.offset.compareTo(a.offset));
    for (final operation in ordered) {
      buffer.apply(operation);
    }
  }

  void _setValueFromBuffer({
    required int selectionOffset,
    List<int> cursorOffsets = const [],
  }) {
    _applyingHistory = true;
    try {
      activeCursors = [
        for (final offset in cursorOffsets)
          EditorSelectionRange(
            baseOffset: offset.clamp(0, buffer.length),
            extentOffset: offset.clamp(0, buffer.length),
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

  List<int> get _cursorOffsets => [
    for (final cursor in activeCursors) cursor.baseOffset,
  ];

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
    return highlighter.highlight(
      text: text,
      environmentId: environmentId,
      baseStyle: style ?? const TextStyle(),
    );
  }
}

class _CursorEdit {
  _CursorEdit({required this.offset, required this.length});
  final int offset;
  final int length;
}
