#!/usr/bin/env python3
"""
Generate synthetic training data for MixDoctor CoreML models
Based on audio engineering best practices and rules
"""

import pandas as pd
import numpy as np
from typing import List, Dict, Tuple

def generate_stereo_width_data(n_samples: int = 1000) -> pd.DataFrame:
    """
    Generate training data for stereo width classification
    
    Features:
    - stereoWidth: 0-1 (narrow to wide)
    - correlation: -1 to 1 (out of phase to in phase)
    - leftRightBalance: -1 to 1 (left heavy to right heavy)
    - midSideRatio: 0+ (mid to side energy ratio)
    
    Labels:
    - classification: 0=tooNarrow, 1=good, 2=tooWide
    - confidence: 0-1
    """
    data = []
    
    for _ in range(n_samples):
        # Generate features with realistic distributions
        stereo_width = np.random.beta(5, 5)  # Bell curve around 0.5
        correlation = np.random.normal(0.7, 0.2)  # High correlation typical
        correlation = np.clip(correlation, -1, 1)
        left_right_balance = np.random.normal(0, 0.1)  # Mostly centered
        left_right_balance = np.clip(left_right_balance, -1, 1)
        mid_side_ratio = np.random.gamma(2, 2)  # Skewed distribution
        
        # Determine classification based on audio engineering rules
        if stereo_width < 0.3:
            classification = 0  # too narrow
            confidence = 0.7 + np.random.random() * 0.25
        elif stereo_width > 0.7:
            classification = 2  # too wide
            confidence = 0.7 + np.random.random() * 0.25
        else:
            classification = 1  # good
            confidence = 0.8 + np.random.random() * 0.2
        
        # Add some noise/uncertainty to make it realistic
        if 0.28 < stereo_width < 0.32 or 0.68 < stereo_width < 0.72:
            confidence *= 0.7  # Less confident near boundaries
        
        data.append({
            'stereoWidth': stereo_width,
            'correlation': correlation,
            'leftRightBalance': left_right_balance,
            'midSideRatio': mid_side_ratio,
            'classification': classification,
            'confidence': confidence
        })
    
    return pd.DataFrame(data)


def generate_phase_problem_data(n_samples: int = 1000) -> pd.DataFrame:
    """
    Generate training data for phase problem detection
    
    Features:
    - correlation: -1 to 1
    - midSideRatio: 0+
    - stereoWidth: 0-1
    
    Labels:
    - hasIssue: 0 or 1
    - severity: 0=none, 1=moderate, 2=severe
    - confidence: 0-1
    """
    data = []
    
    for _ in range(n_samples):
        correlation = np.random.normal(0.5, 0.4)
        correlation = np.clip(correlation, -1, 1)
        mid_side_ratio = np.random.gamma(2, 2)
        stereo_width = np.random.beta(5, 5)
        
        # Determine issues based on correlation
        if correlation < 0.3:
            has_issue = 1
            if correlation < 0:
                severity = 2  # severe
                confidence = 0.85 + np.random.random() * 0.15
            else:
                severity = 1  # moderate
                confidence = 0.7 + np.random.random() * 0.25
        else:
            has_issue = 0
            severity = 0  # none
            confidence = 0.85 + np.random.random() * 0.15
        
        # Less confident near boundaries
        if 0.25 < correlation < 0.35:
            confidence *= 0.75
        
        data.append({
            'correlation': correlation,
            'midSideRatio': mid_side_ratio,
            'stereoWidth': stereo_width,
            'hasIssue': has_issue,
            'severity': severity,
            'confidence': confidence
        })
    
    return pd.DataFrame(data)


def generate_frequency_balance_data(n_samples: int = 1000) -> pd.DataFrame:
    """
    Generate training data for frequency balance analysis
    
    Features:
    - bassRatio: 0-1
    - lowMidRatio: 0-1
    - midRatio: 0-1
    - highMidRatio: 0-1
    - highRatio: 0-1
    
    Labels:
    - balanceScore: 0-100
    - hasIssue: 0 or 1
    """
    data = []
    
    # Ideal ratios (from audio engineering)
    ideal_bass = 0.25
    ideal_low_mid = 0.15
    ideal_mid = 0.30
    ideal_high_mid = 0.18
    ideal_high = 0.12
    
    for _ in range(n_samples):
        # Generate ratios that sum to ~1
        ratios = np.random.dirichlet([5, 3, 6, 4, 2.5])
        bass_ratio = ratios[0]
        low_mid_ratio = ratios[1]
        mid_ratio = ratios[2]
        high_mid_ratio = ratios[3]
        high_ratio = ratios[4]
        
        # Calculate deviation from ideal
        deviations = [
            abs(bass_ratio - ideal_bass),
            abs(low_mid_ratio - ideal_low_mid),
            abs(mid_ratio - ideal_mid),
            abs(high_mid_ratio - ideal_high_mid),
            abs(high_ratio - ideal_high)
        ]
        
        avg_deviation = np.mean(deviations)
        max_deviation = np.max(deviations)
        
        # Score based on deviation (less deviation = higher score)
        balance_score = 100 * (1 - min(avg_deviation * 3, 1))
        balance_score += np.random.normal(0, 5)  # Add noise
        balance_score = np.clip(balance_score, 0, 100)
        
        # Has issue if any band deviates significantly
        has_issue = 1 if max_deviation > 0.15 else 0
        
        data.append({
            'bassRatio': bass_ratio,
            'lowMidRatio': low_mid_ratio,
            'midRatio': mid_ratio,
            'highMidRatio': high_mid_ratio,
            'highRatio': high_ratio,
            'balanceScore': balance_score,
            'hasIssue': has_issue
        })
    
    return pd.DataFrame(data)


def generate_overall_quality_data(n_samples: int = 1000) -> pd.DataFrame:
    """
    Generate training data for overall quality prediction
    Combines all features for holistic assessment
    """
    data = []
    
    for _ in range(n_samples):
        # Generate all features
        stereo_width = np.random.beta(5, 5)
        correlation = np.random.normal(0.7, 0.2)
        correlation = np.clip(correlation, -1, 1)
        dynamic_range = np.random.normal(12, 4)
        dynamic_range = np.clip(dynamic_range, 2, 25)
        peak_level = np.random.normal(-3, 2)
        peak_level = np.clip(peak_level, -20, 0)
        
        # Frequency ratios
        ratios = np.random.dirichlet([5, 3, 6, 4, 2.5])
        
        # Calculate quality score based on multiple factors
        score = 100.0
        
        # Stereo width penalty
        if stereo_width < 0.3 or stereo_width > 0.7:
            score -= 15
        
        # Phase penalty
        if correlation < 0:
            score -= 30
        elif correlation < 0.3:
            score -= 15
        
        # Dynamic range penalty
        if dynamic_range < 6 or dynamic_range > 18:
            score -= 10
        
        # Peak level penalty
        if peak_level > -1:
            score -= 10
        
        # Frequency balance penalty
        ideal_ratios = np.array([0.25, 0.15, 0.30, 0.18, 0.12])
        freq_deviation = np.mean(np.abs(ratios - ideal_ratios))
        score -= freq_deviation * 50
        
        # Add noise
        score += np.random.normal(0, 3)
        score = np.clip(score, 0, 100)
        
        data.append({
            'stereoWidth': stereo_width,
            'correlation': correlation,
            'dynamicRange': dynamic_range,
            'peakLevel': peak_level,
            'bassRatio': ratios[0],
            'lowMidRatio': ratios[1],
            'midRatio': ratios[2],
            'highMidRatio': ratios[3],
            'highRatio': ratios[4],
            'overallScore': score
        })
    
    return pd.DataFrame(data)


def main():
    """Generate all training datasets"""
    print("Generating training data for MixDoctor CoreML models...")
    
    # Generate datasets
    print("\n1. Stereo Width Classification...")
    stereo_data = generate_stereo_width_data(2000)
    stereo_data.to_csv('stereo_width_training_data.csv', index=False)
    print(f"   Generated {len(stereo_data)} samples")
    print(f"   Class distribution: {stereo_data['classification'].value_counts().to_dict()}")
    
    print("\n2. Phase Problem Detection...")
    phase_data = generate_phase_problem_data(2000)
    phase_data.to_csv('phase_problem_training_data.csv', index=False)
    print(f"   Generated {len(phase_data)} samples")
    print(f"   Issue distribution: {phase_data['hasIssue'].value_counts().to_dict()}")
    
    print("\n3. Frequency Balance Analysis...")
    freq_data = generate_frequency_balance_data(2000)
    freq_data.to_csv('frequency_balance_training_data.csv', index=False)
    print(f"   Generated {len(freq_data)} samples")
    print(f"   Mean balance score: {freq_data['balanceScore'].mean():.2f}")
    
    print("\n4. Overall Quality Prediction...")
    quality_data = generate_overall_quality_data(2000)
    quality_data.to_csv('overall_quality_training_data.csv', index=False)
    print(f"   Generated {len(quality_data)} samples")
    print(f"   Mean quality score: {quality_data['overallScore'].mean():.2f}")
    
    print("\n✅ Training data generation complete!")
    print("\nNext steps:")
    print("1. Review the CSV files")
    print("2. Run train_models.py to create CoreML models")
    print("3. Add .mlmodel files to Xcode project")


if __name__ == '__main__':
    main()
