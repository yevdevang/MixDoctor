# File Naming with Stage - Tests Guide

## Overview
This document describes the test suite for the file naming with stage feature, ensuring that files are correctly named and duplicate detection works properly when importing the same audio file with different stages.

## Test File Location
```
MixDoctorTests/AudioImportServiceTests.swift
```

## How to Run Tests

### In Xcode
1. **Run all tests:**
   - Press `⌘ + U` or
   - Click Product → Test

2. **Run file naming tests only:**
   - Click the diamond icon next to `testFileNaming_*` test names
   - Or use Test Navigator (⌘ + 6) and select specific tests

3. **Run single test:**
   - Click the diamond icon next to the specific test function

### Via Command Line
```bash
# Run all tests
xcodebuild test -scheme MixDoctor -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -scheme MixDoctor -only-testing:MixDoctorTests/AudioImportServiceTests

# Run specific test
xcodebuild test -scheme MixDoctor -only-testing:MixDoctorTests/AudioImportServiceTests/testFileNaming_WithMixStage_AppendsCorrectSuffix
```

## Test Suite

### 1. File Naming Tests

#### `testFileNaming_WithMixStage_AppendsCorrectSuffix`
**Purpose**: Verify that "mix" stage creates correct filename suffix

**Given**: 
- Original file: `Twisted Transistor.wav`
- Stage: `mix`

**Expected**: 
- Generated filename: `Twisted Transistor - Mix.wav`

**Verifies**:
- ✅ Filename includes stage suffix
- ✅ Format is `[Name] - [Stage].[ext]`

---

#### `testFileNaming_WithStreamingMasterStage_AppendsCorrectSuffix`
**Purpose**: Verify that "master_streaming" stage creates correct filename suffix

**Given**: 
- Original file: `Twisted Transistor.wav`
- Stage: `master_streaming`

**Expected**: 
- Generated filename: `Twisted Transistor - Master(Streaming).wav`

**Verifies**:
- ✅ Internal stage name converts to display name
- ✅ Parentheses are included in filename

---

#### `testFileNaming_WithCDMasterStage_AppendsCorrectSuffix`
**Purpose**: Verify that "master_cd" stage creates correct filename suffix

**Given**: 
- Original file: `Twisted Transistor.wav`
- Stage: `master_cd`

**Expected**: 
- Generated filename: `Twisted Transistor - Master(CD-Loud).wav`

**Verifies**:
- ✅ Internal stage name converts to display name
- ✅ Hyphen instead of slash in filename (filesystem-safe)

---

### 2. Base Name Extraction Tests

#### `testBaseNameExtraction_FromFileWithStage_ExtractsCorrectly`
**Purpose**: Verify base name extraction from file with stage suffix

**Given**: 
- File: `Twisted Transistor - Master(Streaming).wav`

**Expected**: 
- Base name: `Twisted Transistor`

**Verifies**:
- ✅ Stage suffix is correctly removed
- ✅ Uses `.backwards` option to handle " - " in song titles

---

#### `testBaseNameExtraction_FromFileWithoutStage_ReturnsFullName`
**Purpose**: Verify base name extraction from file without stage suffix

**Given**: 
- File: `Twisted Transistor.wav`

**Expected**: 
- Base name: `Twisted Transistor`

**Verifies**:
- ✅ Works for files without stage suffix
- ✅ Returns original name when no " - " found

---

#### `testBaseNameExtraction_FromFileWithDashInName_ExtractsCorrectly`
**Purpose**: Verify base name extraction handles songs with " - " in title

**Given**: 
- File: `AC-DC - Thunderstruck - Mix.wav`
- Note: Song title itself contains " - "

**Expected**: 
- Base name: `AC-DC - Thunderstruck`

**Verifies**:
- ✅ Only removes LAST " - [Stage]"
- ✅ Preserves artist/title dashes
- ✅ Uses `.backwards` option correctly

---

### 3. Stage Display Name Conversion Tests

#### `testStageDisplayNameConversion_Mix_ConvertsCorrectly`
**Purpose**: Verify "mix" → "Mix" conversion

**Given**: Internal stage: `mix`

**Expected**: Display name: `Mix`

**Verifies**: ✅ Lowercase internal name converts to capitalized display name

---

#### `testStageDisplayNameConversion_MasterStreaming_ConvertsCorrectly`
**Purpose**: Verify "master_streaming" → "Master(Streaming)" conversion

**Given**: Internal stage: `master_streaming`

**Expected**: Display name: `Master(Streaming)`

**Verifies**: 
- ✅ Underscore replaced with parentheses
- ✅ Proper capitalization

---

#### `testStageDisplayNameConversion_MasterCD_ConvertsCorrectly`
**Purpose**: Verify "master_cd" → "Master(CD-Loud)" conversion

**Given**: Internal stage: `master_cd`

**Expected**: Display name: `Master(CD-Loud)`

**Verifies**: 
- ✅ Internal name converts to full display name
- ✅ Uses hyphen (filesystem-safe) instead of slash

---

### 4. Duplicate Detection Tests

#### `testDuplicateDetection_SameFileNameDifferentStage_ShouldAllowImport`
**Purpose**: Verify same file with different stage is NOT a duplicate

**Given**: 
- File 1: `Twisted Transistor - Mix.wav`, stage: `mix`
- File 2: `Twisted Transistor - Master(Streaming).wav`, stage: `master_streaming`

**Expected**: 
- Base names match: ✅
- Stages differ: ✅
- **NOT considered duplicate** ✅

**Verifies**:
- ✅ Base name comparison works
- ✅ Stage comparison works
- ✅ Different stages = allowed import

---

#### `testDuplicateDetection_SameFileNameSameStage_ShouldBlockImport`
**Purpose**: Verify same file with same stage IS a duplicate

**Given**: 
- File 1: `Twisted Transistor - Mix.wav`, stage: `mix`
- File 2: `Twisted Transistor - Mix.wav`, stage: `mix`

**Expected**: 
- Base names match: ✅
- Stages match: ✅
- **IS considered duplicate** ✅

**Verifies**:
- ✅ Base name comparison works
- ✅ Stage comparison works
- ✅ Same base name + same stage = blocked import

---

### 5. Multiple Import Workflow Test

#### `testMultipleImports_SameBaseDifferentStages_CreatesThreeSeparateFiles`
**Purpose**: Verify complete workflow of importing same file 3 times with different stages

**Given**: 
- Base file: `Twisted Transistor.wav`
- 3 stages: `mix`, `master_streaming`, `master_cd`

**Expected**: 
- 3 unique filenames generated
- File 1: `Twisted Transistor - Mix.wav`
- File 2: `Twisted Transistor - Master(Streaming).wav`
- File 3: `Twisted Transistor - Master(CD-Loud).wav`

**Verifies**:
- ✅ All 3 files have unique names
- ✅ Each stage produces correct filename
- ✅ No naming conflicts
- ✅ End-to-end workflow works

---

## Test Results Interpretation

### ✅ All Tests Pass
- File naming logic is correct
- Base name extraction handles edge cases
- Stage conversion works properly
- Duplicate detection is accurate
- Multiple imports create separate files

### ❌ Test Failures

#### File Naming Tests Fail
**Possible Causes**:
- Stage display name mapping is incorrect
- Filename format changed
- Extension handling broken

**Fix**: Check `copyToDocuments` function in `AudioImportService.swift`

#### Base Name Extraction Tests Fail
**Possible Causes**:
- `.backwards` option not used
- Incorrect range extraction
- Edge case not handled

**Fix**: Check base name extraction logic in duplicate detection

#### Stage Conversion Tests Fail
**Possible Causes**:
- Switch statement mapping incorrect
- New stage added without test update
- Case sensitivity issue

**Fix**: Check stage display name conversion in `copyToDocuments`

#### Duplicate Detection Tests Fail
**Possible Causes**:
- Base name comparison logic changed
- Stage comparison not working
- File size/duration check interfering

**Fix**: Check duplicate detection logic in `importAudioFile`

---

## Expected Test Output

### Console Output (Successful Run)
```
Test Suite 'AudioImportServiceTests' started
Test Case '-[MixDoctorTests.AudioImportServiceTests testFileNaming_WithMixStage_AppendsCorrectSuffix]' passed (0.001 seconds)
Test Case '-[MixDoctorTests.AudioImportServiceTests testFileNaming_WithStreamingMasterStage_AppendsCorrectSuffix]' passed (0.001 seconds)
Test Case '-[MixDoctorTests.AudioImportServiceTests testFileNaming_WithCDMasterStage_AppendsCorrectSuffix]' passed (0.001 seconds)
Test Case '-[MixDoctorTests.AudioImportServiceTests testBaseNameExtraction_FromFileWithStage_ExtractsCorrectly]' passed (0.001 seconds)
Test Case '-[MixDoctorTests.AudioImportServiceTests testBaseNameExtraction_FromFileWithoutStage_ReturnsFullName]' passed (0.001 seconds)
Test Case '-[MixDoctorTests.AudioImportServiceTests testBaseNameExtraction_FromFileWithDashInName_ExtractsCorrectly]' passed (0.001 seconds)
Test Case '-[MixDoctorTests.AudioImportServiceTests testStageDisplayNameConversion_Mix_ConvertsCorrectly]' passed (0.001 seconds)
Test Case '-[MixDoctorTests.AudioImportServiceTests testStageDisplayNameConversion_MasterStreaming_ConvertsCorrectly]' passed (0.001 seconds)
Test Case '-[MixDoctorTests.AudioImportServiceTests testStageDisplayNameConversion_MasterCD_ConvertsCorrectly]' passed (0.001 seconds)
Test Case '-[MixDoctorTests.AudioImportServiceTests testDuplicateDetection_SameFileNameDifferentStage_ShouldAllowImport]' passed (0.001 seconds)
Test Case '-[MixDoctorTests.AudioImportServiceTests testDuplicateDetection_SameFileNameSameStage_ShouldBlockImport]' passed (0.001 seconds)
Test Case '-[MixDoctorTests.AudioImportServiceTests testMultipleImports_SameBaseDifferentStages_CreatesThreeSeparateFiles]' passed (0.001 seconds)

Test Suite 'AudioImportServiceTests' passed
     12 tests passed in 0.012 seconds
```

---

## Integration with CI/CD

### GitHub Actions Example
```yaml
- name: Run File Naming Tests
  run: |
    xcodebuild test \
      -scheme MixDoctor \
      -destination 'platform=iOS Simulator,name=iPhone 15' \
      -only-testing:MixDoctorTests/AudioImportServiceTests/testFileNaming_WithMixStage_AppendsCorrectSuffix \
      -only-testing:MixDoctorTests/AudioImportServiceTests/testFileNaming_WithStreamingMasterStage_AppendsCorrectSuffix \
      -only-testing:MixDoctorTests/AudioImportServiceTests/testFileNaming_WithCDMasterStage_AppendsCorrectSuffix
```

---

## Coverage

### Code Coverage
These tests cover:
- ✅ `copyToDocuments` filename generation logic
- ✅ Base name extraction in duplicate detection
- ✅ Stage display name conversion
- ✅ Duplicate detection comparison logic

### Feature Coverage
- ✅ File naming with stage suffix
- ✅ Multiple imports with different stages
- ✅ Duplicate prevention (same file + same stage)
- ✅ Edge cases (songs with " - " in title)

---

## Maintenance

### When to Update Tests

1. **New stage type added**:
   - Add test for stage display name conversion
   - Add test for filename generation
   - Update multiple imports test

2. **Filename format changes**:
   - Update all file naming tests
   - Update base name extraction tests

3. **Duplicate detection logic changes**:
   - Update duplicate detection tests
   - Verify edge cases still pass

4. **Bug fix**:
   - Add regression test to prevent bug from reoccurring

---

## Related Documentation
- [FILE_NAMING_WITH_STAGE.md](FILE_NAMING_WITH_STAGE.md) - Feature implementation details
- [AudioImportService.swift](MixDoctor/Core/Services/AudioImportService.swift) - Source code
