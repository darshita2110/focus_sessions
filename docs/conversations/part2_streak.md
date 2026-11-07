## 10. Part 2: StreakCounter
- **Tool:** Claude Code, with Claude chat for review. Full conversation: docs/conversations/part2_streak.md
- **Asked:** First asked Claude Code to find and prove the bugs without fixing them: one failing test per bug, with an injectable clock so tests do not depend on the real date.
- **Claude produced:** Five bugs, each with a test that failed on the original code:
  1. It returns 1 even with no session today.
  2. It compares dates in the wrong direction, so yesterday gives -1 instead of 1.
  3. It uses 24-hour periods instead of calendar days, so the time of day breaks it.
  4. Two sessions on one day stop the streak.
  5. The loop starts at the wrong index and never reaches the oldest session.
- **What I did:**
  - Decided that no session today returns 0, matching the doc comment's "ending today".
  - Asked for a simpler rewrite: a Set of local calendar dates, walking back one day at a time. This removes the duration maths, sorting, and loop bounds behind bugs 2 to 5.
  - Added tests for an empty list, a single session, a 26-hour gap with a missing day, and UTC input near midnight. Removing toLocal() made the UTC test fail.
- **Known limits:** Daylight saving is untested, because IST has none. The UTC test cannot catch anything on a machine set to UTC.
- **Result:** flutter analyze: No issues found. flutter test: 153 tests passed.
- **Commit:** Fix StreakCounter to count consecutive local calendar days