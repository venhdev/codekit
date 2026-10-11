/// Client-neutral request passed to a webhook transport.
final class WebhookRequest {
  final Uri uri;
  final String method;
  final Map<String, List<String>> headers;
  final List<int> body;

  WebhookRequest({
    required this.uri,
    required this.method,
    Map<String, List<String>> headers = const {},
    List<int> body = const [],
  }) : headers = Map.unmodifiable(
         headers.map(
           (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
         ),
       ),
       body = List.unmodifiable(body);
}

/// Client-neutral response returned by a webhook transport.
final class WebhookResponse {
  final int statusCode;
  final Map<String, List<String>> headers;
  final List<int> body;

  WebhookResponse({
    required this.statusCode,
    Map<String, List<String>> headers = const {},
    List<int> body = const [],
  }) : headers = Map.unmodifiable(
         headers.map(
           (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
         ),
       ),
       body = List.unmodifiable(body);
}

/// Sends one outbound request and returns its response without retrying.
abstract interface class WebhookTransport {
  Future<WebhookResponse> send(WebhookRequest request);
}
