import 'dart:convert';

String stringify(dynamic input) {
  if (input == null) {
    return ''; // Handles null values, returns an empty string
  }
  if (input is String) {
    return input; // If it's already a string, return it directly
  }

  // If it's a function, call it to get the actual value
  // Otherwise, use the text itself
  final dynamic finalText = input is Function ? input() : input;

  // Handle Maps and Iterables (Lists, Sets) by converting them to JSON strings
  if (finalText is Map || finalText is Iterable) {
    try {
      // Using JsonEncoder with no indent for a compact string
      var encoder = const JsonEncoder.withIndent(null);
      return encoder.convert(finalText);
    } catch (e) {
      // Fallback in case of JSON encoding errors (e.g., non-serializable objects within Map/Iterable)
      return finalText.toString();
    }
  } else {
    // For all other types (numbers, booleans, custom objects, etc.),
    // use their default toString() representation.
    return finalText.toString();
  }
}

/// Appends a [suffix] after every occurrence of a [pattern] within a [src] string.
///
/// If [pattern] is not found in [src], the original [src] string is returned.
///
/// Parameters:
/// - [src] The original string to search within.
/// - [pattern] The substring to search for.
/// - [suffix] The string to append after each occurrence of [pattern].
///
/// Returns: The modified string with [suffix] appended after each [pattern].
String stringAppendAfterSubstring({
  required String src,
  required String pattern,
  required String suffix,
}) {
  int index = src.indexOf(pattern);
  if (index == -1) {
    return src;
  }

  final patternLength = pattern.length;
  int endIndex = 0;
  String returnValue = '';
  do {
    returnValue += src.substring(endIndex, index) + pattern + suffix;
    endIndex = index + patternLength;
    index = src.indexOf(pattern, endIndex);
  } while (index != -1);

  returnValue += src.substring(endIndex);
  return returnValue;
}

/// Removes all ANSI escape codes from the input string, returning plain text.
/// Handles sequences like \x1B[1m, \x1B[38;5;208m, \x1B[0m, etc.
String strip(String input) {
  // Match ANSI escape sequences: \x1B[ followed by digits, semicolons, and ending with 'm'
  final ansiPattern = RegExp(r'\x1B\[[\d;]*m');
  return input.replaceAll(ansiPattern, '');
}
