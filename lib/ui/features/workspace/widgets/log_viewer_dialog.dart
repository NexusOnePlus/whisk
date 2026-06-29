import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

enum LogCategory { render, collab, lsp, system }

class LogEntry {
  const LogEntry({
    required this.category,
    required this.message,
    required this.timestamp,
  });

  final LogCategory category;
  final String message;
  final DateTime timestamp;
}

class LogBuffer {
  LogBuffer._();

  static final _entries = <LogEntry>[];
  static final _listeners = <VoidCallback>[];

  static Iterable<LogEntry> get entries => _entries;
  static Iterable<String> get lines =>
      _entries.map((e) => '[${_name(e.category)}] ${e.message}');
  static String get text => _entries
      .map((e) => '[${_name(e.category)}] ${e.message}')
      .join();

  static void write(LogCategory category, String line) {
    _entries.add(LogEntry(category: category, message: line, timestamp: DateTime.now()));
    for (final l in _listeners) {
      l();
    }
  }

  static void writeln(LogCategory category, String line) =>
      write(category, '$line\n');

  static void clear() {
    _entries.clear();
    for (final l in _listeners) {
      l();
    }
  }

  static VoidCallback listen(VoidCallback cb) {
    _listeners.add(cb);
    return () => _listeners.remove(cb);
  }

  static String _name(LogCategory c) => switch (c) {
    LogCategory.render => 'render',
    LogCategory.collab => 'collab',
    LogCategory.lsp => 'lsp',
    LogCategory.system => 'system',
  };
}

class LogViewerDialog extends StatefulWidget {
  const LogViewerDialog({super.key});

  @override
  State<LogViewerDialog> createState() => _LogViewerDialogState();
}

class _LogViewerDialogState extends State<LogViewerDialog> {
  final _scrollCtrl = ScrollController();
  final _visible = LogCategory.values.toSet();
  List<LogEntry> _entries = List.from(LogBuffer.entries);

  @override
  void initState() {
    super.initState();
    LogBuffer.listen(_onLogChanged);
  }

  void _onLogChanged() {
    if (!mounted) return;
    setState(() => _entries = List.from(LogBuffer.entries));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _copy() {
    final text = _entries
        .where((e) => _visible.contains(e.category))
        .map((e) => '[${_catName(e.category)}] ${e.message}')
        .join();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  void _clear() {
    LogBuffer.clear();
  }

  void _toggleCategory(LogCategory c) {
    setState(() {
      if (_visible.contains(c)) {
        if (_visible.length > 1) _visible.remove(c);
      } else {
        _visible.add(c);
      }
    });
  }

  String _catName(LogCategory c) => switch (c) {
    LogCategory.render => 'render',
    LogCategory.collab => 'collab',
    LogCategory.lsp => 'lsp',
    LogCategory.system => 'system',
  };

  Color _catColor(LogCategory c) => switch (c) {
    LogCategory.render => kAccentBlue,
    LogCategory.collab => kSuccessGreen,
    LogCategory.lsp => kAccentAmber,
    LogCategory.system => kTextMuted,
  };

  @override
  Widget build(BuildContext context) {
    final filtered = _entries.where((e) => _visible.contains(e.category));

    return AlertDialog(
      backgroundColor: const Color(0xFF1E2228),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorder),
      ),
      title: Row(
        children: [
          const Icon(Icons.terminal, color: kTextSecondary, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Logs',
            style: TextStyle(
              color: kTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Copy all',
            onPressed: _copy,
            icon: const Icon(Icons.copy, size: 16),
            color: kTextSecondary,
            style: IconButton.styleFrom(
              backgroundColor: kGlassHighlight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: kBorder),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Clear',
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline, size: 16),
            color: kTextSecondary,
            style: IconButton.styleFrom(
              backgroundColor: kGlassHighlight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: kBorder),
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          children: [
            Row(
              children: [
                for (final c in LogCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _CategoryChip(
                      label: _catName(c),
                      color: _catColor(c),
                      selected: _visible.contains(c),
                      onTap: () => _toggleCategory(c),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.terminal, color: kTextMuted, size: 32),
                          const SizedBox(height: 12),
                          const Text(
                            'No matching logs',
                            style: TextStyle(color: kTextMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      controller: _scrollCtrl,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final entry in filtered)
                            _LogLine(entry: entry, catColor: _catColor(entry.category)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(color: kTextMuted)),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : color.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.entry, required this.catColor});

  final LogEntry entry;
  final Color catColor;

  @override
  Widget build(BuildContext context) {
    final ts = entry.timestamp;
    final time =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: time,
              style: const TextStyle(
                color: kTextMuted,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
            const TextSpan(text: ' '),
            TextSpan(
              text: entry.message,
              style: const TextStyle(
                color: kTextSecondary,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
