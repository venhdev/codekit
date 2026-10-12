# CodeKit integration QA app

This native Flutter application exercises the CodeKit workspace packages on
Android and iOS. It uses public HTTPS APIs instead of a local mock server.

The QA controls cover:

- CodeKit UI records, search, filters, Trace sessions and export/share.
- Dio and `package:http` capture with success, errors, redirects and delays.
- Open-Meteo weather, Frankfurter currency rates, DummyJSON products and
  JSONPlaceholder posts.
- Native Drift persistence and Flutter error hooks.
- Optional Discord and Telegram sinks when credentials are supplied through
  `--dart-define`.

Run dependency resolution and static checks from the workspace root:

```sh
fvm dart pub get
fvm flutter analyze example
fvm flutter test example/test
```

Run the application or build an APK from this directory when performing device
QA:

```sh
cd example
fvm flutter run
fvm flutter build apk --debug
```

Optional webhook configuration must not be committed:

```sh
fvm flutter run \
  --dart-define=CODEKIT_QA_ENABLE_WEBHOOKS=true \
  --dart-define=CODEKIT_QA_DISCORD_WEBHOOK_URL=https://example.invalid/webhook \
  --dart-define=CODEKIT_QA_TELEGRAM_BOT_TOKEN=token \
  --dart-define=CODEKIT_QA_TELEGRAM_CHAT_ID=chat-id
```

Public API data is dynamic and internet-dependent. Assert request capture,
status, shape and UI behavior rather than fixed weather, currency or price
values. `httpbin` is used for controlled status, redirect, delay and header
scenarios.
