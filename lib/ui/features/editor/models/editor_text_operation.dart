import 'package:whisk/ui/features/editor/models/editor_selection_range.dart';

class EditorTextOperation {
  const EditorTextOperation({
    required this.offset,
    required this.deletedText,
    required this.insertedText,
  });

  final int offset;
  final String deletedText;
  final String insertedText;

  EditorTextOperation get inverse {
    return EditorTextOperation(
      offset: offset,
      deletedText: insertedText,
      insertedText: deletedText,
    );
  }
}

class EditorTextTransaction {
  const EditorTextTransaction({
    required this.operations,
    required this.selectionOffsetBefore,
    required this.selectionOffsetAfter,
    required this.cursorRangesBefore,
    required this.cursorRangesAfter,
  });

  final List<EditorTextOperation> operations;
  final int selectionOffsetBefore;
  final int selectionOffsetAfter;
  final List<EditorSelectionRange> cursorRangesBefore;
  final List<EditorSelectionRange> cursorRangesAfter;

  factory EditorTextTransaction.single({
    required EditorTextOperation operation,
    required int selectionOffsetBefore,
    required int selectionOffsetAfter,
    List<EditorSelectionRange> cursorRangesBefore = const [],
    List<EditorSelectionRange> cursorRangesAfter = const [],
  }) {
    return EditorTextTransaction(
      operations: [operation],
      selectionOffsetBefore: selectionOffsetBefore,
      selectionOffsetAfter: selectionOffsetAfter,
      cursorRangesBefore: cursorRangesBefore,
      cursorRangesAfter: cursorRangesAfter,
    );
  }

  bool canMergeWith(EditorTextTransaction next) {
    if (operations.length != next.operations.length) return false;
    if (cursorRangesAfter.length != next.cursorRangesBefore.length) {
      return false;
    }
    for (var index = 0; index < operations.length; index++) {
      final current = operations[index];
      final incoming = next.operations[index];
      if (current.deletedText.isNotEmpty || incoming.deletedText.isNotEmpty) {
        return false;
      }
      if (current.offset + current.insertedText.length != incoming.offset) {
        return false;
      }
    }
    return selectionOffsetAfter == next.selectionOffsetBefore;
  }

  EditorTextTransaction mergeWith(EditorTextTransaction next) {
    return EditorTextTransaction(
      operations: [
        for (var index = 0; index < operations.length; index++)
          EditorTextOperation(
            offset: operations[index].offset,
            deletedText: '',
            insertedText:
                operations[index].insertedText +
                next.operations[index].insertedText,
          ),
      ],
      selectionOffsetBefore: selectionOffsetBefore,
      selectionOffsetAfter: next.selectionOffsetAfter,
      cursorRangesBefore: cursorRangesBefore,
      cursorRangesAfter: next.cursorRangesAfter,
    );
  }

  List<EditorTextOperation> inverseOperations() {
    final inverse = <EditorTextOperation>[];
    for (final operation in operations) {
      final shiftBefore = operations
          .where((candidate) => candidate.offset < operation.offset)
          .fold<int>(
            0,
            (total, candidate) =>
                total +
                candidate.insertedText.length -
                candidate.deletedText.length,
          );
      inverse.add(
        EditorTextOperation(
          offset: operation.offset + shiftBefore,
          deletedText: operation.insertedText,
          insertedText: operation.deletedText,
        ),
      );
    }
    inverse.sort((a, b) => b.offset.compareTo(a.offset));
    return inverse;
  }
}
