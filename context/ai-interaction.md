# AI Interaction Guidelines

## Communication

- Be concise and direct
- Explain non-obvious decisions briefly
- Ask before large refactors or architectural changes
- Don't add features not in the project spec
- Never delete files without clarification

## Workflow

This is the common workflow for every feature/fix:

1. **Document** — Document the feature in `context/current-feature.md`
2. **Branch** — Create a new branch (`feature/[name]` or `fix/[name]`)
3. **Implement** — Implement the feature/fix described in `context/current-feature.md`
4. **Build** — Run `xcodebuild build -scheme MixDoctor -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` and fix any errors
5. **Test** — Run relevant tests with `xcodebuild test -scheme MixDoctor -destination 'platform=iOS Simulator,name=iPhone 15'`
6. **Iterate** — Fix issues until build and tests pass
7. **Commit** — Only after build passes and everything works
8. **Review** — Review AI-generated code periodically and on demand
9. **Complete** — Mark as done in `context/current-feature.md` and add to history

Do NOT commit without permission and until the build passes. If build fails, fix the issues first.

## Branching

Create a new branch for every feature/fix. Name branches `feature/[feature]` or `fix/[fix]`. Ask to delete the branch once merged.

## Commits

- Ask before committing (don't auto-commit)
- Use conventional commit messages (`feat:`, `fix:`, `chore:`, etc.)
- Keep commits focused — one feature/fix per commit
- Never put "Generated With Claude" in commit messages

## When Stuck

- If something isn't working after 2–3 attempts, stop and explain the issue
- Don't keep trying random fixes
- Ask for clarification if requirements are unclear

## Code Changes

- Make minimal changes to accomplish the task
- Don't refactor unrelated code unless asked
- Don't add "nice to have" features
- Preserve existing patterns in the codebase

## Testing

- Tests live in `MixDoctorTests/`
- Run all tests: `xcodebuild test -scheme MixDoctor -destination 'platform=iOS Simulator,name=iPhone 15'`
- Run a specific class: append `-only-testing:MixDoctorTests/ClassName`
- Run a specific method: append `-only-testing:MixDoctorTests/ClassName/methodName`
- Integration tests are skipped by default — set `RUN_INTEGRATION_TESTS=1` to enable
- Call `reset()` in both `setUp()` and `tearDown()` for singleton-dependent tests
- `AudioKitWarmupTests` must run before other AudioKit tests (alphabetical order ensures this)

## Mac Catalyst

- Always wrap Mac-specific code in `#if targetEnvironment(macCatalyst)`
- Build Mac target separately: `xcodebuild build -scheme MixDoctorMac -destination 'platform=macOS'`
- Font scaling (1.4×) and window sizing are applied at app init — don't duplicate them in features

## Code Review

Review AI-generated code periodically, especially for:

- **SwiftData safety** — no full paths stored, `@Transient` used for large arrays
- **iCloud correctness** — files downloaded before AVFoundation access, no auto-orphan scans
- **Concurrency** — `@MainActor` used where required, no data races in async code
- **Subscription gating** — `canPerformAnalysis()` checked before triggering analysis
- **Mac Catalyst guards** — platform-specific code wrapped in `#if targetEnvironment(macCatalyst)`
