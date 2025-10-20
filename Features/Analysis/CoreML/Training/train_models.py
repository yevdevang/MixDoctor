#!/usr/bin/env python3
"""
Train CoreML models for MixDoctor using scikit-learn and coremltools
Requires: pandas, numpy, scikit-learn, coremltools
Install: pip install pandas numpy scikit-learn coremltools
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, mean_squared_error, classification_report
import coremltools as ct
from coremltools.models import MLModel

def train_stereo_width_model():
    """Train and export Stereo Width Classification model"""
    print("\n" + "="*60)
    print("Training Stereo Width Classification Model")
    print("="*60)
    
    # Load data
    data = pd.read_csv('stereo_width_training_data.csv')
    print(f"Loaded {len(data)} samples")
    
    # Prepare features and labels
    feature_names = ['stereoWidth', 'correlation', 'leftRightBalance', 'midSideRatio']
    X = data[feature_names]
    y = data['classification']
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    
    # Train model
    print("Training Random Forest Classifier...")
    model = RandomForestClassifier(
        n_estimators=100,
        max_depth=10,
        random_state=42
    )
    model.fit(X_train, y_train)
    
    # Evaluate
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    print(f"Test Accuracy: {accuracy:.3f}")
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred, 
                                target_names=['TooNarrow', 'Good', 'TooWide']))
    
    # Convert to CoreML
    print("\nConverting to CoreML...")
    coreml_model = ct.converters.sklearn.convert(
        model,
        input_features=feature_names,
        output_feature_names='classification'
    )
    
    # Set model metadata
    coreml_model.author = 'MixDoctor'
    coreml_model.license = 'MIT'
    coreml_model.short_description = 'Classifies stereo width as too narrow, good, or too wide'
    coreml_model.input_description['stereoWidth'] = 'Stereo width (0-1)'
    coreml_model.input_description['correlation'] = 'Phase correlation (-1 to 1)'
    coreml_model.input_description['leftRightBalance'] = 'L/R balance (-1 to 1)'
    coreml_model.input_description['midSideRatio'] = 'Mid/Side energy ratio'
    
    # Save model
    output_path = '../MLModels/StereoWidthModel.mlmodel'
    coreml_model.save(output_path)
    print(f"✅ Model saved to {output_path}")
    
    return coreml_model


def train_phase_problem_model():
    """Train and export Phase Problem Detection model"""
    print("\n" + "="*60)
    print("Training Phase Problem Detection Model")
    print("="*60)
    
    # Load data
    data = pd.read_csv('phase_problem_training_data.csv')
    print(f"Loaded {len(data)} samples")
    
    # Prepare features and labels
    feature_names = ['correlation', 'midSideRatio', 'stereoWidth']
    X = data[feature_names]
    y = data['severity']  # 0=none, 1=moderate, 2=severe
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    
    # Train model
    print("Training Random Forest Classifier...")
    model = RandomForestClassifier(
        n_estimators=100,
        max_depth=10,
        random_state=42
    )
    model.fit(X_train, y_train)
    
    # Evaluate
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    print(f"Test Accuracy: {accuracy:.3f}")
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred,
                                target_names=['None', 'Moderate', 'Severe']))
    
    # Convert to CoreML
    print("\nConverting to CoreML...")
    coreml_model = ct.converters.sklearn.convert(
        model,
        input_features=feature_names,
        output_feature_names='severity'
    )
    
    # Set model metadata
    coreml_model.author = 'MixDoctor'
    coreml_model.license = 'MIT'
    coreml_model.short_description = 'Detects phase problems in stereo audio'
    coreml_model.input_description['correlation'] = 'Phase correlation (-1 to 1)'
    coreml_model.input_description['midSideRatio'] = 'Mid/Side energy ratio'
    coreml_model.input_description['stereoWidth'] = 'Stereo width (0-1)'
    
    # Save model
    output_path = '../MLModels/PhaseProblemModel.mlmodel'
    coreml_model.save(output_path)
    print(f"✅ Model saved to {output_path}")
    
    return coreml_model


def train_frequency_balance_model():
    """Train and export Frequency Balance Analysis model"""
    print("\n" + "="*60)
    print("Training Frequency Balance Analysis Model")
    print("="*60)
    
    # Load data
    data = pd.read_csv('frequency_balance_training_data.csv')
    print(f"Loaded {len(data)} samples")
    
    # Prepare features and labels
    feature_names = ['bassRatio', 'lowMidRatio', 'midRatio', 'highMidRatio', 'highRatio']
    X = data[feature_names]
    y = data['balanceScore']
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    
    # Train model
    print("Training Random Forest Regressor...")
    model = RandomForestRegressor(
        n_estimators=100,
        max_depth=15,
        random_state=42
    )
    model.fit(X_train, y_train)
    
    # Evaluate
    y_pred = model.predict(X_test)
    rmse = np.sqrt(mean_squared_error(y_test, y_pred))
    print(f"Test RMSE: {rmse:.3f}")
    print(f"Mean Absolute Error: {np.mean(np.abs(y_test - y_pred)):.3f}")
    
    # Convert to CoreML
    print("\nConverting to CoreML...")
    coreml_model = ct.converters.sklearn.convert(
        model,
        input_features=feature_names,
        output_feature_names='balanceScore'
    )
    
    # Set model metadata
    coreml_model.author = 'MixDoctor'
    coreml_model.license = 'MIT'
    coreml_model.short_description = 'Predicts frequency balance score (0-100)'
    coreml_model.input_description['bassRatio'] = 'Bass frequency ratio (0-1)'
    coreml_model.input_description['lowMidRatio'] = 'Low-mid frequency ratio (0-1)'
    coreml_model.input_description['midRatio'] = 'Mid frequency ratio (0-1)'
    coreml_model.input_description['highMidRatio'] = 'High-mid frequency ratio (0-1)'
    coreml_model.input_description['highRatio'] = 'High frequency ratio (0-1)'
    
    # Save model
    output_path = '../MLModels/FrequencyBalanceModel.mlmodel'
    coreml_model.save(output_path)
    print(f"✅ Model saved to {output_path}")
    
    return coreml_model


def train_overall_quality_model():
    """Train and export Overall Quality Prediction model"""
    print("\n" + "="*60)
    print("Training Overall Quality Prediction Model")
    print("="*60)
    
    # Load data
    data = pd.read_csv('overall_quality_training_data.csv')
    print(f"Loaded {len(data)} samples")
    
    # Prepare features and labels
    feature_names = [
        'stereoWidth', 'correlation', 'dynamicRange', 'peakLevel',
        'bassRatio', 'lowMidRatio', 'midRatio', 'highMidRatio', 'highRatio'
    ]
    X = data[feature_names]
    y = data['overallScore']
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    
    # Train model
    print("Training Random Forest Regressor...")
    model = RandomForestRegressor(
        n_estimators=150,
        max_depth=20,
        min_samples_split=5,
        random_state=42
    )
    model.fit(X_train, y_train)
    
    # Evaluate
    y_pred = model.predict(X_test)
    rmse = np.sqrt(mean_squared_error(y_test, y_pred))
    print(f"Test RMSE: {rmse:.3f}")
    print(f"Mean Absolute Error: {np.mean(np.abs(y_test - y_pred)):.3f}")
    
    # Feature importance
    feature_importance = pd.DataFrame({
        'feature': feature_names,
        'importance': model.feature_importances_
    }).sort_values('importance', ascending=False)
    print("\nFeature Importance:")
    print(feature_importance.to_string(index=False))
    
    # Convert to CoreML
    print("\nConverting to CoreML...")
    coreml_model = ct.converters.sklearn.convert(
        model,
        input_features=feature_names,
        output_feature_names='overallScore'
    )
    
    # Set model metadata
    coreml_model.author = 'MixDoctor'
    coreml_model.license = 'MIT'
    coreml_model.short_description = 'Predicts overall mix quality score (0-100)'
    
    # Save model
    output_path = '../MLModels/OverallQualityModel.mlmodel'
    coreml_model.save(output_path)
    print(f"✅ Model saved to {output_path}")
    
    return coreml_model


def main():
    """Train all models"""
    print("="*60)
    print("MixDoctor CoreML Model Training")
    print("="*60)
    print("\nThis will train 4 ML models for audio analysis:")
    print("1. Stereo Width Classification")
    print("2. Phase Problem Detection")
    print("3. Frequency Balance Analysis")
    print("4. Overall Quality Prediction")
    
    # Create MLModels directory
    import os
    os.makedirs('../MLModels', exist_ok=True)
    
    try:
        # Train all models
        train_stereo_width_model()
        train_phase_problem_model()
        train_frequency_balance_model()
        train_overall_quality_model()
        
        print("\n" + "="*60)
        print("✅ ALL MODELS TRAINED SUCCESSFULLY!")
        print("="*60)
        print("\nNext steps:")
        print("1. Drag the .mlmodel files from Features/Analysis/CoreML/MLModels/ into Xcode")
        print("2. Xcode will automatically generate Swift classes")
        print("3. Update the analyzer classes to use the ML models")
        print("4. Build and test!")
        
    except Exception as e:
        print(f"\n❌ Error during training: {e}")
        print("\nMake sure you have installed required packages:")
        print("pip install pandas numpy scikit-learn coremltools")


if __name__ == '__main__':
    main()
