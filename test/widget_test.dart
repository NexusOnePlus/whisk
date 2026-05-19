import 'package:flutter_test/flutter_test.dart';

import 'package:whisk/main.dart';

void main() {
  testWidgets('shows the project dashboard', (tester) async {
    await tester.pumpWidget(const WhiskApp());

    expect(find.text('Create, reopen and collaborate across renderable projects.'), findsOneWidget);
    expect(find.text('New Project'), findsOneWidget);
    expect(find.text('LaTeX Draft'), findsOneWidget);
    expect(find.text('Typst Project'), findsOneWidget);
    expect(find.text('Open Projects'), findsOneWidget);
  });

  testWidgets('shows collaboration entry points', (tester) async {
    await tester.pumpWidget(const WhiskApp());

    expect(find.text('Collaboration'), findsOneWidget);
    expect(find.text('Local instance'), findsOneWidget);
    expect(find.text('Second perspective'), findsOneWidget);
  });
}
