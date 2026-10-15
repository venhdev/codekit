import 'dart:convert';

// Internal whole-value detector. Decodes at most twelve prefix bytes.
final _syntax = RegExp(r'^(?:[A-Za-z0-9+/]*|[A-Za-z0-9_-]*)(?:={0,2})$');
bool isBase64Image(String value) {
  try {
    return _inspect(value) != null;
  } on FormatException {
    return false;
  }
}

String? _inspect(String value) {
  var s = value;
  if (s.startsWith('data:')) {
    final comma = s.indexOf(',');
    if (comma < 0 || !s.substring(0, comma).endsWith(';base64')) return null;
    s = s.substring(comma + 1);
  }
  if (s.isEmpty || !_syntax.hasMatch(s) || s.endsWith('\n')) return null;
  final n = !s.contains('=') ? s.length : s.indexOf('=');
  final padding = s.length - n;
  if (n % 4 == 1 ||
      (padding > 0 && (s.length % 4 != 0 || padding != (4 - n % 4) % 4))) {
    return null;
  }
  // Validate canonical trailing bits on just the final partial quartet.
  if (n % 4 != 0) {
    final tail = s.substring(n - n % 4, n);
    final decoded = base64.decode(base64.normalize(tail));
    final canonical = base64UrlEncode(decoded).replaceAll('=', '');
    if (canonical != tail.replaceAll('+', '-').replaceAll('/', '_')) {
      return null;
    }
  }
  final head = base64.decode(base64.normalize(s.substring(0, n < 16 ? n : 16)));
  bool starts(List<int> b) =>
      head.length >= b.length &&
      List.generate(b.length, (i) => head[i] == b[i]).every((v) => v);
  if (starts([137, 80, 78, 71, 13, 10, 26, 10])) return 'png';
  if (starts([255, 216, 255])) return 'jpeg';
  if (starts(ascii.encode('GIF87a')) || starts(ascii.encode('GIF89a'))) {
    return 'gif';
  }
  if (starts(ascii.encode('RIFF')) &&
      head.length >= 12 &&
      ascii.decode(head.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    return 'webp';
  }
  return null;
}
