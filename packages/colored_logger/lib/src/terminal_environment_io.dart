import 'dart:io';

bool get supportsAnsiEscapes => stdout.supportsAnsiEscapes;
bool get supportsStdout =>
    stdioType(stdout) == StdioType.terminal ||
    stdioType(stdout) == StdioType.pipe;
bool get isTest => Platform.script.path.split('/').last.startsWith('test.dart');
String get stdoutDescription =>
    '${stdioType(stdout)} and hasTerminal: ${stdout.hasTerminal}';

String terminalInfo() {
  String details(String name, Stdout stream) =>
      '[$name]\n type: ${stdioType(stream).name}'
      '\n ansi: ${stream.supportsAnsiEscapes}'
      '\n hasTerminal: ${stream.hasTerminal}'
      '\n terminalColumns: ${stream.hasTerminal ? stream.terminalColumns : 'none'}'
      '\n terminalLines: ${stream.hasTerminal ? stream.terminalLines : 'none'}'
      '\n encoding: ${stream.encoding.name}';
  return '${details('stdout', stdout)}\n'
      '[stdin]\n type: ${stdioType(stdin).name}'
      '\n ansi: ${stdin.supportsAnsiEscapes}'
      '\n hasTerminal: ${stdin.hasTerminal}\n'
      '${details('stderr', stderr)}';
}
