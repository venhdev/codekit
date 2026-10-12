import 'package:flutter_test/flutter_test.dart';

import 'package:codekit_qa_app/qa_app.dart';
import 'package:codekit_qa_app/qa_services.dart';

void main() {
  testWidgets('QA app exposes the diagnostics entrypoint', (tester) async {
    final services = QaServices.forTest();
    addTearDown(services.close);

    await tester.pumpWidget(QaApp(services: services));

    expect(find.text('CodeKit integration QA'), findsOneWidget);
    expect(find.text('Open diagnostics viewer'), findsOneWidget);
    expect(find.text('Run safe API suite'), findsOneWidget);
  });
}
