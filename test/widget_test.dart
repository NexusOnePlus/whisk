import 'package:flutter_test/flutter_test.dart';

import 'package:whisk/main.dart';

void main() {
  testWidgets('shows the initial authoring workspace', (tester) async {
    await tester.pumpWidget(const WhiskApp());

    expect(find.text('LaTeX'), findsWidgets);
    expect(find.text('Typst'), findsOneWidget);
    expect(find.text('Mermaid'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Render'), findsOneWidget);
  });

  testWidgets('switches between environments', (tester) async {
    await tester.pumpWidget(const WhiskApp());

    await tester.tap(find.text('Mermaid').first);
    await tester.pump();

    expect(find.text('Mermaid engine'), findsOneWidget);
    expect(find.text('Source .mmd'), findsOneWidget);
  });
}
