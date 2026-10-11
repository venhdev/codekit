import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<bool> shareText(String text) async {
  final result = await SharePlus.instance.share(
    ShareParams(
      text: text,
      mailToFallbackEnabled: false,
      downloadFallbackEnabled: false,
    ),
  );
  if (result.status == ShareResultStatus.unavailable) {
    throw StateError('Share unavailable');
  }
  return result.status == ShareResultStatus.success;
}

Future<bool> shareFile(String text) async {
  final directory = await getTemporaryDirectory();
  final path =
      '${directory.path}${Platform.pathSeparator}'
      'codekit-${DateTime.now().microsecondsSinceEpoch}.txt';
  final file = await File(path).writeAsString(text);
  final result = await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'text/plain')],
      fileNameOverrides: ['codekit-diagnostics.txt'],
      downloadFallbackEnabled: false,
    ),
  );
  if (result.status == ShareResultStatus.unavailable) {
    throw StateError('Share unavailable');
  }
  return result.status == ShareResultStatus.success;
}
