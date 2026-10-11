# codekit_webhook

Optional Discord and Telegram sinks for `codekit_core`. Each sink uses one
private `package:http` client by default and closes it when diagnostics are
disposed. You can inject a client-neutral `WebhookTransport`; injected
transports remain caller-owned and prevent creation of an internal client.

```dart
final diagnostics = CodeKitDiagnostics(
  sinks: [
    DiscordSink(
      webhookUrl: Uri.parse('https://discord.com/api/webhooks/...'),
      httpDispatchPolicy: HttpDispatchPolicy(
        statusGroups: {HttpStatusGroup.serverError},
      ),
      logDispatchPolicy: LogDispatchPolicy(includeTags: {'appCrash'}),
    ),
    TelegramSink(
      botToken: 'your-bot-token',
      chatId: 'your-chat-id',
      logDispatchPolicy: LogDispatchPolicy(levels: {LogLevel.fatal}),
    ),
  ],
);

diagnostics.log(LogInput(message: 'Service ready'));
await diagnostics.dispose();
```

Delivery is fire-and-forget, single-flight per sink, and never retried. A
five-failure circuit breaker with a one-minute cooldown is configured per
sink by default. `transport`, content/service options, breaker settings, and
the safe warning callback are optional constructor parameters. Keep webhook
credentials outside source control.

Run checks from the workspace root with the pinned SDK:

```sh
.fvm/flutter_sdk/bin/dart analyze packages/codekit_webhook
.fvm/flutter_sdk/bin/dart test packages/codekit_webhook/test
```
