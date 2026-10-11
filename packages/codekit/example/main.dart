import 'package:codekit/codekit.dart';

Future<void> main() async {
  final diagnostics = CodeKitDiagnostics(sinks: [ColoredConsoleSink()]);
  await diagnostics
      .log(const LogInput(message: 'CodeKit is ready'))
      .persistedOrNull();
  await diagnostics.dispose();
}
