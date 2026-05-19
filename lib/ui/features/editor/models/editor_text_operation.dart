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
    required this.cursorOffsetsBefore,
    required this.cursorOffsetsAfter,
  });

  final List<EditorTextOperation> operations;
  final int selectionOffsetBefore;
  final int selectionOffsetAfter;
  final List<int> cursorOffsetsBefore;
  final List<int> cursorOffsetsAfter;

  factory EditorTextTransaction.single({
    required EditorTextOperation operation,
    required int selectionOffsetBefore,
    required int selectionOffsetAfter,
    List<int> cursorOffsetsBefore = const [],
    List<int> cursorOffsetsAfter = const [],
  }) {
    return EditorTextTransaction(
      operations: [operation],
      selectionOffsetBefore: selectionOffsetBefore,
      selectionOffsetAfter: selectionOffsetAfter,
      cursorOffsetsBefore: cursorOffsetsBefore,
      cursorOffsetsAfter: cursorOffsetsAfter,
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
