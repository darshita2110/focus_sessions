import 'package:flutter_test/flutter_test.dart';
import 'package:focus_sessions/models/quote.dart';

void main() {
  test('round-trips through JSON', () {
    const quote = Quote(text: 'Text', author: 'Author');

    expect(Quote.fromJson(quote.toJson()), quote);
  });

  test('reads q and a and ignores other fields', () {
    final quote = Quote.fromJson({'q': 'Text', 'a': 'Author', 'h': '<b>x</b>'});

    expect(quote, const Quote(text: 'Text', author: 'Author'));
  });

  const invalid = <String, Map<String, dynamic>>{
    'missing q': {'a': 'Author'},
    'missing a': {'q': 'Text'},
    'non-string q': {'q': 1, 'a': 'Author'},
    'non-string a': {'q': 'Text', 'a': null},
    'blank q': {'q': '  ', 'a': 'Author'},
    'blank a': {'q': 'Text', 'a': ''},
  };

  invalid.forEach((name, json) {
    test('throws FormatException for $name', () {
      expect(() => Quote.fromJson(json), throwsFormatException);
    });
  });
}
