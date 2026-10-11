import 'native_export_delivery.dart'
    if (dart.library.js_interop) 'web_export_delivery.dart'
    as platform;

/// Delivery happens only after the caller has chosen the data representation.
Future<bool> shareDiagnosticText(String text) => platform.shareText(text);

/// On native platforms this shares a temporary file; Web downloads the file.
Future<bool> shareDiagnosticFile(String text) => platform.shareFile(text);
