---
name: cleanup
description: Clean up project housekeeping tasks (add "run" to execute fixes)
argument-hint: run|check
---

Review the codebase for cleanup tasks:

1. Make sure that the history in `context/current-feature.md` is in order from oldest to newest
2. Find unnecessary `print()` statements in `MixDoctor/` (use `Logger`/OSLog in production code)
3. Find unused imports (`import Foundation`, `import SwiftUI`, etc.)
4. Check for stale `// TODO` comments not tracked in an issue
5. Find orphaned/unused files (views, models, services with no references)
6. Check that context files (`context/`) match actual project state
7. Check `Config.xcconfig` has the same keys as `Config.xcconfig.template` — if anything is missing, report it
8. Find stale `// swiftlint:disable` or `// swiftformat:disable` comments that may no longer be needed
9. Check for any leftover free trial UI references (`isInTrialPeriod`, trial copy in views) that should have been removed

**Mode: $ARGUMENTS**

If no argument or argument is "check":

- Only report findings, don't modify anything
- List what WOULD be cleaned up

If the argument is "run" or "fix":

- First, report all findings with numbered items
- Then ask: "Which items would you like me to fix? (enter numbers like 1,3,5 or 'all' or 'none')"
- Wait for user response before making any changes
- Only fix the items the user specifies
- Report what you changed
