# CoreML Implementation Plan for MixDoctor

## Overview
Transform rule-based audio analysis into machine learning-powered analysis using CoreML.

## Phase 1: Training Data Generation (Python)

### Option A: Synthetic Training Data (Quick Start)
Generate synthetic training data based on audio engineering principles:
- 1000+ samples with known quality labels
- Feature vectors: stereo width, phase correlation, frequency balance, dynamic range
- Labels: quality scores 0-100

### Option B: Real Audio Dataset (Production)
Collect real audio files with quality annotations:
- Professional mixes (90-100 score)
- Amateur mixes (40-70 score)
- Problematic mixes (0-40 score)

## Phase 2: Model Training

### Models to Train:

1. **Stereo Width Quality Classifier**
   - Input: stereoWidth, correlation, leftRightBalance, midSideRatio
   - Output: classification (tooNarrow, good, tooWide) + confidence

2. **Phase Problem Detector**
   - Input: correlation, midSideRatio, leftRightBalance
   - Output: hasIssue (bool) + severity (none/moderate/severe) + confidence

3. **Frequency Balance Analyzer**
   - Input: bassRatio, lowMidRatio, midRatio, highMidRatio, highRatio
   - Output: balanceScore (0-100) + issue categories

4. **Overall Quality Predictor**
   - Input: All features combined
   - Output: overallScore (0-100) + confidence

### Training Options:

**Option 1: Create ML (macOS app - Easiest)**
- Drag & drop CSV with features
- Automatic model training
- Export .mlmodel directly

**Option 2: Python (scikit-learn + coremltools)**
```python
from sklearn.ensemble import RandomForestClassifier
import coremltools as ct

# Train model
model = RandomForestClassifier()
model.fit(X_train, y_train)

# Convert to CoreML
coreml_model = ct.converters.sklearn.convert(model)
coreml_model.save('StereoWidthModel.mlmodel')
```

**Option 3: Python (TensorFlow/PyTorch + coremltools)**
For more complex models with better accuracy

## Phase 3: Integration into MixDoctor

### File Structure:
```
Features/Analysis/CoreML/
├── Models/
│   ├── StereoWidthClassifier.swift (updated)
│   ├── PhaseProblemDetector.swift (updated)
│   ├── FrequencyBalanceAnalyzer.swift (updated)
│   └── OverallQualityPredictor.swift (new)
├── MLModels/
│   ├── StereoWidthModel.mlmodel
│   ├── PhaseProblemModel.mlmodel
│   ├── FrequencyBalanceModel.mlmodel
│   └── OverallQualityModel.mlmodel
└── Training/
    ├── generate_training_data.py
    ├── train_models.py
    └── requirements.txt
```

## Phase 4: Implementation Steps

### Step 1: Create Training Data Generator
### Step 2: Train Models
### Step 3: Add .mlmodel files to Xcode
### Step 4: Update Swift classifier classes
### Step 5: Add fallback logic
### Step 6: Test and validate

## Timeline

- **Quick Demo (2 hours)**: Synthetic data + simple models
- **Production Ready (2-3 days)**: Real data collection + robust models
- **Advanced ML (1-2 weeks)**: Neural networks + extensive training

## Current Implementation Plan

I'll implement a **hybrid approach**:
1. ✅ Keep rule-based analysis as fallback
2. ✅ Add CoreML model support with graceful fallback
3. ✅ Create synthetic training data generator
4. ✅ Train basic models for demonstration
5. ✅ Integrate models into existing analyzers

This way, the app works NOW with rules, but can use ML when models are available!
