import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_webhook/codekit_webhook.dart';
import 'package:test/test.dart';

void main() {
  group('DiscordSink', () {
    test(
      'formats a request and leaves the injected transport caller-owned',
      () async {
        final transport = _FakeTransport();
        final sink = DiscordSink(
          webhookUrl: Uri.parse('https://discord.test/hooks/secret?x=1'),
          transport: transport,
          options: const DiscordSinkOptions(username: 'CodeKit'),
        );

        sink.dispatch(_logRecord('failure'));
        final request = await transport.request.future;
        final payload = jsonDecode(utf8.decode(request.body)) as Map;
        expect(request.method, 'POST');
        expect(request.uri.queryParameters, {'x': '1', 'wait': 'true'});
        expect(payload['username'], 'CodeKit');
        expect(payload['allowed_mentions']['parse'], isEmpty);
        expect(
          (payload['embeds'] as List).single['description'],
          contains('failure'),
        );

        sink.dispose();
        expect(transport.closed, isFalse);
      },
    );

    test('drops arrivals while a send is in flight', () async {
      final transport = _FakeTransport(holdResponse: true);
      final sink = DiscordSink(
        webhookUrl: Uri.parse('https://discord.test/hooks/secret'),
        transport: transport,
      );

      sink.dispatch(_logRecord('first'));
      await transport.request.future;
      sink.dispatch(_logRecord('second'));
      expect(transport.sendCount, 1);
      transport.response.complete(_okResponse);
      await Future<void>.delayed(Duration.zero);
      sink.dispose();
    });

    test(
      'opens the circuit after the configured consecutive failures',
      () async {
        final transport = _FakeTransport(
          response: WebhookResponse(statusCode: 500),
        );
        final warnings = <WebhookWarning>[];
        final sink = DiscordSink(
          webhookUrl: Uri.parse('https://discord.test/hooks/secret'),
          transport: transport,
          circuitBreaker: const SinkCircuitBreakerOptions(failureThreshold: 1),
          onWarning: warnings.add,
        );

        sink.dispatch(_logRecord('first'));
        await transport.request.future;
        await Future<void>.delayed(Duration.zero);
        sink.dispatch(_logRecord('second'));

        expect(transport.sendCount, 1);
        expect(warnings.map((warning) => warning.code), ['circuitOpened']);
        expect(warnings.single.message, isNot(contains('secret')));
        sink.dispose();
      },
    );

    test(
      'honors a valid server retry-after without exposing the webhook URL',
      () async {
        final transport = _FakeTransport(
          response: WebhookResponse(
            statusCode: 429,
            headers: const {
              'retry-after': ['30'],
            },
          ),
        );
        final warnings = <WebhookWarning>[];
        final sink = DiscordSink(
          webhookUrl: Uri.parse('https://discord.test/hooks/secret'),
          transport: transport,
          onWarning: warnings.add,
        );

        sink.dispatch(_logRecord('limited'));
        await transport.request.future;
        await Future<void>.delayed(Duration.zero);

        expect(warnings.map((warning) => warning.code), ['rateLimited']);
        expect(warnings.single.message, isNot(contains('secret')));
        sink.dispose();
      },
    );

    test('includes generated curl when selected in content options', () async {
      final transport = _FakeTransport();
      final sink = DiscordSink(
        webhookUrl: Uri.parse('https://discord.test/hooks/secret'),
        transport: transport,
        contentOptions: const DiagnosticContentOptions(curl: true),
        httpDispatchPolicy: HttpDispatchPolicy(
          statusGroups: {HttpStatusGroup.serverError},
        ),
      );

      sink.dispatch(_httpRecord());
      final request = await transport.request.future;
      final payload = jsonDecode(utf8.decode(request.body)) as Map;
      expect(
        (payload['embeds'] as List).single['description'],
        contains("curl -X 'GET' 'https://api.example.test/failure'"),
      );
      sink.dispose();
    });

    test('default package:http transport sends to a loopback server', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final received = Completer<HttpRequest>();
      server.listen((request) async {
        received.complete(request);
        request.response
          ..statusCode = HttpStatus.noContent
          ..close();
      });
      final sink = DiscordSink(
        webhookUrl: Uri.parse(
          'http://${server.address.address}:${server.port}/webhook',
        ),
        httpDispatchPolicy: HttpDispatchPolicy(
          statusGroups: {HttpStatusGroup.unknown},
        ),
      );

      sink.dispatch(_httpRecord());
      final request = await received.future.timeout(const Duration(seconds: 5));
      expect(request.method, 'POST');
      expect(request.uri.queryParameters['wait'], 'true');
      sink.dispose();
      await server.close(force: true);
    });
  });

  group('TelegramSink', () {
    test('escapes content and maps Telegram options', () async {
      final transport = _FakeTransport();
      final sink = TelegramSink(
        botToken: 'token-secret',
        chatId: 'room-1',
        transport: transport,
        options: const TelegramSinkOptions(
          messageThreadId: 7,
          disableNotification: true,
          protectContent: true,
          disableLinkPreview: true,
        ),
      );

      sink.dispatch(_logRecord('<unsafe>'));
      final request = await transport.request.future;
      final payload = jsonDecode(utf8.decode(request.body)) as Map;
      expect(request.uri.path, '/bottoken-secret/sendMessage');
      expect(payload['chat_id'], 'room-1');
      expect(payload['message_thread_id'], 7);
      expect(payload['disable_notification'], isTrue);
      expect(payload['protect_content'], isTrue);
      expect(payload['link_preview_options']['is_disabled'], isTrue);
      expect(payload['text'], contains('&lt;unsafe&gt;'));
      sink.dispose();
    });

    test('limits long content without splitting Unicode characters', () async {
      final transport = _FakeTransport();
      final sink = TelegramSink(
        botToken: 'token',
        chatId: 'room',
        transport: transport,
      );
      sink.dispatch(_logRecord('🙂' * 5000));
      final request = await transport.request.future;
      final payload = jsonDecode(utf8.decode(request.body)) as Map;
      expect((payload['text'] as String).runes.length, lessThanOrEqualTo(4096));
      expect(payload['text'], contains('(truncated)'));
      sink.dispose();
    });
  });
}

final class _FakeTransport implements WebhookTransport {
  final request = Completer<WebhookRequest>();
  final response = Completer<WebhookResponse>();
  final bool holdResponse;
  int sendCount = 0;
  bool closed = false;

  _FakeTransport({this.holdResponse = false, WebhookResponse? response}) {
    if (response != null) {
      this.response.complete(response);
    } else if (!holdResponse) {
      this.response.complete(_okResponse);
    }
  }

  @override
  Future<WebhookResponse> send(WebhookRequest value) {
    sendCount++;
    if (!request.isCompleted) request.complete(value);
    return response.future;
  }
}

final WebhookResponse _okResponse = WebhookResponse(
  statusCode: 204,
  body: const [],
);

DiagnosticRecord _logRecord(String message) => DiagnosticRecord(
  id: 'log-1',
  recordedAt: DateTime.utc(2026),
  recordMode: RecordMode.storeRaw,
  payload: LogPayload(message: message),
);

DiagnosticRecord _httpRecord() => DiagnosticRecord(
  id: 'http-1',
  recordedAt: DateTime.utc(2026),
  recordMode: RecordMode.storeRaw,
  payload: HttpPayload(
    requestStartedAt: DateTime.utc(2026),
    method: 'GET',
    uri: Uri.https('api.example.test', '/failure'),
    response: const HttpResponseSnapshot(statusCode: 500),
  ),
);
