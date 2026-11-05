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
- **Commit:** [commit hash and message]