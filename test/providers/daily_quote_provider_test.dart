import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_sessions/models/quote.dart';
import 'package:focus_sessions/providers/core_providers.dart';
import 'package:focus_sessions/providers/daily_quote_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('fetches through the repository, once, and keeps the result', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('[{"q":"Text","a":"Author"}]', 200);
    });
    final container = ProviderContainer(
      overrides: [
        httpClientProvider.overrideWithValue(client),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final first = await container.read(dailyQuoteProvider.future);
    final second = await container.read(dailyQuoteProvider.future);

    expect(
      first,
      const QuoteResult(
        quote: Quote(text: 'Text', author: 'Author'),
        source: QuoteSource.fresh,
      ),
    );
    expect(second, first);
    expect(requests, 1);
  });
}
