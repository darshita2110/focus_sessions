import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_sessions/models/quote.dart';
import 'package:focus_sessions/providers/daily_quote_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows today's quote, with a note if it is not a freshly fetched one.
class DailyQuote extends ConsumerWidget {
  const DailyQuote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(dailyQuoteProvider).when(
          loading: () => const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          // The repository handles network and data failures, so this is only
          // reachable through a bug. A missing quote should not block the timer.
          error: (_, __) => const SizedBox.shrink(),
          data: (result) => _QuoteText(result: result),
        );
  }
}

class _QuoteText extends StatelessWidget {
  const _QuoteText({required this.result});

  final QuoteResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sourceNote = _sourceNote(result.source);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          result.quote.text,
          style: textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '— ${result.quote.author}',
          style: textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        if (sourceNote != null) ...[
          const SizedBox(height: 8),
          Text(
            sourceNote,
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        // The built-in quote is not from ZenQuotes, so it gets no credit.
        if (result.source != QuoteSource.fallback) ...[
          const SizedBox(height: 8),
          const _ZenQuotesCredit(),
        ],
      ],
    );
  }

  static String? _sourceNote(QuoteSource source) {
    return switch (source) {
      QuoteSource.fresh => null,
      QuoteSource.cached =>
        'Could not fetch a new quote. Showing the last saved one.',
      QuoteSource.fallback =>
        'Could not fetch a quote. Showing a built-in one.',
    };
  }
}

/// The attribution link ZenQuotes requires on its free tier.
class _ZenQuotesCredit extends StatelessWidget {
  const _ZenQuotesCredit();

  static final _url = Uri.parse('https://zenquotes.io/');

  /// launchUrl reports failure by returning false or throwing. Either way the
  /// user just stays in the app, so both are ignored.
  Future<void> _open() async {
    try {
      await launchUrl(_url, mode: LaunchMode.externalApplication);
    } on Exception {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        textStyle: Theme.of(context).textTheme.labelSmall,
      ),
      onPressed: _open,
      child: const Text('Quotes provided by ZenQuotes API'),
    );
  }
}
