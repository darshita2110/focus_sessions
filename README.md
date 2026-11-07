# Focus Sessions

A single-user Flutter app for timed focus blocks (15, 25, or 45 minutes) with a note for each session, a history list, and a daily quote. Built for the Junior Flutter Developer first-round assignment using Claude as a pair programmer.

**Video walkthrough:** [Loom link]

## Status

All 7 required items are done and tested:

| Requirement | Where |
|---|---|
| Home screen with 15/25/45 min sessions, live countdown, end early | `lib/screens/home_screen.dart`, `lib/providers/focus_timer_provider.dart` |
| Note on finish or early stop, then save | Timer state `TimerEnded` and `saveNote` |
| History, newest first, swipe to delete | `lib/screens/history_screen.dart` |
| Persistence across restarts | `lib/data/session_repository.dart` |
| Daily quote with loading, error, offline, and fallback states | `lib/data/quote_repository.dart`, `lib/widgets/daily_quote.dart` |
| Riverpod for all shared state | `lib/providers/` |
| Unit and widget tests | `test/`: 154 tests |

Part 2: `lib/legacy/streak_counter.dart` is fixed, with one test per bug in `test/legacy/streak_counter_test.dart`. There was no starter repo, so I added the snippet from the assignment text unchanged in its own commit before fixing it.

Bonus: the timer keeps correct time when the app is backgrounded and resumed, because remaining time is always calculated from the session's end time. No other bonus items were done.

## How to run

Requirements: Flutter 3.27.4 stable (Dart 3.6.2) and JDK 17 or 21. Android Studio's bundled JDK works.

```bash
flutter pub get
flutter run
flutter test
flutter analyze
```

Tested on Android only: a Realme RMX5111 running Android 16.

## Package choices

- **flutter_riverpod:** Notifiers can be unit tested without a widget tree, and the clock, ticker, HTTP client, and storage can be overridden in tests. No code generation.
- **shared_preferences:** Enough for one user's list of sessions. Each session is stored as its own JSON string, so a corrupted entry only loses itself. The trade-off is that every save rewrites the whole list, which is fine at this size.
- **http:** Its `MockClient` makes the success, error, timeout, and invalid-data cases easy to test.
- **intl:** Date formatting in History.
- **url_launcher:** ZenQuotes requires a link back to zenquotes.io on its free tier.
- **shared_preferences_platform_interface** (test only): Provides a store that fails writes, to test retries after a failed save.

## Structure

```text
lib/models/      Session, FocusLength, timer states, Quote
lib/data/        SessionRepository, QuoteRepository
lib/providers/   Riverpod providers and notifiers
lib/screens/     Home and History
lib/widgets/     DailyQuote
lib/legacy/      StreakCounter (Part 2)
```

Times are stored in UTC and converted with `toLocal()` before being shown or grouped by day.

## Known issues and limits

- A running session is kept in memory only, so it is lost if Android kills the app. Finished sessions are saved.
- There is no notification when a session ends in the background.
- The quote is fetched once per launch, so an app left open overnight shows yesterday's quote.
- ZenQuotes does not document its rate-limit reply. If it returns a normal-looking quote, the app would show and cache it.
- After a session ends, the note must be saved before starting another. An empty note is allowed.
- History shows only the date, in US format.
- StreakCounter: no session today returns 0, matching the doc comment's "ending today". Daylight saving is not tested, because IST has none, and the UTC test cannot catch anything on a machine set to UTC.
- The Android Gradle Plugin was upgraded from 8.1.0 to 8.2.1, and Gradle from 8.3 to 8.5, because the template version fails to build with Java 21.

## Working with Claude

- `CLAUDE.md`: Instructions for Claude.
- `docs/PROMPT_LOG.md`: Every meaningful exchange, with pushbacks.
- `docs/conversations/`: Full conversations for Part 2 and the review pass.
- `docs/REFLECTION.md`: What I learned.