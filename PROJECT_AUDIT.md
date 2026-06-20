# MixDoctor Project Audit

A prioritized punch list of improvements across AI prompts, features, code quality, and UX.

---

## HIGH PRIORITY — Will improve scoring quality

### 1. Prompts produce inconsistent scores (the big one)
**Files:** `ClaudeAPIService.swift`, `OpenAIService.swift`

Three compounding problems:

- **No temperature setting** → defaults to ~1.0 (creative). Same mix scores differently each run.
  **Fix:** set `"temperature": 0.3` on all API calls.
- **No few-shot examples** → Claude has no calibration anchor for "what does a 75 actually look like."
  **Fix:** include 3–5 example metric-to-score mappings per mix stage in the system prompt (cacheable).
- **Output is parsed via regex** (~70 lines around `ClaudeAPIService.swift:1745-1815`). Brittle.
  **Fix:** use structured JSON output with a schema + a `Decodable` response struct. Anthropic SDK supports it.

These three changes alone would meaningfully reduce score variance complaints.

### 2. Prompt is bloated (~800–1200 wasted tokens/call)
Repetitive frequency-band guidelines and genre rules duplicated across the prompt.

**Fix:** refactor into a **cached** system prompt (rules + examples) + a **minimal** user message (just JSON metrics + stage label). Saves cost on every analysis and speeds up responses.

### 3. Force unwraps in critical paths
- `ClaudeAPIService.swift:230` — `URL(string: apiURL)!`
- `AnalysisResultPersistence.swift:87` — `iCloudContainerURL!` (crashes for users who disable iCloud Drive)

**Fix:** replace with `guard let` + graceful fallback.

---

## MEDIUM PRIORITY — User-facing wins

### 4. Analysis history exists but isn't surfaced
`AudioFile.analysisHistory` is stored but the UI never shows it.

**Fix:** add a timeline view in `ResultsView` showing score trends + frequency balance shifts over time. Strong re-engagement hook — users want proof they're improving.

### 5. Genre selection doesn't persist
User picks "Hip-Hop" → re-analyzes same file → picker resets.

**Fix:** store `selectedGenre` on `AudioFile`. One-line schema change.

### 6. Recommendations are text-only
Spectrum image generator exists but EQ suggestions like "cut 100Hz" have no visual overlay.

**Fix:** add a dashed "suggested curve" overlay on the spectrum.

### 7. Paywall has a 12.5× cliff (4 → 50 analyses)
Steep jumps hurt conversion vs. anchoring.

**Fix:** consider a middle tier (~15 analyses for ~$2.99/mo).

### 8. No rate-limit UX
HTTP 429 from Claude just logs to console — user sees infinite spinner.

**Fix:** surface a real alert ("Too many analyses. Try again in 5 minutes.").

---

## LOW PRIORITY — Polish

- **Debug logs everywhere** — 50+ `print()` calls with emoji shipped to release. Wrap in `#if DEBUG` or move to `os.Logger`.
- **Test coverage gap** — strong scoring tests, but paywall/onboarding have none. Add snapshot tests for tier rendering.
- **Onboarding skips genre guidance** — users pick wrong genre → bad scores. One-line tooltip in import flow.

---

## Where to start

If you only do one thing: **add `temperature=0.3` + few-shot examples to the Claude prompt** (~1 hour).
That single change attacks the most common complaint about AI-based scoring apps — inconsistency.

**Quickest wins (2–3 hours combined):**
1. Add few-shot examples (#1)
2. Fix force unwraps (#3)
3. Persist genre selection (#5)

**Highest ROI:** Fix prompts (#1, #2) + add history UI (#4). These directly improve scoring consistency and user retention.
