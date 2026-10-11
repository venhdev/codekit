bool get supportsAnsiEscapes => false;
bool get supportsStdout => false;
bool get isTest => false;
String get stdoutDescription => 'Web console (no terminal)';
String terminalInfo() => '[stdio] Terminal streams are unavailable on Web';
