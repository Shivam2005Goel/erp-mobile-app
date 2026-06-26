// Basic smoke test for the Argmac ERP app shell.
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_app/app_state.dart';
import 'package:my_first_app/main.dart';

void main() {
  testWidgets('App boots to the landing screen', (WidgetTester tester) async {
    await tester.pumpWidget(ArgmacApp(appState: AppState()));
    await tester.pump();
    expect(find.text('Argmac ERP'), findsOneWidget);
  });
}
