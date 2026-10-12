import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codekit_qa_app/qa_app.dart';
import 'package:codekit_qa_app/qa_services.dart';

void main() {
  testWidgets('QA app exposes the configured diagnostics viewer', (
    tester,
  ) async {
    final services = QaServices.forTest();
    addTearDown(services.close);

    await tester.pumpWidget(QaApp(services: services));

    expect(find.text('CodeKit integration QA'), findsOneWidget);
    expect(find.text('Open diagnostics viewer'), findsOneWidget);
    await tester.tap(find.text('Open diagnostics viewer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('CodeKit settings'), findsOneWidget);
    expect(find.text('Memory (test)'), findsWidgets);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(find.text('Headers: x-qa-secret'), findsOneWidget);
  });
}
