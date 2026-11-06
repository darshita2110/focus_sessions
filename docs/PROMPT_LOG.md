# Prompt Log

## 1. Project setup and CLAUDE.md
- **Tool:** Claude chat
- **Asked:** Help planning the assignment and drafting CLAUDE.md.
- **Claude produced:** A build plan, technical choices, and a first CLAUDE.md.
- **What I did:** Edited a few lines that were irrelevant
- **Commit:** Set up Flutter project and Claude working rules

## 2. Session model
- **Tool:** Claude Code for the plan and code, Claude chat for review
- **Asked:** Asked Claude Code to read CLAUDE.md and propose the Session model before writing code. I then asked Claude chat to review the plan and code.
- **Claude produced:** An immutable Session model with JSON conversion, a derived actualDuration, UTC timestamps, and unit tests.
- **What I did:** Accepted it with changes. I used a FocusLength enum, did not add an id, and kept toString for readable test failures.
- **Pushbacks:**
  - **Invalid JSON values:** The plan did not cover values like plannedMinutes: 30 or an end time before the start time. I asked for FormatException and tests.
  - **Unneeded timestamp check:** I removed a check for timestamps with no offset, because toJson always includes Z.
  - **UTC and local dates:** Using UTC dates directly could show sessions under the wrong day, so I added a doc comment and CLAUDE.md rule. This was confirmed in entry 6.
- **Result:** flutter analyze: No issues found. flutter test: All tests passed.
- **Commit:** Add Session model with strict JSON parsing to protect saved history


## 3. SessionRepository
- **Tool:** Claude Code for the plan and code, Claude chat for review
- **Asked:** Asked for a plan for loading, adding, and deleting sessions with shared_preferences, including how it would handle corrupted data, before any code was written.
- **Claude produced:** A repository that stores one JSON string per session, skips corrupted entries, keeps them on write, and returns sessions newest first.
- **What I did:** Accepted the design with these changes:
  - Chose StateError for duplicate start times instead of replacing the session, because note editing is not a requirement.
  - Did not add a fake SharedPreferences just to test one failed-write path. I will list this in the README.
- **Pushbacks:**
  - **Delete could silently fail:** The plan took a DateTime, but DateTime == treats the same moment in UTC and local time as different. I asked for isAtSameMomentAs and a toLocal() test. To confirm it, I temporarily changed the code to compare with != and the test failed. I then restored the code.
  - **Unneeded wrong-type handling:** I removed the handling for a wrong type under the sessions key. Only this repository writes to that key, and hiding that error could mask a real bug.
- **Result:** flutter analyze: No issues found! (ran in 2.5s)
. flutter test: All tests passed!.
- **Commit:** Add SessionRepository so sessions survive app restarts


## 4. Timer logic
- **Tool:** Claude Code for the plan and code, Claude chat for review
- **Asked:** Asked for a plan for the timer state, ticking, cleanup, clock changes, and test timing before any code was written.
- **Claude produced:** A plan that saved sessions immediately and also stored the running session across app kills. After my changes, it built sealed timer states, a synchronous Notifier, injectable clock and ticker providers, and tests.
- **What I did:** Rejected the first plan, then accepted the revised code with one cleanup. I accepted flutter_riverpod ^2.6.1 because it resolves with this project's Dart version.
- **Pushbacks:**
  - **Missing note step:** The plan saved a session as soon as it ended, but the assignment asks for a note first and Session is immutable. I required a TimerEnded state and saveNote, with tests for saving, double-taps, and failed saves.
  - **Unneeded persistence:** The plan added ActiveSession, new repository methods, and restore logic for app kills. The assignment only requires finished sessions to survive a restart, so I removed them. A running session is lost if Android kills the app, and I will list that in the README.
  - **Dead code:** The negative check in _clampDuration could never run because _tick finishes the session first, so I removed it.
- **Result:** flutter analyze: No issues found! (ran in 4.3s). flutter test: All tests passed!.
- **Commit:** Add focus timer logic with a note step before saving


## 5. Home screen
- **Tool:** Claude Code for the code, Claude chat for review
- **Asked:** Asked Claude to connect the timer to a home screen with idle, running, and note states, without building History or the quote.
- **Claude produced:** main.dart setup, a state-driven HomeScreen, rounded-up countdown seconds, and widget and unit tests.
- **What I did:** Accepted it. I kept the catch-all error handling on Save, because the user sees a retry message instead of a crash, although this can hide the exact cause of a bug.
- **Verified:** flutter analyze: No issues found! (ran in 4.4s). flutter test: All tests passed!. 
- **Commit:** Connect timer to home screen so sessions can be run and saved


## 6. History screen
- **Tool:** Claude Code for the code, Claude chat for review
- **Asked:** Asked for a History screen with loading, error, and empty states, swipe to delete, refresh after saving, and midnight date tests.
- **Claude produced:** A history notifier, History screen, Home navigation, and tests. It added beforeRestore so a failed delete does not trigger Flutter's dismissed Dismissible error.
- **What I did:** Accepted it. Claude Code temporarily broke four behaviors, and the tests caught each one. It also removed one of its own tests because the test did not check what its name claimed.
- **UTC pushback confirmed:** Removing toLocal() made the just-after-midnight test fail on my IST machine.
- **Bug found:** Claude Code reproduced a failed-write bug in SessionRepository. Claude chat had earlier advised skipping that test, and I reversed that decision in entry 7.
- **Result:** flutter analyze: No issues found. flutter test: 87 tests passed. Device: Not run yet.
- **Commit:** Add History screen with swipe to delete


## 7. Failed storage writes
- **Tool:** Claude Code, with Claude chat for review
- **Asked:** Asked Claude Code to fix the failed-write bug and test it with the real SharedPreferences class.
- **Claude produced:** A reload after failed writes, plus retry tests using a failing store.
- **What I did:** Accepted it and reversed my earlier decision not to test this path. The earlier fake failed before reaching SharedPreferences, so it could not expose the bug.
- **Result:** flutter analyze: No issues found. flutter test: 91 tests passed. All 4 new retry tests failed with reload() removed.
- **Commit:** Reload saved data after failed writes so retries work


## 8. Daily quote
- **Tool:** Claude Code for the code, Claude chat for review
- **Asked:** Asked for a ZenQuotes daily quote with a timeout, a cached quote, a built-in fallback, loading and fallback states, the INTERNET permission, and MockClient tests.
- **Claude produced:** A QuoteRepository, Quote model, provider, DailyQuote widget, and 51 tests. Before writing the parser, it checked the real API response and the ZenQuotes docs.
- **What I did:** Accepted it. Claude Code temporarily broke five behaviors, and the tests caught each one. I accepted two additions beyond my prompt: decoding the response as UTF-8, and making Home scroll so a long quote cannot overflow.
- **Claude caught my mistake:** My prompt asked for a plain-text credit, but ZenQuotes requires a link for free use. I fixed this in entry 9.
- **Known limits:** The rate-limit response is undocumented, and an app left open overnight keeps yesterday's quote. I will list both in the README.
- **Result:** flutter analyze: No issues found. flutter test: 142 tests passed. Device: Not run yet.
- **Commit:** Add daily quote with cached and built-in fallbacks