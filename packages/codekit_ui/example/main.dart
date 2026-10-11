import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_ui/codekit_ui.dart';
import 'package:flutter/material.dart';

void main() {
  final diagnostics = CodeKitDiagnostics();
  diagnostics.log(const LogInput(message: 'CodeKit UI example started'));
  runApp(_ExampleApp(diagnostics: diagnostics));
}

class _ExampleApp extends StatelessWidget {
  _ExampleApp({required this.diagnostics});

  final CodeKitDiagnostics diagnostics;
  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    builder: (context, child) => CodeKitBubble(
      diagnostics: diagnostics,
      navigatorKey: navigatorKey,
      child: child!,
    ),
    home: Scaffold(
      appBar: AppBar(title: const Text('CodeKit UI example')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => diagnostics.log(
            const LogInput(message: 'Example button pressed'),
          ),
          child: const Text('Write diagnostic log'),
        ),
      ),
    ),
  );
}
