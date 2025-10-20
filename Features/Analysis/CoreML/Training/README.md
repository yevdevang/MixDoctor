# CoreML Model Training for MixDoctor

This directory contains Python scripts to generate training data and train CoreML models for audio analysis.

## Quick Start

### 1. Install Dependencies

```bash
cd Features/Analysis/CoreML/Training
python3 -m pip install -r requirements.txt
```

### 2. Generate Training Data

```bash
python3 generate_training_data.py
```

This creates 4 CSV files with synthetic training data:
- `stereo_width_training_data.csv` (2000 samples)
- `phase_problem_training_data.csv` (2000 samples)
- `frequency_balance_training_data.csv` (2000 samples)
- `overall_quality_training_data.csv` (2000 samples)

### 3. Train Models

```bash
python3 train_models.py
```

This trains 4 Random Forest models and converts them to CoreML format:
- `StereoWidthModel.mlmodel` - Classifies stereo width
- `PhaseProblemModel.mlmodel` - Detects phase issues
- `FrequencyBalanceModel.mlmodel` - Scores frequency balance
- `OverallQualityModel.mlmodel` - Predicts overall quality

### 4. Add Models to Xcode

1. Open Xcode
2. Drag the `.mlmodel` files from `../MLModels/` into your project
3. Xcode will automatically generate Swift wrapper classes
4. Update the analyzer classes to use the models (see below)

## Model Details

### 1. Stereo Width Classifier
**Input Features:**
- `stereoWidth` (Float): 0-1, narrow to wide
- `correlation` (Float): -1 to 1, phase relationship
- `leftRightBalance` (Float): -1 to 1, L/R balance
- `midSideRatio` (Float): Mid/side energy ratio

**Output:**
- `classification` (Int64): 0=tooNarrow, 1=good, 2=tooWide

**Usage in Swift:**
```swift
let input = StereoWidthModelInput(
    stereoWidth: Double(features.stereoWidth),
    correlation: Double(features.correlation),
    leftRightBalance: Double(features.leftRightBalance),
    midSideRatio: Double(features.midSideRatio)
)
let prediction = try model.prediction(input: input)
let classification = prediction.classification
```

### 2. Phase Problem Detector
**Input Features:**
- `correlation` (Float): -1 to 1
- `midSideRatio` (Float)
- `stereoWidth` (Float): 0-1

**Output:**
- `severity` (Int64): 0=none, 1=moderate, 2=severe

### 3. Frequency Balance Analyzer
**Input Features:**
- `bassRatio` (Float): 0-1
- `lowMidRatio` (Float): 0-1
- `midRatio` (Float): 0-1
- `highMidRatio` (Float): 0-1
- `highRatio` (Float): 0-1

**Output:**
- `balanceScore` (Double): 0-100

### 4. Overall Quality Predictor
**Input Features:**
- All stereo + frequency features
- `dynamicRange` (Float)
- `peakLevel` (Float)

**Output:**
- `overallScore` (Double): 0-100

## Updating Swift Analyzers

After adding models to Xcode, update the analyzer classes:

### StereoWidthClassifier.swift
```swift
import CoreML

final class StereoWidthClassifier {
    private let model: StereoWidthModel?
    
    init() {
        self.model = try? StereoWidthModel(configuration: MLModelConfiguration())
    }
    
    func classify(features: AudioFeatureExtractor.StereoFeatures) -> StereoWidthResult {
        // Try ML model first
        if let model = model {
            do {
                let input = StereoWidthModelInput(
                    stereoWidth: Double(features.stereoWidth),
                    correlation: Double(features.correlation),
                    leftRightBalance: Double(features.leftRightBalance),
                    midSideRatio: Double(features.midSideRatio)
                )
                let prediction = try model.prediction(input: input)
                
                let classification: Classification
                switch prediction.classification {
                case 0: classification = .tooNarrow
                case 2: classification = .tooWide
                default: classification = .good
                }
                
                return StereoWidthResult(
                    classification: classification,
                    confidence: 0.9,
                    recommendation: getRecommendation(for: classification)
                )
            } catch {
                print("ML model failed, using fallback: \\(error)")
            }
        }
        
        // Fallback to rule-based (existing code)
        let width = features.stereoWidth
        if width < Constants.Analysis.stereoWidthNarrow {
            return StereoWidthResult(classification: .tooNarrow, confidence: 0.8, ...)
        }
        // ... rest of fallback logic
    }
}
```

## Training with Real Data

To train with real audio files instead of synthetic data:

1. Collect audio files with quality labels
2. Extract features using AudioFeatureExtractor
3. Save to CSV with same format as synthetic data
4. Run train_models.py with your data

Example feature extraction:
```swift
// In Swift
let features = featureExtractor.extractAllFeatures(audioFile)
// Export to CSV
```

## Advanced Training

For better models:
1. **Collect more data** (10,000+ samples)
2. **Use real audio files** with expert quality ratings
3. **Try different algorithms** (XGBoost, Neural Networks)
4. **Hyperparameter tuning** (GridSearchCV)
5. **Cross-validation** for robust evaluation

## Troubleshooting

**Import errors:** Make sure coremltools is installed:
```bash
pip install --upgrade coremltools
```

**Model not loading in Swift:**
- Check the model is added to the correct target
- Clean build folder (Cmd+Shift+K)
- Check model name matches class name

**Low accuracy:**
- Generate more training data
- Adjust feature thresholds in generate_training_data.py
- Use real audio data instead of synthetic

## Files Generated

```
Training/
├── generate_training_data.py   # Generates synthetic data
├── train_models.py              # Trains and exports models
├── requirements.txt             # Python dependencies
├── README.md                    # This file
├── *.csv                        # Training data (generated)
└── ../MLModels/
    ├── StereoWidthModel.mlmodel
    ├── PhaseProblemModel.mlmodel
    ├── FrequencyBalanceModel.mlmodel
    └── OverallQualityModel.mlmodel
```

## Next Steps

1. ✅ Generate training data
2. ✅ Train models
3. ⬜ Add .mlmodel files to Xcode
4. ⬜ Update Swift analyzer classes
5. ⬜ Test with real audio files
6. ⬜ Collect real data for production models
7. ⬜ Retrain with real data
