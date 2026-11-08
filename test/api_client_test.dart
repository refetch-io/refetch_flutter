import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:refetch/core/auth/jwt_service.dart';
import 'package:refetch/core/network/api_client.dart';
import 'package:refetch/core/network/api_exception.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _MockAccount extends Mock implements Account {}

void main() {
  setUpAll(() => registerFallbackValue(Uri()));

  late _MockHttpClient httpClient;
  late _MockAccount account;
  late ApiClient api;
  late JwtService jwt;

  setUp(() {
    httpClient = _MockHttpClient();
    account = _MockAccount();
    jwt = JwtService(account);
    api = ApiClient(
      baseUrl: 'https://example.test',
      jwtService: jwt,
      httpClient: httpClient,
    );
    when(
      () => account.createJWT(),
    ).thenAnswer((_) async => models.Jwt(jwt: 't'));
  });

  test('clears the JWT and retries once on 401, then succeeds', () async {
    var calls = 0;
    when(
      () => httpClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
        encoding: any(named: 'encoding'),
      ),
    ).thenAnswer((_) async {
      calls++;
      return calls == 1
          ? http.Response('{"error":"expired"}', 401)
          : http.Response('{"ok":true}', 200);
    });

    final result = await api.post('/api/vote', body: {'x': 1});

    expect(result, {'ok': true});
    expect(calls, 2);
    // Initial mint + a re-mint after the 401 clear.
    verify(() => account.createJWT()).called(2);
  });

  test(
    'throws ApiException with the server message on non-401 errors',
    () async {
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
          encoding: any(named: 'encoding'),
        ),
      ).thenAnswer((_) async => http.Response('{"message":"nope"}', 400));

      await expectLater(
        api.post('/api/vote', body: const {}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', 'nope'),
        ),
      );
    },
  );

  test('unauthenticated request without a session fails fast', () async {
    when(() => account.createJWT()).thenThrow(AppwriteException('no session'));

    await expectLater(
      api.post('/api/vote', body: const {}),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 401)),
    );
    verifyNever(
      () => httpClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
        encoding: any(named: 'encoding'),
      ),
    );
  });

  test('unwraps the app API data envelope', () async {
    when(
      () => httpClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
        encoding: any(named: 'encoding'),
      ),
    ).thenAnswer(
      (_) async => http.Response('{"data":{"vote":"up","count":4}}', 200),
    );

    expect(await api.post('/api/app/vote'), {'vote': 'up', 'count': 4});
  });

  test('reads the app API error field', () async {
    when(
      () => httpClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
        encoding: any(named: 'encoding'),
      ),
    ).thenAnswer(
      (_) async => http.Response(
        '{"error":"This story has already been shared.","code":"duplicate"}',
        409,
      ),
    );

    await expectLater(
      api.post('/api/app/submit'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having(
              (e) => e.message,
              'message',
              'This story has already been shared.',
            ),
      ),
    );
  });

  // Appwrite Cloud's edge executor overwrites Authorization before the request
  // reaches refetch.io, so the JWT must travel in X-Refetch-JWT.
  test('sends the JWT in X-Refetch-JWT, not Authorization', () async {
    Map<String, String>? sent;
    when(
      () => httpClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
        encoding: any(named: 'encoding'),
      ),
    ).thenAnswer((invocation) async {
      sent = invocation.namedArguments[#headers] as Map<String, String>;
      return http.Response('{"data":{}}', 200);
    });

    await api.post('/api/app/session');

    expect(sent?['x-refetch-jwt'], 't');
    expect(sent?.containsKey('authorization'), isFalse);
  });
}
