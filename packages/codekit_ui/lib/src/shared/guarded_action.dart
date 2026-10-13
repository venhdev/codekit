import 'dart:developer' as developer;

/// Executes an asynchronous [action] safely.
///
/// If an error occurs, it is logged via [developer.log] under `codekit.ui`
/// and forwarded to [onError].
Future<void> guardAction(
  Future<void> Function() action, {
  required void Function(Object error, StackTrace stackTrace) onError,
}) async {
  try {
    await action();
  } catch (error, stackTrace) {
    developer.log(
      'Error during action: $error',
      name: 'codekit.ui',
      error: error,
      stackTrace: stackTrace,
      level: 900,
    );
    onError(error, stackTrace);
  }
}
