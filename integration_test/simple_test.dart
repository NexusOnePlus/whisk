import 'package:flutter_test/flutter_test.dart';
import 'package:whisk/main.dart';
import 'package:whisk/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('shows the Whisk app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const WhiskApp());
    expect(find.text('New Project'), findsOneWidget);
  });
}
