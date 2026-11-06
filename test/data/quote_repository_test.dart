import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_sessions/data/quote_repository.dart';
import 'package:focus_sessions/models/quote.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// A real /api/today response, captured on 2026-11-06.
const _liveBody =
    r'''[{"q":"Your mind is infinite, it's your doubts that are limiting.","a":"Robert Kiyosaki","i":"https:\/\/zenquotes.io\/img\/robert-kiyosaki.jpg","h":"<blockquote>&ldquo;Your mind is infinite, it&#039;s your doubts that are limiting.&rdquo; &mdash; <footer>Robert Kiyosaki<\/footer><\/blockquote>","date":"2026-11-06"}]''';

const _liveQuote = Quote(
  text: "Your mind is infinite, it's your doubts that are limiting.",
  author: 'Robert Kiyosaki',
);

class _FailingStore extends InMemorySharedPreferencesStore {
  _FailingStore() : super.empty();

  Future<bool> Function()? failure;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    return failure?.call() ?? super.setValue(valueType, key, value);
  }
}

void main() {
  final okClient = MockClient((_) async => http.Response(_liveBody, 200));

  http.Client respondingWith(String body, [int status = 200]) =>
      MockClient((_) async => http.Response(body, status));

  // Duration.zero makes the timeout case fire without a real delay.
  QuoteRepository repositoryFor(http.Client client, SharedPreferences prefs) =>
      QuoteRepository(client, prefs, timeout: Duration.zero);

  // Every case except the timeout one uses a long timeout, so only it can expire.
  QuoteRepository patientRepository(
    http.Client client,
    SharedPreferences prefs,
  ) =>
      QuoteRepository(client, prefs, timeout: const Duration(minutes: 1));

  Future<SharedPreferences> prefsWith([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('success', () {
    test('requests /api/today and reads q and a from a real response',
        () async {
      late http.Request request;
      final client = MockClient((r) async {
        request = r;
        return http.Response(_liveBody, 200);
      });

      final result =
          await patientRepository(client, await prefsWith()).fetchDailyQuote();

      expect(request.method, 'GET');
      expect(request.url, Uri.parse('https://zenquotes.io/api/today'));
      expect(
        result,
        const QuoteResult(quote: _liveQuote, source: QuoteSource.fresh),
      );
    });

    test('decodes UTF-8 when the response has no charset', () async {
      final body = utf8.encode(jsonEncode([
        {'q': 'Déjà vu — again', 'a': 'Café'},
      ]));
      final client = MockClient((_) async => http.Response.bytes(body, 200));

      final result =
          await patientRepository(client, await prefsWith()).fetchDailyQuote();

      expect(
          result.quote, const Quote(text: 'Déjà vu — again', author: 'Café'));
    });

    test('a newer quote replaces the cached one', () async {
      final prefs = await prefsWith();
      await patientRepository(okClient, prefs).fetchDailyQuote();
      await patientRepository(
        respondingWith(jsonEncode([
          {'q': 'Newer', 'a': 'Someone'},
        ])),
        prefs,
      ).fetchDailyQuote();

      final result = await patientRepository(
        respondingWith('', 500),
        prefs,
      ).fetchDailyQuote();

      expect(result.quote, const Quote(text: 'Newer', author: 'Someone'));
    });

    for (final (name, failure) in <(String, Future<bool> Function())>[
      ('returns false', () async => false),
      ('throws', () async => throw Exception('Disk full')),
    ]) {
      test('still returns the quote if saving it $name', () async {
        SharedPreferences.setMockInitialValues({});
        final store = _FailingStore()..failure = failure;
        SharedPreferencesStorePlatform.instance = store;

        final result = await patientRepository(
          okClient,
          await SharedPreferences.getInstance(),
        ).fetchDailyQuote();

        expect(
          result,
          const QuoteResult(quote: _liveQuote, source: QuoteSource.fresh),
        );
      });
    }
  });

  group('failures', () {
    // Each failure builds its repository so the timeout case can use a zero
    // timeout with a response that never arrives.
    final failures =
        <String, QuoteRepository Function(SharedPreferences prefs)>{
      'a server error': (prefs) =>
          patientRepository(respondingWith(_liveBody, 500), prefs),
      'a rate-limit status': (prefs) =>
          patientRepository(respondingWith(_liveBody, 429), prefs),
      'a timeout': (prefs) => repositoryFor(
            MockClient((_) => Completer<http.Response>().future),
            prefs,
          ),
      'a network error': (prefs) => patientRepository(
            MockClient((_) async => throw http.ClientException('No network')),
            prefs,
          ),
      'invalid JSON': (prefs) =>
          patientRepository(respondingWith('<html>Oops</html>'), prefs),
      'invalid UTF-8': (prefs) => patientRepository(
            MockClient(
              (_) async => http.Response.bytes([0xC3, 0x28], 200),
            ),
            prefs,
          ),
      'an empty list': (prefs) =>
          patientRepository(respondingWith('[]'), prefs),
      'an object instead of a list': (prefs) =>
          patientRepository(respondingWith('{"q":"x","a":"y"}'), prefs),
      'a list without an object': (prefs) =>
          patientRepository(respondingWith('[1]'), prefs),
      'a missing q': (prefs) =>
          patientRepository(respondingWith('[{"a":"y"}]'), prefs),
      'a missing a': (prefs) =>
          patientRepository(respondingWith('[{"q":"x"}]'), prefs),
      'a non-string q': (prefs) =>
          patientRepository(respondingWith('[{"q":1,"a":"y"}]'), prefs),
      'a blank q': (prefs) =>
          patientRepository(respondingWith('[{"q":" ","a":"y"}]'), prefs),
    };

    failures.forEach((name, repositoryWith) {
      test('$name with no cache uses the built-in quote', () async {
        final result =
            await repositoryWith(await prefsWith()).fetchDailyQuote();

        expect(
          result,
          const QuoteResult(
            quote: QuoteRepository.fallbackQuote,
            source: QuoteSource.fallback,
          ),
        );
      });

      test('$name with a cache uses and keeps the cached quote', () async {
        final prefs = await prefsWith();
        await patientRepository(okClient, prefs).fetchDailyQuote();
        const cached =
            QuoteResult(quote: _liveQuote, source: QuoteSource.cached);

        expect(await repositoryWith(prefs).fetchDailyQuote(), cached);
        // A second failure proves the first did not overwrite the cache.
        expect(await repositoryWith(prefs).fetchDailyQuote(), cached);
      });
    });
  });

  group('corrupted cache', () {
    for (final stored in ['not json', '[]', '{"q":"only text"}']) {
      test('"$stored" falls back to the built-in quote', () async {
        final prefs = await prefsWith({'last_quote': stored});

        final result = await patientRepository(
          respondingWith('', 500),
          prefs,
        ).fetchDailyQuote();

        expect(result.source, QuoteSource.fallback);
        expect(result.quote, QuoteRepository.fallbackQuote);
      });
    }
  });
}
