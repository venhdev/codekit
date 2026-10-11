import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/foundation.dart';

/// Installs error hooks while preserving callbacks owned by the application.
///
/// Install after the application's error handlers are configured. If other code
/// replaces a handler later, dispose leaves that new handler untouched.
final class CodeKitFlutterErrorHooks {
  CodeKitFlutterErrorHooks._(this._previousFlutter, this._previousPlatform);

  static CodeKitFlutterErrorHooks? _active;

  final FlutterExceptionHandler? _previousFlutter;
  final ErrorCallback? _previousPlatform;
  late final FlutterExceptionHandler _flutterHandler;
  late final ErrorCallback _platformHandler;
  bool _disposed = false;

  static CodeKitFlutterErrorHooks install(CodeKitDiagnostics diagnostics) {
    if (_active != null) {
      throw StateError('CodeKit Flutter error hooks are already installed');
    }
    final dispatcher = PlatformDispatcher.instance;
    final hooks = CodeKitFlutterErrorHooks._(
      FlutterError.onError,
      dispatcher.onError,
    );
    hooks._flutterHandler = (details) {
      diagnostics.log(
        LogInput(
          message: details.exceptionAsString(),
          level: LogLevel.error,
          error: details.exception,
          stackTrace: details.stack,
          source: details.library ?? 'Flutter',
        ),
      );
      hooks._previousFlutter?.call(details);
    };
    hooks._platformHandler = (error, stack) {
      diagnostics.log(
        LogInput(
          message: error.toString(),
          level: LogLevel.fatal,
          error: error,
          stackTrace: stack,
          source: 'PlatformDispatcher',
        ),
      );
      return hooks._previousPlatform?.call(error, stack) ?? false;
    };
    FlutterError.onError = hooks._flutterHandler;
    dispatcher.onError = hooks._platformHandler;
    _active = hooks;
    return hooks;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _active = null;
    if (identical(FlutterError.onError, _flutterHandler)) {
      FlutterError.onError = _previousFlutter;
    }
    final dispatcher = PlatformDispatcher.instance;
    if (identical(dispatcher.onError, _platformHandler)) {
      dispatcher.onError = _previousPlatform;
    }
  }
}
