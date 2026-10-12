# codekit_webhook

Optional Discord and Telegram sinks for `codekit_core`. Configure either or
both independently. Each sink uses a private `package:http` client by default
and closes it when diagnostics are disposed. You can inject a client-neutral
`WebhookTransport`; injected transports remain caller-owned and prevent
creation of an internal client.

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
five-failure circuit breaker with a one-minute cooldown is configured per sink
by default. Dispatch policies select which LOG/HTTP records are sent; narrow
them by status group, tag, or severity when sending every record is not
appropriate. `transport`, content/service options, breaker settings, and the
safe warning callback are optional constructor parameters.

Treat webhook URLs and bot tokens as secrets. Do not commit credentials or ship
server-side credentials inside a public client application. Consider the data
destination before enabling external delivery. Sinks receive the prepared
dispatch representation; store and export mode are separate concerns. For
delivery and policy details, see the
[diagnostic sinks specification](../../doc/specs/diagnostic-sinks.md).

This workspace package is not currently published. See the
[implementation guide](../../doc/guides/codekit-implementation-guide.md) for
package availability and composition guidance.

Run checks from the workspace root with the pinned SDK:

```sh
.fvm/flutter_sdk/bin/dart analyze packages/codekit_webhook
.fvm/flutter_sdk/bin/dart test packages/codekit_webhook/test
```
