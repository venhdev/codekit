import 'dart:convert';

import 'package:codekit/codekit.dart' as kit;
import 'package:colored_logger/colored_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_catalog.dart';
import 'qa_services.dart';

/// User-triggerable scenarios for device QA.
final class QaActions {
  QaActions(this.services);

  final QaServices services;

  Future<void> seedLogMatrix() {
    for (final level in kit.LogLevel.values) {
      services.diagnostics.log(
        kit.LogInput(
          message: 'QA ${level.name} log',
          level: level,
          source: 'qa.log-matrix',
          tags: {'qa', 'level:${level.name}'},
          context: {'scenario': 'log-matrix', 'level': level.name},
        ),
      );
    }
    ColoredLogger.info('CodeKit QA log matrix generated');
    return Future.value();
  }

  Future<void> seedSensitiveRecords() => runHttpJsonPost(
    'sensitive-echo',
    ApiCatalog.httpbin('/anything'),
    body: const {
      'email': 'qa@example.test',
      'password': 'qa-password',
      'token': 'qa-token',
    },
    headers: const {
      'authorization': 'Bearer qa-token',
      'x-qa-secret': 'qa-secret',
    },
  );

  Future<void> generatePaginationDataset({int count = 120}) async {
    for (var index = 0; index < count; index++) {
      services.diagnostics.log(
        kit.LogInput(
          message: 'QA pagination record $index',
          source: 'qa.pagination',
          tags: {'qa', 'pagination'},
          context: {'index': index},
        ),
      );
    }
  }

  Future<void> runDioHealth() =>
      _runDio('dio-httpbin-json', ApiCatalog.httpbin('/json'));

  Future<void> runDioWeather() => _runDio('dio-weather', ApiCatalog.weather());

  Future<void> runDioProductDetail() =>
      _runDio('dio-product-detail', ApiCatalog.product(1));

  Future<void> runDioStatus(int status) =>
      _runDio('dio-status-$status', ApiCatalog.httpbin('/status/$status'));

  Future<void> runDioRedirect() =>
      _runDio('dio-redirect', ApiCatalog.httpbin('/redirect/2'));

  Future<void> runDioDelay() =>
      _runDio('dio-delay', ApiCatalog.httpbin('/delay/2'));

  Future<void> runDioResponseHeaders() => _runDio(
    'dio-response-headers',
    ApiCatalog.httpbin('/response-headers', {'X-QA-Response': 'true'}),
  );

  Future<void> runDioAbort() =>
      _runDio('dio-status-599', ApiCatalog.httpbin('/status/599'));

  Future<void> runHttpCurrencyRates() => _runHttp(
    'http-currency-rates',
    () => services.httpClient.get(ApiCatalog.currencyRates()),
  );

  Future<void> runHttpCurrencyRate() => _runHttp(
    'http-currency-rate',
    () => services.httpClient.get(ApiCatalog.currencyRate()),
  );

  Future<void> runHttpProducts() => _runHttp(
    'http-products',
    () => services.httpClient.get(ApiCatalog.products()),
  );

  Future<void> runHttpProductSearch() => _runHttp(
    'http-product-search',
    () => services.httpClient.get(ApiCatalog.productSearch('phone')),
  );

  Future<void> runHttpProductCrud() async {
    await runHttpJsonPost(
      'http-product-create',
      ApiCatalog.productAdd(),
      body: const {'title': 'CodeKit QA product', 'price': 42.50},
    );
    await _runHttp(
      'http-product-update',
      () => services.httpClient.patch(
        ApiCatalog.product(1),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode(const {'title': 'Updated CodeKit QA product'}),
      ),
    );
    await _runHttp(
      'http-product-delete',
      () => services.httpClient.delete(ApiCatalog.product(1)),
    );
  }

  Future<void> runHttpPosts() =>
      _runHttp('http-posts', () => services.httpClient.get(ApiCatalog.posts()));

  Future<void> runHttpPostCrud() async {
    await runHttpJsonPost(
      'http-post-create',
      ApiCatalog.posts(),
      body: const {
        'title': 'CodeKit QA post',
        'body': 'Created by the CodeKit integration app.',
        'userId': 1,
      },
    );
    await _runHttp(
      'http-post-patch',
      () => services.httpClient.patch(
        ApiCatalog.post(1),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode(const {'title': 'Updated CodeKit QA post'}),
      ),
    );
    await _runHttp(
      'http-post-delete',
      () => services.httpClient.delete(ApiCatalog.post(1)),
    );
  }

  Future<void> runHttpJsonPost(
    String name,
    Uri uri, {
    required Map<String, Object?> body,
    Map<String, String> headers = const {},
  }) => _runHttp(
    name,
    () => services.httpClient.post(
      uri,
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode(body),
    ),
  );

  Future<void> runAllSafeApiScenarios() async {
    await seedLogMatrix();
    await runDioHealth();
    await runDioWeather();
    await runDioProductDetail();
    await runDioStatus(404);
    await runDioStatus(500);
    await runDioRedirect();
    await runDioDelay();
    await runDioResponseHeaders();
    await runHttpCurrencyRates();
    await runHttpCurrencyRate();
    await runHttpProducts();
    await runHttpProductSearch();
    await runHttpPosts();
    await seedSensitiveRecords();
  }

  Future<void> triggerFlutterError() {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError('CodeKit QA Flutter error'),
        stack: StackTrace.current,
        library: 'CodeKit QA',
        context: ErrorDescription('manual Flutter hook scenario'),
      ),
    );
    return Future.value();
  }

  Future<void> triggerPlatformError() {
    PlatformDispatcher.instance.onError?.call(
      StateError('CodeKit QA platform error'),
      StackTrace.current,
    );
    return Future.value();
  }

  Future<void> startTrace() {
    services.diagnostics.startTrace();
    _log('trace-started', 'Manual QA trace started');
    return Future.value();
  }

  Future<void> stopTrace() async {
    final session = await services.diagnostics.stopTrace(name: 'QA manual');
    _log(
      'trace-stopped',
      session == null
          ? 'Manual QA trace had no records'
          : 'Manual QA trace saved ${session.recordIds.length} records',
    );
  }

  Future<void> clearRecords() => services.diagnostics.clearRecords();

  Future<void> _runDio(String name, Uri uri) async {
    try {
      final response = await services.dio.getUri<Object?>(uri);
      _log(name, 'Dio completed with HTTP ${response.statusCode}');
    } catch (error, stackTrace) {
      _log(
        name,
        'Dio failed: $error',
        level: kit.LogLevel.warning,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _runHttp(
    String name,
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request();
      final level = response.statusCode >= 400
          ? kit.LogLevel.warning
          : kit.LogLevel.info;
      _log(
        name,
        'package:http completed with HTTP ${response.statusCode}',
        level: level,
      );
    } catch (error, stackTrace) {
      _log(
        name,
        'package:http failed: $error',
        level: kit.LogLevel.warning,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _log(
    String scenario,
    String message, {
    kit.LogLevel level = kit.LogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    services.diagnostics.log(
      kit.LogInput(
        message: message,
        level: level,
        source: 'qa.action',
        tags: {'qa', 'scenario:$scenario'},
        error: error,
        stackTrace: stackTrace,
        context: {'scenario': scenario},
      ),
    );
  }
}
