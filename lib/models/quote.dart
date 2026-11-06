/// A quote and its author.
class Quote {
  const Quote({required this.text, required this.author});

  /// Reads the ZenQuotes format, where `q` is the text and `a` the author.
  ///
  /// Throws [FormatException] if either is missing, not a String, or blank.
  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      text: _readText(json, 'q'),
      author: _readText(json, 'a'),
    );
  }

  final String text;
  final String author;

  Map<String, dynamic> toJson() => {'q': text, 'a': author};

  static String _readText(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty String', value);
    }
    return value;
  }

  @override
  bool operator ==(Object other) =>
      other is Quote && other.text == text && other.author == author;

  @override
  int get hashCode => Object.hash(text, author);

  @override
  String toString() => 'Quote(text: $text, author: $author)';
}

/// Where a displayed quote came from.
enum QuoteSource {
  /// Fetched just now.
  fresh,

  /// The last successful fetch, because a new one could not be fetched.
  cached,

  /// Built into the app, because nothing could be fetched or read from cache.
  fallback,
}

/// A quote plus where it came from.
class QuoteResult {
  const QuoteResult({required this.quote, required this.source});

  final Quote quote;
  final QuoteSource source;

  @override
  bool operator ==(Object other) =>
      other is QuoteResult && other.quote == quote && other.source == source;

  @override
  int get hashCode => Object.hash(quote, source);

  @override
  String toString() => 'QuoteResult(quote: $quote, source: $source)';
}
