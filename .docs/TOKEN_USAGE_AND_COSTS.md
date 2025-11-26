# Claude API Token Usage and Cost Analysis

## Overview

This document provides detailed information about token usage and associated costs for the MixDoctor audio analysis feature powered by Anthropic's Claude models.

⚠️ **IMPORTANT:** This app uses **Claude API**, not OpenAI. Previous versions of this document incorrectly referenced OpenAI pricing.

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
  "summary": "Your mix demonstrates...", // ~50-100 tokens
  "stereoAnalysis": "...", // ~80-120 tokens
  "frequencyAnalysis": "...", // ~80-120 tokens
  "dynamicsAnalysis": "...", // ~80-120 tokens
  "effectsAnalysis": "...", // ~80-120 tokens
  "recommendations": [
    // ~200-300 tokens (3-5 items)
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

### Claude Sonnet 4.5 Pricing (Pro Users & Trial)

- **Input:** $3.00 per 1M tokens
- **Output:** $15.00 per 1M tokens
- **Prompt Caching (Write):** $3.75 per 1M tokens
- **Prompt Caching (Read):** $0.30 per 1M tokens

**Per analysis cost (without caching):**

- Input: 1,000 tokens × $3.00 / 1,000,000 = **$0.003**
- Output: 400 tokens × $15.00 / 1,000,000 = **$0.006**
- **Total: ~$0.009 per analysis** (less than 1 cent)

**Per analysis cost (with prompt caching after first request):**

- Cached Input: 1,000 tokens × $0.30 / 1,000,000 = **$0.0003**
- Output: 400 tokens × $15.00 / 1,000,000 = **$0.006**
- **Total: ~$0.0063 per analysis** (30% savings)

### Claude Haiku 4.5 Pricing (Free Users)

- **Input:** $1.00 per 1M tokens
- **Output:** $5.00 per 1M tokens
- **Prompt Caching (Write):** $1.25 per 1M tokens
- **Prompt Caching (Read):** $0.10 per 1M tokens

**Per analysis cost (without caching):**

- Input: 1,000 tokens × $1.00 / 1,000,000 = **$0.001**
- Output: 400 tokens × $5.00 / 1,000,000 = **$0.002**
- **Total: ~$0.003 per analysis** (negligible)

---

## Monthly Cost Projections

| User Type             | Analyses/Month | Model             | Cost/User/Month |
| --------------------- | -------------- | ----------------- | --------------- |
| **Free User**         | 3              | Claude Haiku 4.5  | $0.009          |
| **Trial User**        | 3              | Claude Sonnet 4.5 | $0.027          |
| **Pro (Light Usage)** | 20             | Claude Sonnet 4.5 | $0.18           |
| **Pro (Moderate)**    | 50             | Claude Sonnet 4.5 | $0.45           |
| **Pro (Heavy)**       | 100            | Claude Sonnet 4.5 | $0.90           |
| **Pro (Power User)**  | 500            | Claude Sonnet 4.5 | $4.50           |

---

## Revenue vs. Cost Analysis

### Monthly Subscription ($5.99/month)

| Usage Level | Analyses | API Cost | **Profit** | Break-even Point |
| ----------- | -------- | -------- | ---------- | ---------------- |
| Light       | 20       | $0.18    | **$5.81**  | 665 analyses     |
| Moderate    | 50       | $0.45    | **$5.54**  | -                |
| Heavy       | 100      | $0.90    | **$5.09**  | -                |
| Power       | 200      | $1.80    | **$4.19**  | -                |
| Extreme     | 500      | $4.50    | **$1.49**  | -                |

### Annual Subscription ($47.88/year = $3.99/month)

| Usage Level | Analyses | API Cost | **Profit/Month** | Break-even Point |
| ----------- | -------- | -------- | ---------------- | ---------------- |
| Light       | 20       | $0.18    | **$3.81**        | 443 analyses     |
| Moderate    | 50       | $0.45    | **$3.54**        | -                |
| Heavy       | 100      | $0.90    | **$3.09**        | -                |
| Power       | 200      | $1.80    | **$2.19**        | -                |
| Extreme     | 500      | $4.50    | **-$0.51** ⚠️    | -                |

---

## Key Insights

### ✅ Healthy Margins

- **Free tier cost is negligible:** $0.009/user/month (3 analyses with Claude Haiku 4.5)
- **Trial period cost is minimal:** $0.027/user for 3 analyses with Claude Sonnet 4.5
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

1. **Prompt Caching (HIGH PRIORITY):** Implement Claude's prompt caching to save 90% on input tokens (~$0.0027 per cached request)
2. **Prompt Optimization:** Reducing system prompt from ~1,000 to ~700 tokens could save ~30% on input costs
3. **Response Format:** Limiting recommendation count to 3 (instead of 5) could save ~100 output tokens
4. **Model Selection:** Continue using Claude Haiku 4.5 for free tier to minimize costs
5. **Batch Processing:** For non-urgent analyses, use Claude's batch API for 50% cost savings

---

## Implementation Details

- **Service:** `ClaudeAPIService.swift`
- **Free tier model:** `claude-haiku-4-5-20251001`
- **Pro/Trial model:** `claude-sonnet-4-5-20250929`
- **API endpoint:** `https://api.anthropic.com/v1/messages`
- **API version:** `2023-06-01`
- **Max tokens:** 1000 (output limit)
- **Prompt caching:** Not yet implemented (recommended)

---

## Last Updated

November 26, 2025

## Pricing Source

Claude API pricing as of November 2025:

- https://www.anthropic.com/pricing
- https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching

## Related Documents

- **Comprehensive Analysis:** `.docs/CLAUDE_API_COST_ANALYSIS.md`
- **Implementation:** `MixDoctor/Core/Services/ClaudeAPIService.swift`
