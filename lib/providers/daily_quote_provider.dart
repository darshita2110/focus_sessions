import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_sessions/models/quote.dart';
import 'package:focus_sessions/providers/core_providers.dart';

/// Not autoDispose, so moving between timer states does not fetch again.
final dailyQuoteProvider =
    AsyncNotifierProvider<DailyQuoteNotifier, QuoteResult>(
  DailyQuoteNotifier.new,
);

/// Today's quote, fetched once per app launch.
class DailyQuoteNotifier extends AsyncNotifier<QuoteResult> {
  @override
  Future<QuoteResult> build() =>
      ref.watch(quoteRepositoryProvider).fetchDailyQuote();
}
