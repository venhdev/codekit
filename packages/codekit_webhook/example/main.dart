import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_webhook/codekit_webhook.dart';

Future<void> main() async {
  final diagnostics = CodeKitDiagnostics(
    sinks: [
      DiscordSink(
        webhookUrl: Uri.parse('https://discord.example.invalid/webhook'),
        httpDispatchPolicy: HttpDispatchPolicy(
          statusGroups: {HttpStatusGroup.serverError},
        ),
      ),
      TelegramSink(
        botToken: 'configure-at-runtime',
        chatId: 'configure-at-runtime',
        logDispatchPolicy: LogDispatchPolicy(levels: {LogLevel.fatal}),
      ),
    ],
  );

  // No matching records are submitted here, so running this example makes no
  // network requests. Supply real credentials through your app configuration.
  await diagnostics.dispose();
}
