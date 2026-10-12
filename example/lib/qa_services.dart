import 'package:codekit/codekit.dart' as kit;
import 'package:codekit_console/codekit_console.dart';
import 'package:codekit_dio/codekit_dio.dart';
import 'package:codekit_drift_diagnostic_store/codekit_drift_diagnostic_store.dart';
import 'package:codekit_flutter/codekit_flutter.dart';
import 'package:codekit_http/codekit_http.dart';
import 'package:codekit_webhook/codekit_webhook.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Shared native resources used by the QA actions and the UI.
final class QaServices {
  QaServices._({
    required this.diagnostics,
    required this.dio,
    required this.httpClient,
    required this.errorHooks,
    required this.storageDescription,
  });

  final kit.CodeKitDiagnostics diagnostics;
  final Dio dio;
  final http.Client httpClient;
  final CodeKitFlutterErrorHooks? errorHooks;
  final String storageDescription;
  bool _closed = false;

  static final kit.RedactionPolicy _redactionPolicy = kit.RedactionPolicy(
    rules: [
      kit.HeaderRedactionRule(const ['x-qa-secret']),
      kit.BodyFieldRedactionRule(const ['password', 'token', 'secret']),
    ],
  );

  static Future<QaServices> create() async {
    final directory = await getApplicationDocumentsDirectory();
    final sinks = <kit.DiagnosticSink>[
      ColoredConsoleSink(writer: (text) => debugPrint(text)),
    ];
    _addConfiguredWebhooks(sinks);

    final databasePath = path.join(directory.path, 'codekit_qa.sqlite');
    final diagnostics = await createDriftDiagnostics(
      databasePath: databasePath,
      retention: kit.RetentionPolicy(maxRecords: 1000),
      redactionPolicy: _redactionPolicy,
      sinks: sinks,
      onWarning: (warning) =>
          debugPrint('[CodeKit warning] ${warning.code}: ${warning.message}'),
      onStoreWarning: (message, error, stackTrace) =>
          debugPrint('[CodeKit store warning] $message $error\n$stackTrace'),
    );
    final hooks = CodeKitFlutterErrorHooks.install(diagnostics);
    return QaServices._(
      diagnostics: diagnostics,
      dio: Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      ).withDiagnostics(diagnostics),
      httpClient: http.Client().withDiagnostics(diagnostics),
      errorHooks: hooks,
      storageDescription: 'Drift (persistent)',
    );
  }

  /// Uses memory storage so the widget smoke test does not touch a device file.
  factory QaServices.forTest() {
    final diagnostics = kit.CodeKitDiagnostics(
      redactionPolicy: _redactionPolicy,
    );
    return QaServices._(
      diagnostics: diagnostics,
      dio: Dio().withDiagnostics(diagnostics),
      httpClient: http.Client().withDiagnostics(diagnostics),
      errorHooks: null,
      storageDescription: 'Memory (test)',
    );
  }

  static void _addConfiguredWebhooks(List<kit.DiagnosticSink> sinks) {
    if (!const bool.fromEnvironment('CODEKIT_QA_ENABLE_WEBHOOKS')) return;

    final discordUrl = const String.fromEnvironment(
      'CODEKIT_QA_DISCORD_WEBHOOK_URL',
    );
    if (discordUrl.isNotEmpty) {
      sinks.add(
        DiscordSink(
          webhookUrl: Uri.parse(discordUrl),
          onWarning: (warning) => debugPrint(
            '[Discord warning] ${warning.code}: ${warning.message}',
          ),
        ),
      );
    }

    final telegramToken = const String.fromEnvironment(
      'CODEKIT_QA_TELEGRAM_BOT_TOKEN',
    );
    final telegramChatId = const String.fromEnvironment(
      'CODEKIT_QA_TELEGRAM_CHAT_ID',
    );
    if (telegramToken.isNotEmpty && telegramChatId.isNotEmpty) {
      sinks.add(
        TelegramSink(
          botToken: telegramToken,
          chatId: telegramChatId,
          onWarning: (warning) => debugPrint(
            '[Telegram warning] ${warning.code}: ${warning.message}',
          ),
        ),
      );
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    errorHooks?.dispose();
    dio.close(force: true);
    httpClient.close();
    await diagnostics.dispose();
  }
}
