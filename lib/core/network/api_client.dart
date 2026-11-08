import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../auth/jwt_service.dart';
import '../config/app_config.dart';
import 'api_exception.dart';

/// Thin wrapper around [http.Client] for the refetch.io app API (`/api/app/*`,
/// see the web repo's `docs/APP_API.md`).
///
/// Handles JSON encoding/decoding, unwrapping the `{ "data": … }` envelope,
/// error mapping to [ApiException], and sending the cached Appwrite JWT in the
/// `X-Refetch-JWT` header on authenticated calls.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.jwtService,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final JwtService jwtService;
  final http.Client _http;

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return _send(
      auth,
      () async => _http.get(uri, headers: await _headers(auth)),
    );
  }

  Future<dynamic> post(String path, {Object? body, bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$path');
    return _send(
      auth,
      () async => _http.post(
        uri,
        headers: await _headers(auth),
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ),
    );
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$path');
    return _send(
      auth,
      () async => _http.delete(uri, headers: await _headers(auth)),
    );
  }

  Future<dynamic> _send(
    bool auth,
    Future<http.Response> Function() request,
  ) async {
    var response = await _run(request);

    // A cached JWT can be locally-valid but rejected server-side (revoked,
    // clock skew). Clear it and retry once with a freshly minted token.
    if (auth && response.statusCode == 401) {
      jwtService.clear();
      response = await _run(request);
    }
    return _handle(response);
  }

  Future<http.Response> _run(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(0, 'Network error: $error');
    }
  }

  Future<Map<String, String>> _headers(bool auth) async {
    final headers = <String, String>{'content-type': 'application/json'};
    if (auth) {
      final token = await jwtService.getToken();
      if (token == null) {
        throw const ApiException(401, 'You need to sign in to do that.');
      }
      // Not `Authorization`: Appwrite Cloud's edge executor overwrites that
      // header before the request reaches refetch.io (docs/APP_API.md).
      headers['x-refetch-jwt'] = token;
    }
    return headers;
  }

  dynamic _handle(http.Response response) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body;
      }
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (ok) {
      return decoded is Map && decoded.containsKey('data')
          ? decoded['data']
          : decoded;
    }

    final message = decoded is Map
        ? (decoded['message'] ?? decoded['error'] ?? 'Request failed')
        : 'Request failed';
    throw ApiException(response.statusCode, message.toString());
  }

  void close() => _http.close();
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    jwtService: ref.watch(jwtServiceProvider),
  );
  ref.onDispose(client.close);
  return client;
});
