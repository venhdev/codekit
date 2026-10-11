import 'package:codekit_console/codekit_console.dart';
import 'package:codekit_core/codekit_core.dart';

void main() {
  final diagnostics = CodeKitDiagnostics(sinks: [ColoredConsoleSink()]);
  diagnostics.log(const LogInput(message: 'Console example started'));
}
