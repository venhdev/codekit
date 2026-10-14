import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart' show ThemeMode, ValueChanged;

/// Optional host-provided configuration for the diagnostics viewer.
class CodeKitViewerSettings {
  const CodeKitViewerSettings({
    this.allowRuntimeRecordModeChanges = false,
    this.setupDetails = const [],
    this.initialThemeMode = ThemeMode.system,
    this.enableDevProxyOverride = true,
    this.devProxyConfig,
    this.devProxyProvider,
    this.onDevProxyConfigChanged,
  });

  /// Enables choosing the record mode for records accepted after the change.
  final bool allowRuntimeRecordModeChanges;

  /// Read-only host integration details, such as storage and client adapters.
  final List<CodeKitViewerSetupDetail> setupDetails;

  /// Initial viewer theme; runtime choices live for the viewer/bubble session.
  final ThemeMode initialThemeMode;

  /// Whether the dev proxy session override card is enabled in viewer settings.
  /// Defaults to `true`.
  final bool enableDevProxyOverride;

  /// Initial or static dev proxy configuration for this session.
  final DevProxyConfig? devProxyConfig;

  /// Optional dynamic provider callback resolving the current dev proxy configuration.
  final DevProxyConfig Function()? devProxyProvider;

  /// Callback invoked when dev proxy configuration is modified (toggled or edited)
  /// in the viewer settings.
  final ValueChanged<DevProxyConfig>? onDevProxyConfigChanged;

  /// Whether dev proxy section is shown in viewer settings.
  bool get hasDevProxySupport => enableDevProxyOverride;

  /// Current resolved dev proxy configuration.
  DevProxyConfig get currentDevProxyConfig =>
      devProxyProvider?.call() ?? devProxyConfig ?? const DevProxyConfig();

  CodeKitViewerSettings copyWith({
    bool? allowRuntimeRecordModeChanges,
    List<CodeKitViewerSetupDetail>? setupDetails,
    ThemeMode? initialThemeMode,
    bool? enableDevProxyOverride,
    DevProxyConfig? devProxyConfig,
    DevProxyConfig Function()? devProxyProvider,
    ValueChanged<DevProxyConfig>? onDevProxyConfigChanged,
  }) => CodeKitViewerSettings(
    allowRuntimeRecordModeChanges:
        allowRuntimeRecordModeChanges ?? this.allowRuntimeRecordModeChanges,
    setupDetails: setupDetails ?? this.setupDetails,
    initialThemeMode: initialThemeMode ?? this.initialThemeMode,
    enableDevProxyOverride:
        enableDevProxyOverride ?? this.enableDevProxyOverride,
    devProxyConfig: devProxyConfig ?? this.devProxyConfig,
    devProxyProvider: devProxyProvider ?? this.devProxyProvider,
    onDevProxyConfigChanged:
        onDevProxyConfigChanged ?? this.onDevProxyConfigChanged,
  );
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
