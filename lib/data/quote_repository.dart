import 'dart:convert';

import 'package:focus_sessions/models/quote.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Fetches the ZenQuotes quote of the day.
///
/// Never fails for network or data problems: it falls back to the last
/// successful quote, then to [fallbackQuote].
class QuoteRepository {
  QuoteRepository(
    this._client,
    this._prefs, {
    this.timeout = const Duration(seconds: 5),
  });

  static const fallbackQuote = Quote(
    text: 'We are what we repeatedly do. Excellence, then, is not an act, '
        'but a habit.',
    author: 'Will Durant',
  );

  static const _cacheKey = 'last_quote';
  static final _todayUrl = Uri.parse('https://zenquotes.io/api/today');

  final http.Client _client;
  final SharedPreferences _prefs;
  final Duration timeout;

  /// Returns today's quote and where it came from.
  Future<QuoteResult> fetchDailyQuote() async {
    final Quote quote;
    try {
      quote = await _fetch();
    } on Exception {
      return _cachedOrFallback();
    }
    await _saveToCache(quote);
    return QuoteResult(quote: quote, source: QuoteSource.fresh);
  }

  Future<Quote> _fetch() async {
    final response = await _client.get(_todayUrl).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Unexpected status ${response.statusCode}',
        _todayUrl,
      );
    }
    // Decoded from bytes because JSON is always UTF-8, while response.body
    // assumes Latin-1 if the server leaves out the charset.
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! List || json.isEmpty) {
      throw const FormatException('Expected a non-empty list');
    }
    final first = json.first;
    if (first is! Map<String, dynamic>) {
      throw const FormatException('Expected a quote object');
    }
    return Quote.fromJson(first);
  }

  /// A failed cache write only costs the next offline launch this quote, so it
  /// must not throw away the quote that was just fetched.
  Future<void> _saveToCache(Quote quote) async {
    try {
      await _prefs.setString(_cacheKey, jsonEncode(quote.toJson()));
    } on Exception {
      return;
    }
  }

  QuoteResult _cachedOrFallback() {
    final cached = _readCache();
    if (cached != null) {
      return QuoteResult(quote: cached, source: QuoteSource.cached);
    }
    return const QuoteResult(
      quote: fallbackQuote,
      source: QuoteSource.fallback,
    );
  }

  /// Returns `null` if nothing is cached or the cached value is not valid.
  Quote? _readCache() {
    final stored = _prefs.getString(_cacheKey);
    if (stored == null) return null;
    try {
      final json = jsonDecode(stored);
      return json is Map<String, dynamic> ? Quote.fromJson(json) : null;
    } on FormatException {
      return null;
    }
  }
}
