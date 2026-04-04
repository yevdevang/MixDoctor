# Test Action

1. Read `current-feature.md` to understand what was implemented
2. Identify services, ViewModels, and utility functions added/modified for this feature
3. Check if tests already exist for these in `MixDoctorTests/`
4. For functions without tests that have testable logic, write unit tests:
   - Use XCTest framework
   - Focus on services and ViewModels (not SwiftUI views)
   - Test happy path and error/edge cases
   - For `@MainActor` services: use `async setUp/tearDown` with initialization delay
   - For singletons: call `reset()` in both `setUp()` and `tearDown()` to prevent state leakage
   - For AudioKit tests: ensure `AudioKitWarmupTests` runs first (alphabetical order)
   - Set `RUN_INTEGRATION_TESTS=1` env var if the feature touches real API calls
   - Do not write tests just to write them — use your best judgement
5. Run tests to verify they pass:
   ```bash
   xcodebuild test -scheme MixDoctor -destination 'platform=iOS Simulator,name=iPhone 15'
   ```
   To run only the new test class:
   ```bash
   xcodebuild test -scheme MixDoctor -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MixDoctorTests/<TestClassName>
   ```
6. Report test coverage for the new feature code
