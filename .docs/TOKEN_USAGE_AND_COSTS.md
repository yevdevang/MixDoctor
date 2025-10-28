# OpenAI Token Usage and Cost Analysis

## Overview

This document provides detailed information about token usage and associated costs for the MixDoctor audio analysis feature powered by OpenAI's GPT models.

---

## Token Usage Per Analysis

### Input Tokens (Sent to OpenAI)

**System Message:** ~250 tokens
```
You are an expert audio engineer and mixing specialist...
[Full system prompt with all instructions and analysis guidelines]
```

**User Message:** ~150-200 tokens (varies based on audio metrics)
```json
{
  "stereoWidth": 65.2,
  "phaseCoherence": 0.89,
  "frequencyBalance": {
    "low": 28.5,
    "mid": 45.2,
    "high": 26.3
  },
  "dynamicRange": 8.7,
  "loudness": {
    "lufs": -14.2,
    "peak": -0.3,
    "truePeak": -0.1
  }
}
```

**Total Input:** ~**400-450 tokens per analysis**

---

### Output Tokens (Received from OpenAI)

The response structure contains:
```json
{
  "overallScore": 85,
  "summary": "Your mix demonstrates...",  // ~50-100 tokens
  "stereoAnalysis": "...",                 // ~80-120 tokens
  "frequencyAnalysis": "...",              // ~80-120 tokens
  "dynamicsAnalysis": "...",               // ~80-120 tokens
  "effectsAnalysis": "...",                // ~80-120 tokens
  "recommendations": [                     // ~200-300 tokens (3-5 items)
    "Recommendation 1...",
    "Recommendation 2...",
    "Recommendation 3...",
    "Recommendation 4...",
    "Recommendation 5..."
  ]
}
```

**Total Output:** ~**570-880 tokens per analysis**

**Average tokens per analysis:** ~**1,250 tokens** (450 input + 800 output)

---

## Cost Analysis

### GPT-4o Pricing (Pro Users & Trial)

- **Input:** $2.50 per 1M tokens
- **Output:** $10.00 per 1M tokens

**Per analysis cost:**
- Input: 450 tokens × $2.50 / 1,000,000 = **$0.001125**
- Output: 800 tokens × $10.00 / 1,000,000 = **$0.008**
- **Total: ~$0.009 per analysis** (less than 1 cent)

### GPT-4o-mini Pricing (Free Users)

- **Input:** $0.15 per 1M tokens
- **Output:** $0.60 per 1M tokens

**Per analysis cost:**
- Input: 450 tokens × $0.15 / 1,000,000 = **$0.0000675**
- Output: 800 tokens × $0.60 / 1,000,000 = **$0.00048**
- **Total: ~$0.00055 per analysis** (negligible)

---

## Monthly Cost Projections

| User Type | Analyses/Month | Model | Cost/User/Month |
|-----------|----------------|-------|-----------------|
| **Free User** | 3 | GPT-4o-mini | $0.0016 |
| **Trial User** | 3 | GPT-4o | $0.027 |
| **Pro (Light Usage)** | 20 | GPT-4o | $0.18 |
| **Pro (Moderate)** | 50 | GPT-4o | $0.45 |
| **Pro (Heavy)** | 100 | GPT-4o | $0.90 |
| **Pro (Power User)** | 500 | GPT-4o | $4.50 |

---

## Revenue vs. Cost Analysis

### Monthly Subscription ($5.99/month)

| Usage Level | Analyses | API Cost | **Profit** | Break-even Point |
|-------------|----------|----------|------------|------------------|
| Light | 20 | $0.18 | **$5.81** | 665 analyses |
| Moderate | 50 | $0.45 | **$5.54** | - |
| Heavy | 100 | $0.90 | **$5.09** | - |
| Power | 200 | $1.80 | **$4.19** | - |
| Extreme | 500 | $4.50 | **$1.49** | - |

### Annual Subscription ($47.88/year = $3.99/month)

| Usage Level | Analyses | API Cost | **Profit/Month** | Break-even Point |
|-------------|----------|----------|------------------|------------------|
| Light | 20 | $0.18 | **$3.81** | 443 analyses |
| Moderate | 50 | $0.45 | **$3.54** | - |
| Heavy | 100 | $0.90 | **$3.09** | - |
| Power | 200 | $1.80 | **$2.19** | - |
| Extreme | 500 | $4.50 | **-$0.51** ⚠️ | - |

---

## Key Insights

### ✅ Healthy Margins

- **Free tier cost is negligible:** $0.0016/user/month (3 analyses with GPT-4o-mini)
- **Trial period cost is minimal:** $0.027/user for 3 analyses with GPT-4o
- **Pro users are profitable:** Even heavy users (100+ analyses) remain highly profitable
- **Break-even point is very high:** Users would need to perform 443-665 analyses/month to exceed subscription revenue

### ✅ Sustainable Pricing

Your current pricing structure ($5.99/month or $47.88/year) provides:
- **Strong profit margins** for typical users (20-50 analyses/month)
- **Sustainable costs** even for power users (200-500 analyses/month)
- **Low financial risk** from the free tier and trial period

### ⚠️ Edge Cases

- **Extreme users (500+ analyses/month on annual plan):** May operate at a slight loss, but this is rare
- **Mitigation:** Consider implementing soft limits or tier upgrades for extreme usage patterns

---

## Cost Optimization Opportunities

1. **Prompt Optimization:** Reducing system prompt verbosity could save ~50-100 input tokens per request
2. **Response Format:** Limiting recommendation count to 3 (instead of 5) could save ~50-100 output tokens
3. **Caching:** OpenAI's prompt caching could reduce input token costs by 50% for repeated system messages
4. **Model Selection:** Continue using GPT-4o-mini for free tier to minimize costs

---

## Implementation Details

- **Service:** `OpenAIService.swift`
- **Free tier model:** `gpt-4o-mini`
- **Pro/Trial model:** `gpt-4o`
- **API endpoint:** `https://api.openai.com/v1/chat/completions`
- **Temperature:** 0.7 (balanced creativity/consistency)
- **Max tokens:** 1000 (output limit)

---

## Last Updated

October 28, 2025

## Pricing Source

OpenAI API pricing as of October 2025:
- https://openai.com/api/pricing/
