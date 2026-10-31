import 'package:flutter_test/flutter_test.dart';

import 'package:regain_app/main.dart';

void main() {
  testWidgets('bottom nav switches between the four tabs', (tester) async {
    await tester.pumpWidget(const RegainApp());
    await tester.pumpAndSettle();

    expect(find.text('Coming in Phase 4'), findsOneWidget);

    for (final (tab, body) in [
      ('Focus', 'Coming in Phase 7'),
      ('Blocking', 'Coming in Phase 5'),
      ('Settings', 'Coming in Phase 2'),
      ('Dashboard', 'Coming in Phase 4'),
    ]) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(find.text(body).hitTestable(), findsOneWidget);
    }
  });
}
