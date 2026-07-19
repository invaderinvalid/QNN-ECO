import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qnn_eco/app/qnn_eco_app.dart';
import 'package:qnn_eco/features/model_setup/model_setup_screen.dart';

void main() {
  testWidgets('shows the application startup screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QnnEcoApp());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.byType(ModelSetupScreen), findsOneWidget);
  });
}
