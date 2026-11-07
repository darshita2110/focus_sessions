# Focus Sessions

Single-user Flutter app for running timed focus blocks (15, 25 or 45 minutes)
and reviewing them afterwards. No login and no custom backend.

- Target: Android
- Flutter: 3.27.4 stable
- Priority: correctness, app states and tests over UI polish. Material defaults are fine.

## Project structure

```text
lib/
  main.dart                 App entry point and ProviderScope
  models/                   Plain Dart data classes
  data/                     Persistence and network access
  providers/                Riverpod providers and notifiers
  screens/                  One file per screen
  widgets/                  Reusable widgets
  legacy/streak_counter.dart
test/                       Mirrors the lib/ structure
docs/PROMPT_LOG.md          Record of work done with Claude
```

## State management

- Use Riverpod consistently, with `Notifier` or `AsyncNotifier` for shared state.
- Do not use Riverpod code generation.
- Use `ref.watch` in `build` and `ref.read` in callbacks.
- Keep business logic in models, repositories or notifiers, not widgets.
- Use `setState` only for state local to one widget, never for shared state.

## Conventions

- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables and functions: `camelCase`
- Prefer `const` constructors where possible.
- Keep widgets small and split up large `build` methods.
- Test files end in `_test.dart`.

## Domain rules

- Store a running session's end time. Calculate remaining time from the clock;
  never decrement a counter.
- Make the clock injectable so timer logic can be tested without real delays.
- All session storage goes through `SessionRepository`, using JSON in
  `shared_preferences`.
- All quote fetching goes through `QuoteRepository`, using the ZenQuotes
  `/api/today` endpoint.
- Quote requests need a timeout. If a request fails, use the last cached quote,
  then a built-in fallback quote.
- Session times are stored in UTC. Convert with `.toLocal()` before showing dates or grouping by day.

## Approved packages

- `flutter_riverpod`
- `shared_preferences`
- `http`
- `intl`
- `url_launcher`
- `shared_preferences_platform_interface` (test-only dev dependency, for a failing store; do not import it from `lib/`)

## Do not

- Do not add packages without asking first.
- Do not commit. I review and commit every change myself.
- Do not change or weaken a test just to make it pass.
- Do not refactor code unrelated to the current task.
- Do not start bonus features until I ask.
- Do not build more than the current task needs.
- Do not say something works unless you ran it. Report the actual result.

## How to work with me

- Work on one feature or file at a time.
- For anything non-trivial, briefly outline your approach before editing.
- Explain non-obvious decisions so I can defend them in an interview.
- Tell me when you are unsure or when there is a real trade-off.
- After code changes, run `flutter analyze` and `flutter test`, then show me the results.