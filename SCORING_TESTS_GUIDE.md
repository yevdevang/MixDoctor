# Scoring System Test Guide

## Overview

This guide explains how to test the Claude API scoring system to ensure it:
1. **Differentiates** between different quality levels (not all identical scores)
2. **Respects ranges** (Mix: 75-90, Masters: 88-100)
3. **Handles genres** appropriately (Metal allows wide stereo, EDM allows lower phase)
4. **Handles stages** correctly (Mix vs Master(Streaming) vs Master(CD/Loud))

## Test Files

### 1. `AudioImportServiceTests.swift`
**Unit tests** for audio import, file naming with stages, and duplicate detection.

**What it tests:**
- File naming with stage suffixes (Mix, Master(Streaming), Master(CD-Loud))
- Base name extraction from files with stage suffixes
- Stage display name conversion (internal → display)
- Duplicate detection (same file + different stage = allowed, same stage = blocked)
- Multiple imports workflow (3 stages create 3 separate files)

**How to run:**
```bash
# In Xcode:
Cmd + U (Run all tests)

# Or run specific file naming tests:
Cmd + 6 (Test Navigator) → AudioImportServiceTests → Click diamond next to test
```

**See also:** [FILE_NAMING_TESTS_GUIDE.md](FILE_NAMING_TESTS_GUIDE.md) for detailed test documentation.

---

### 2. `ClaudeAPIScoringTests.swift`
**Unit tests** for scoring logic and parsing.

**What it tests:**
- Score range validation (Mix: cap at 90, no floor | Masters: cap at 100, no floor)
- Score differentiation (different quality = different scores)
- Genre-specific scoring (Metal, EDM, etc.)
- Stage-specific scoring (Mix, Master(Streaming), Master(CD/Loud))
- Edge cases (unmixed tracks, clipping, etc.)
- **NEW:** Convergence fix tests (floors removed, caps maintained)
- **NEW:** Weak/unmixed tracks score below 75 (no artificial floor)
- **NEW:** Amateur masters score below 95 (no artificial floor)

**How to run:**
```bash
# In Xcode:
Cmd + U (Run all tests)

# Or run specific test:
Cmd + Option + U (Run current test)
```

### 3. `ClaudeAPIScoringIntegrationTests.swift`
**Integration tests** with realistic scenarios.

**What it tests:**
- Three different songs get different scores (Korn, User Mix, Abbey Road)
- Same song with different stages gets appropriate scores
- Same song with different genres gets appropriate scores
- Quality level differentiation (excellent vs good vs decent)
- **NEW:** Korn vs Amateur differentiation (no convergence to same score)
- **NEW:** Multiple professional tracks don't converge to 75 or 95
- **NEW:** Full quality spectrum distribution (50-100 range)

**How to run:**
```bash
# Same as above - run in Xcode
Cmd + U
```

## Test Scenarios

### Scenario 1: Three Different Songs
**Expected:** Different scores, not all identical

| Song | Stage | Genre | Expected Range |
|------|-------|-------|----------------|
| Korn Master | Master(Streaming) | Metal | 96-100 |
| User Mix | Mix | Metal | 85-90 |
| Abbey Road Master | Master(CD/Loud) | Rock | 88-95 |

**Test:** `testThreeSongs_Differentiation()`

### Scenario 2: Same Song, Different Stages
**Expected:** Mix scores lower than Masters

| Stage | Expected Range | Notes |
|-------|----------------|-------|
| Mix | **Cap at 90, no floor** | Allow scores below 75 for weak mixes |
| Master(Streaming) | **85-100** | Allow scores below 95 for amateur masters |
| Master(CD/Loud) | **85-100** | Allow scores below 95 for amateur masters |

**Test:** `testSameSong_DifferentStages()`, `testSameSongDifferentStages_Differentiation()`

### Scenario 3: Same Song, Different Genres
**Expected:** Genre-appropriate scoring

| Genre | Expected Range | Notes |
|-------|----------------|-------|
| Metal | 96-100 | Allows wide stereo (95%+) |
| Pop | 90-95 | Might penalize wide stereo |
| Rock | 92-97 | Between metal and pop |

**Test:** `testSameSong_DifferentGenres()`

### **NEW:** Scenario 4: Score Convergence Prevention
**Expected:** Different quality levels get different scores (no convergence to 75 or 95)

| Quality Level | Stage | Expected Range | Notes |
|---------------|-------|----------------|-------|
| Exceptional (Korn) | Master | 96-100 | Top tier |
| Excellent | Master | 92-95 | Commercial quality |
| Very Good | Master | 88-91 | Professional |
| Good | Master | 85-87 | Some flaws |
| Amateur | Master | 75-84 | Needs improvement |
| Professional | Mix | 85-90 | Ready for mastering |
| Good Amateur | Mix | 78-84 | Strong work |
| Decent | Mix | 68-77 | Needs work |
| Weak/Unmixed | Mix | 50-67 | **No floor!** |

**Tests:**
- `testMixScore_NoFloor()` - Verify scores below 75 are allowed
- `testMasterScore_NoFloor()` - Verify scores below 95 are allowed
- `testKornVsAmateurDifferentiation()` - Korn should score higher than amateur
- `testMultipleProfessionalTracks_NoConvergence()` - Professional tracks should NOT all score 75 or 95
- `testWeakUnmixedTracks_NoFloor()` - Unmixed should score 50-67

## Running Tests

### In Xcode:
1. Open project: `MixDoctor.xcodeproj`
2. Select test target: `MixDoctorTests`
3. Run tests: `Cmd + U`
4. View results in Test Navigator (`Cmd + 6`)

### Command Line:
```bash
# Run all tests
xcodebuild test -scheme MixDoctor -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -scheme MixDoctor -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MixDoctorTests/ClaudeAPIScoringTests

# Run specific test method
xcodebuild test -scheme MixDoctor -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MixDoctorTests/ClaudeAPIScoringTests/testMixStage_ScoreRange
```

## What to Verify

### ✅ Score Ranges (Updated - Floors Removed)
- [ ] Mix scores are **capped at 90** (no floor - can go below 75)
- [ ] Master(Streaming) scores are **85-100** (no floor at 95)
- [ ] Master(CD/Loud) scores are **85-100** (no floor at 95)
- [ ] Weak/unmixed mixes can score **50-67** (floor removed)
- [ ] Amateur masters can score **75-84** (floor removed)

### ✅ Differentiation (Convergence Fix)
- [ ] Different songs get different scores (not all identical)
- [ ] **NO convergence to 75 for all mixes** (floor removed)
- [ ] **NO convergence to 95 for all masters** (floor removed)
- [ ] Korn masters score **96-100**, amateur masters score **75-84**
- [ ] Professional mixes score **85-90**, amateur mixes score **70-84**
- [ ] Excellent masters score higher than good masters
- [ ] Excellent mixes score higher than good mixes
- [ ] Mix scores are lower than Master scores

### ✅ Genre Handling
- [ ] Metal allows wide stereo (95%+) without penalty
- [ ] EDM allows lower phase coherence (50%+) without heavy penalty
- [ ] Pop/Rock have balanced expectations

### ✅ Stage Handling
- [ ] Master(Streaming) rewards -14 to -16 LUFS
- [ ] Master(CD/Loud) rewards -6 to -9 LUFS
- [ ] Mix doesn't penalize for being quieter

## Manual Testing Checklist

If automated tests aren't available, manually test:

1. **Import same file 3 times:**
   - Metal + Mix → Should score 75-90
   - Metal + Master(Streaming) → Should score 88-100
   - Metal + Master(CD/Loud) → Should score 88-100

2. **Import 3 different songs:**
   - Korn master → Should score 96-100
   - Your mix → Should score 80-90
   - Abbey Road master → Should score 90-95

3. **Verify scores are different:**
   - Not all 80, 95, 95
   - Should see variation: 80, 96, 92 (for example)

## Troubleshooting

### All scores are identical (e.g., all 75 or all 95)
**Problem:** Artificial floors causing convergence
**Solution:** ✅ **FIXED** - Floors removed in `ClaudeAPIService.swift`
- Mix floor at 75 removed (allow natural variation 50-90)
- Master floor at 95 removed (allow natural variation 85-100)
- **Tests:** `testMixScore_NoFloor()`, `testMasterScore_NoFloor()`, `testScoreConvergence_Prevention()`

### Mix scores below 75 for weak/unmixed tracks
**Problem:** This is CORRECT behavior now (floor removed)
**Solution:** No action needed - weak mixes should score 50-74
- Professional mixes: 85-90
- Good amateur: 78-84
- Decent: 68-77
- Weak/unmixed: 50-67

### Master scores below 95 for amateur masters
**Problem:** This is CORRECT behavior now (floor removed)
**Solution:** No action needed - amateur masters should score 75-94
- Exceptional (Korn): 96-100
- Excellent: 92-95
- Very good: 88-91
- Good: 85-87
- Amateur: 75-84

### Scores still don't differentiate
**Problem:** Claude ignoring quality differences
**Solution:** Check prompt for differentiation instructions:
- "DIFFERENT SONGS MUST GET DIFFERENT SCORES!"
- "Korn should NOT score the same as amateur"
- Explicit score ranges for each quality level

## Next Steps

1. **Run tests:** `Cmd + U` in Xcode
2. **Review results:** Check Test Navigator for failures
3. **Fix issues:** Adjust scoring logic in `ClaudeAPIService.swift`
4. **Re-test:** Run tests again to verify fixes
5. **Document:** Update this guide with any new test scenarios

## Notes

- Tests currently use placeholders - need to implement actual Claude API mocking or use real API calls
- Integration tests require API key - consider using environment variables or test configuration
- Some tests are documentation-only - implement actual assertions when API mocking is available
