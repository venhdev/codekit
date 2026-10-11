String genEscCodes(String input, {String label = '', bool toCompare = false}) {
  final buffer = StringBuffer();
  if (label.isNotEmpty) {
    buffer.write('$label: ');
  }

  for (final rune in input.runes) {
    if (rune >= 32 && rune <= 126) {
      // Printable ASCII characters
      buffer.write(String.fromCharCode(rune));
    } else if (rune == 27) {
      // ESC (\x1B)
      buffer.write(r'\x1B');
    } else if (rune < 32 || rune == 127) {
      // Other control characters (e.g., NUL, DEL)
      buffer.write(
        '\\x${rune.toRadixString(16).padLeft(2, '0').toUpperCase()}',
      );
    } else {
      // Non-ASCII or extended characters
      buffer.write(String.fromCharCode(rune));
    }
  }

  if (toCompare) {
    return buffer.toString().replaceAll('\\x1B', '\x1B');
  }

  return buffer.toString();
}

/// Prints the raw ANSI escape codes of a string to the console for debugging.
/// Each character is displayed as either a printable character or an escaped
/// control code (e.g., '\x1B' for ESC).
void printEscCodes(String input, {String label = ''}) {
  print(genEscCodes(input, label: label));
}
