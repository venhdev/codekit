import 'package:flutter/material.dart' show ThemeMode;

/// Optional host-provided configuration for the diagnostics viewer.
class CodeKitViewerSettings {
  const CodeKitViewerSettings({
    this.allowRuntimeRecordModeChanges = false,
    this.setupDetails = const [],
    this.initialThemeMode = ThemeMode.system,
  });

  /// Enables choosing the record mode for records accepted after the change.
  final bool allowRuntimeRecordModeChanges;

  /// Read-only host integration details, such as storage and client adapters.
  final List<CodeKitViewerSetupDetail> setupDetails;

  /// Initial viewer theme; runtime choices live for the viewer/bubble session.
  final ThemeMode initialThemeMode;
}

class CodeKitViewerSetupDetail {
  const CodeKitViewerSetupDetail({
    required this.label,
    required this.value,
    this.description,
  });

  final String label;
  final String value;
  final String? description;
}
