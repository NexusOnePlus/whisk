import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/features/workspace/widgets/log_viewer_dialog.dart';

class CategorizedLogPanel extends StatefulWidget {
  const CategorizedLogPanel({super.key});

  @override
  State<CategorizedLogPanel> createState() => _CategorizedLogPanelState();
}

class _CategorizedLogPanelState extends State<CategorizedLogPanel> {
  final _scrollCtrl = ScrollController();
  final _visible = LogCategory.values.toSet();
  List<LogEntry> _entries = List.from(LogBuffer.entries);
  VoidCallback? _cancelListen;

  @override
  void initState() {
    super.initState();
    _cancelListen = LogBuffer.listen(_onLogChanged);
  }

  @override
  void dispose() {
    _cancelListen?.call();
    _scrollCtrl.dispose();
    super.dispose();
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

  void _toggleCategory(LogCategory c) {
    setState(() {
      if (_visible.contains(c)) {
        if (_visible.length > 1) _visible.remove(c);
      } else {
        _visible.add(c);
      }
    });
  }

  Color _catColor(LogCategory c) => switch (c) {
    LogCategory.render => kAccentBlue,
    LogCategory.collab => kSuccessGreen,
    LogCategory.lsp => kAccentAmber,
    LogCategory.system => kTextMuted,
  };

  String _catName(LogCategory c) => switch (c) {
    LogCategory.render => 'render',
    LogCategory.collab => 'collab',
    LogCategory.lsp => 'lsp',
    LogCategory.system => 'system',
  };

  @override
  Widget build(BuildContext context) {
    final filtered = _entries.where((e) => _visible.contains(e.category)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final c in LogCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _CategoryFilterChip(
                    label: _catName(c),
                    color: _catColor(c),
                    selected: _visible.contains(c),
                    onTap: () => _toggleCategory(c),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'No logs',
                    style: TextStyle(color: kTextMuted, fontSize: 11),
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final ts = entry.timestamp;
                    final time =
                        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
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
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            fontSize: 9,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
