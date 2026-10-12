/// Public HTTPS endpoints used by the native QA application.
final class ApiCatalog {
  static Uri httpbin(String path, [Map<String, String>? query]) =>
      Uri.https('httpbin.org', path, query);

  static Uri weather() => Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': '10.8231',
    'longitude': '106.6297',
    'current': 'temperature_2m,relative_humidity_2m,wind_speed_10m',
    'hourly': 'temperature_2m,precipitation_probability',
    'forecast_days': '2',
  });

  static Uri currencyRates() => Uri.https('api.frankfurter.dev', '/v2/rates', {
    'base': 'USD',
    'quotes': 'EUR,JPY,VND',
  });

  static Uri currencyRate() =>
      Uri.https('api.frankfurter.dev', '/v2/rate/usd/eur');

  static Uri products({int limit = 10, int skip = 0}) =>
      Uri.https('dummyjson.com', '/products', {
        'limit': '$limit',
        'skip': '$skip',
        'select': 'title,price,rating,stock,category,reviews',
      });

  static Uri productSearch(String query) =>
      Uri.https('dummyjson.com', '/products/search', {'q': query});

  static Uri product(int id) => Uri.https('dummyjson.com', '/products/$id');

  static Uri productAdd() => Uri.https('dummyjson.com', '/products/add');

  static Uri posts({int userId = 1}) => Uri.https(
    'jsonplaceholder.typicode.com',
    '/posts',
    {'userId': '$userId'},
  );

  static Uri post(int id) =>
      Uri.https('jsonplaceholder.typicode.com', '/posts/$id');
}
