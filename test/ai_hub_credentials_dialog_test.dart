import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qnn_eco/features/model_setup/widgets/ai_hub_credentials_dialog.dart';

void main() {
  testWidgets('cancelling the API key dialog leaves no framework exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDialog<AiHubCredentialsChange>(
                context: context,
                builder: (_) => const AiHubCredentialsDialog(
                  hasSavedApiKey: false,
                  requiredForDownload: true,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
