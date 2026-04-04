# Coding Standards

## Swift

- Swift 5.9+ features preferred (macros, parameter packs where applicable)
- No `Any` types — use proper typing or generics
- Define structs/classes for all models, API responses, and data transfer objects
- Use type inference where obvious, explicit types where it aids readability
- Prefer `let` over `var`; mutate only when necessary

## SwiftUI

- Functional views only — no UIKit views
- Use `@Observable` for ViewModels (not `ObservableObject` / `@StateObject`)
- Use `@State private var viewModel` pattern in views (not `@StateObject`)
- Keep views focused — one job per view; extract subviews aggressively
- Extract reusable logic into ViewModels or service layers, not into views

## ViewModels

- All ViewModels use `@Observable` macro
- ViewModels are instantiated as `@State private var` in the owning view
- Optional ViewModel pattern for async initialization:

```swift
@State private var viewModel: MyViewModel?

var body: some View {
    if let viewModel {
        contentView(viewModel: viewModel)
    } else {
        ProgressView("Loading...")
            .task { await initializeViewModel() }
    }
}
```

- Use `FetchDescriptor` inside ViewModels for SwiftData queries
- Use `@Query` only in Views

## Data Layer (SwiftData + iCloud)

- **Never store full file paths** in SwiftData models — paths change between simulator builds; store filenames only
- Use `@Transient` computed properties for large arrays (e.g., `[Float]`) backed by `Data` storage — direct array storage crashes CloudKit sync
- `AudioFile.fileURL` is always a `@Transient` computed property reconstructed at runtime
- Two-layer sync: SwiftData+CloudKit for metadata, iCloud Documents for audio files

## Services

- All services are singletons accessed via `.shared`
- `@MainActor` services (e.g., `AudioImportService`) require `async setUp/tearDown` in tests with initialization delay
- Always call `reset()` in both `setUp()` and `tearDown()` in singleton tests to prevent state leakage
- Never call `scanForOrphanedFiles()` on view appear — causes import timeout errors

## File Organization

- Features: `MixDoctor/Features/[Feature]/Views/`, `MixDoctor/Features/[Feature]/ViewModels/`
- Core services: `MixDoctor/Core/Services/`
- Models: `MixDoctor/Core/Models/`
- Extensions: `MixDoctor/Core/Extensions/`
- Utilities: `MixDoctor/Core/Utilities/`
- Shared views: `MixDoctor/Core/Views/`

## Naming

- Types, structs, classes, enums: `PascalCase`
- Functions, variables, properties: `camelCase`
- Constants: `camelCase` (Swift convention) or `static let` on a type
- Files: match the primary type they contain (`AudioFile.swift`, `DashboardView.swift`)
- SwiftUI views: suffix with `View` (`DashboardView`, `ImportView`)
- ViewModels: suffix with `ViewModel` (`ImportViewModel`, `AnalysisViewModel`)

## Styling

- SwiftUI only — no UIKit views
- Primary accent color: `Color(red: 0.435, green: 0.173, blue: 0.871)` (purple)
- No hardcoded magic numbers — use named constants or design tokens
- Mac Catalyst UI adjustments must be wrapped in `#if targetEnvironment(macCatalyst)`

## Cross-View Communication

- Use `NotificationCenter` for decoupled cross-view updates:

```swift
// Post
NotificationCenter.default.post(name: .audioFileDeleted, object: nil)

// Receive
.onReceive(NotificationCenter.default.publisher(for: .audioFileDeleted)) { _ in
    viewModel.loadImports()
}
```

## Error Handling

- Use `do/catch` with typed errors where possible
- Surface user-facing errors through ViewModel `@Published`-equivalent state, not raw alerts in views
- Log errors via `Logger` (OSLog) — no `print()` in production code

## Subscriptions & Paywall

- All analysis gating goes through `SubscriptionService.canPerformAnalysis()` — never bypass
- No free trial UI — all trial references removed; `isInTrialPeriod` kept only for backward compat
- Use `MockSubscriptionService` + `MockPaywallView` for testing without App Store Connect

## Code Quality

- No commented-out code unless explicitly noted
- No unused imports or variables
- Keep functions under 50 lines when possible
- No `// TODO` left in committed code unless tracked in an issue
