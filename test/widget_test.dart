import 'package:flutter_test/flutter_test.dart';

import 'package:qnn_eco/main.dart';

void main() {
  testWidgets('shows the GenieX model catalogue', (WidgetTester tester) async {
    await tester.pumpWidget(const QnnEcoApp());

    expect(find.text('Available models'), findsOneWidget);
    expect(find.text('Qwen3 0.6B'), findsOneWidget);
  });
}
