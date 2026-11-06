# Prompt Log

## 1. Project setup and CLAUDE.md
- **Tool:** Claude chat
- **Asked:** Help planning the assignment and drafting CLAUDE.md.
- **Claude produced:** A build plan, technical choices, and a first CLAUDE.md.
- **What I did:** Edited a few lines that were irrelevant
- **Commit:** Set up Flutter project and Claude working rules

## 2. Session model plan and review
- **Tool:** Claude Code for the plan and code, Claude chat for reviewing the plan
- **Asked:** Asked Claude Code to read CLAUDE.md and propose the Session model before writing code, including its fields, types, and reasons. I then asked Claude chat to review the plan.
- **Claude produced:** A plan for an immutable Session model with JSON conversion, a derived actualDuration, UTC timestamps, and unit tests. It also asked whether to add an id and whether to use Duration or an enum.
- **What I did:** Accepted the plan with these changes:
  - Used a FocusLength enum instead of Duration, so the compiler enforces the three lengths and the home screen can build its buttons from the enum values.
  - Did not add an id yet, because startTime is enough to identify a session in this single-user app.
- **Pushback candidates:**
  - **Invalid JSON values:** The plan covered missing fields and wrong types, but not invalid values like plannedMinutes: 20 or an end time before the start time. I asked for these to throw FormatException, with tests. [Confirmed by: test name or result]
  - **UTC and local dates:** Using UTC dates directly could put sessions under the wrong day. For example, 2:00 AM IST on Nov 7 is 8:30 PM UTC on Nov 6. I added a doc comment and a CLAUDE.md rule to use toLocal() before showing or grouping dates. [Confirmed by: what you checked]
- **Result:** flutter analyze: No issues found! (ran in 2.8s). flutter test: All tests passed!.
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