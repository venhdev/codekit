import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
  final directory = await getTemporaryDirectory();
  final path =
      '${directory.path}${Platform.pathSeparator}'
      'codekit-${DateTime.now().microsecondsSinceEpoch}.txt';
  final file = await File(path).writeAsString(text);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'text/plain')],
      fileNameOverrides: ['codekit-diagnostics.txt'],
      downloadFallbackEnabled: false,
    ),
  );
}
