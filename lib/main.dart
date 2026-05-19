import 'package:flutter/material.dart';

void main() {
  runApp(const WhiskApp());
}

class WhiskApp extends StatelessWidget {
  const WhiskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whisk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      ),
      home: const WhiskHome(),
    );
  }
}

class EnvironmentKind {
  const EnvironmentKind({
    required this.name,
    required this.description,
    required this.extension,
    required this.icon,
    required this.sample,
  });

  final String name;
  final String description;
  final String extension;
  final IconData icon;
  final String sample;
}

const environments = <EnvironmentKind>[
  EnvironmentKind(
    name: 'LaTeX',
    description: 'Documents, papers and math-heavy writing.',
    extension: '.tex',
    icon: Icons.functions,
    sample: r'''\documentclass{article}
\begin{document}
\section{Whisk}
Write structured documents without leaving your workspace.
\end{document}''',
  ),
  EnvironmentKind(
    name: 'Typst',
    description: 'Fast technical documents with modern syntax.',
    extension: '.typ',
    icon: Icons.description_outlined,
    sample: '''= Whisk

Build documents, diagrams and notes from focused environments.''',
  ),
  EnvironmentKind(
    name: 'Mermaid',
    description: 'Flowcharts, sequence diagrams and architecture maps.',
    extension: '.mmd',
    icon: Icons.account_tree_outlined,
    sample: '''flowchart LR
  Idea --> Environment
  Environment --> Preview
  Preview --> Export''',
  ),
  EnvironmentKind(
    name: 'Notes',
    description: 'Plain writing for planning, drafts and context.',
    extension: '.md',
    icon: Icons.notes_outlined,
    sample: '''# Research notes

- Capture ideas
- Link them to an environment
- Render only when needed''',
  ),
];

class WhiskHome extends StatefulWidget {
  const WhiskHome({super.key});

  @override
  State<WhiskHome> createState() => _WhiskHomeState();
}

class _WhiskHomeState extends State<WhiskHome> {
  int selectedIndex = 0;
  late final TextEditingController controller;

  EnvironmentKind get selected => environments[selectedIndex];

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: selected.sample);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void selectEnvironment(int index) {
    setState(() {
      selectedIndex = index;
      controller.text = environments[index].sample;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 860;

            if (isCompact) {
              return Column(
                children: [
                  _TopBar(selected: selected),
                  _EnvironmentTabs(
                    selectedIndex: selectedIndex,
                    onSelected: selectEnvironment,
                  ),
                  Expanded(
                    child: _Workspace(
                      selected: selected,
                      controller: controller,
                      compact: true,
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                _Sidebar(
                  selectedIndex: selectedIndex,
                  onSelected: selectEnvironment,
                ),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(selected: selected),
                      Expanded(
                        child: _Workspace(
                          selected: selected,
                          controller: controller,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Text(
              'Whisk',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: environments.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final environment = environments[index];
                final selected = selectedIndex == index;

                return ListTile(
                  selected: selected,
                  selectedTileColor: const Color(0xFFEFF6FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: Icon(environment.icon),
                  title: Text(environment.name),
                  subtitle: Text(environment.extension),
                  onTap: () => onSelected(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentTabs extends StatelessWidget {
  const _EnvironmentTabs({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: environments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final environment = environments[index];
          final selected = selectedIndex == index;

          return ChoiceChip(
            selected: selected,
            label: Text(environment.name),
            avatar: Icon(environment.icon, size: 18),
            onSelected: (_) => onSelected(index),
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.selected});

  final EnvironmentKind selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Icon(selected.icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  selected.description,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.play_arrow),
            label: const Text('Render'),
          ),
        ],
      ),
    );
  }
}

class _Workspace extends StatelessWidget {
  const _Workspace({
    required this.selected,
    required this.controller,
    this.compact = false,
  });

  final EnvironmentKind selected;
  final TextEditingController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final editor = _EditorPane(selected: selected, controller: controller);
    final preview = _PreviewPane(selected: selected);

    if (compact) {
      return Column(
        children: [
          Expanded(child: editor),
          const Divider(height: 1),
          Expanded(child: preview),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: editor),
        const VerticalDivider(width: 1),
        Expanded(child: preview),
      ],
    );
  }
}

class _EditorPane extends StatelessWidget {
  const _EditorPane({required this.selected, required this.controller});

  final EnvironmentKind selected;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Source ${selected.extension}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: controller,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                height: 1.45,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({required this.selected});

  final EnvironmentKind selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Preview', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selected.name} engine',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Renderer adapter pending for ${selected.extension} files.',
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                  const Spacer(),
                  const LinearProgressIndicator(value: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
