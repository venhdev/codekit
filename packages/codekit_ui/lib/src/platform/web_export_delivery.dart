import 'dart:js_interop';

import 'package:share_plus/share_plus.dart';
import 'package:web/web.dart' as web;

Future<void> shareText(String text) async {
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      mailToFallbackEnabled: false,
      downloadFallbackEnabled: false,
    ),
  );
}

Future<void> shareFile(String text) async {
  final blob = web.Blob(
    <JSAny>[text.toJS].toJS,
    web.BlobPropertyBag(type: 'text/plain;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  try {
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = 'codekit-diagnostics.txt';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    await Future<void>.delayed(Duration.zero);
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
