# Claude API Token Usage and Cost Analysis

## Overview

This document provides detailed information about token usage and associated costs for the MixDoctor audio analysis feature powered by Anthropic's Claude models.

⚠️ **IMPORTANT:** This app uses **Claude API**, not OpenAI. Previous versions of this document incorrectly referenced OpenAI pricing.

⚠️ **CRITICAL UPDATE (Dec 25, 2025):** Free users get **3 total analyses (lifetime)**, not 3 per month. This dramatically reduces free tier costs.

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

**Total Input:** ~**1,000 tokens per analysis** (includes system prompt)

---

### Output Tokens (Received from Claude API)

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

**Total Output:** ~**400 tokens per analysis**

**Average tokens per analysis:** ~**1,400 tokens** (1,000 input + 400 output)

---

## Cost Analysis

### 🎯 Current Model Configuration (from ClaudeAPIService.swift)

```swift
private func determineModel(isProUser: Bool) -> String {
    return isProUser ? "claude-sonnet-4-5-20250929" : "claude-haiku-4-5-20251001"
}
```

- **Free Users:** `claude-haiku-4-5-20251001` (fastest, cheapest)
- **Pro Users:** `claude-sonnet-4-5-20250929` (smartest, more expensive)
- **Trial Users:** `claude-sonnet-4-5-20250929` (premium experience)

---

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

## Cost Projections

### Free Tier (3 Analyses TOTAL - Lifetime Limit)

| User Type     | Analyses | Model             | Cost/User (Lifetime) |
| ------------- | -------- | ----------------- | -------------------- |
| **Free User** | 3        | Claude Haiku 4.5  | **$0.009**           |

✅ **Free tier cost is negligible:** Each free user costs less than **1 cent** for their lifetime usage.

### Trial Period (3-Day Trial with Sonnet Access)

| User Type      | Analyses | Model             | Cost/User |
| -------------- | -------- | ----------------- | --------- |
| **Trial User** | 3        | Claude Sonnet 4.5 | **$0.027** |

⚠️ Note: Trial users also have a 3-analysis limit but use the premium Sonnet model.

### Pro Users (Monthly Subscription)

| Usage Level          | Analyses/Month | Model             | Cost/User/Month |
| -------------------- | -------------- | ----------------- | --------------- |
| **Pro (Light)**      | 20             | Claude Sonnet 4.5 | $0.18           |
| **Pro (Moderate)**   | 50 (limit)     | Claude Sonnet 4.5 | $0.45           |
| **Pro (Heavy)**      | 100            | Claude Sonnet 4.5 | $0.90           |
| **Pro (Power User)** | 200            | Claude Sonnet 4.5 | $1.80           |

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

- **Free tier cost is negligible:** $0.009/user **lifetime** (3 total analyses with Claude Haiku 4.5)
- **Trial period cost is minimal:** $0.027/user for 3 analyses with Claude Sonnet 4.5
- **Pro users are highly profitable:** 50 analyses/month costs only $0.45 vs $5.99 revenue
- **Break-even point is very high:** Users would need 665+ analyses/month to exceed subscription revenue
- **Free tier has no ongoing cost:** Once a user exhausts their 3 analyses, they cost $0

### ✅ Sustainable Pricing

Your current pricing structure ($5.99/month or $47.88/year) provides:

- **Strong profit margins** for typical users (20-50 analyses/month)
- **Sustainable costs** even for power users (200-500 analyses/month)
- **Low financial risk** from the free tier and trial period

### ⚠️ Edge Cases

- **Extreme users (500+ analyses/month on annual plan):** May operate at a slight loss, but this is rare
- **Mitigation:** Consider implementing soft limits or tier upgrades for extreme usage patterns

---

## 🛡️ Budget Protection Strategies

### Current Safeguards ✅

1. **Hard Limits Enforced:**
   - Free users: 3 analyses lifetime (enforced in `SubscriptionService.swift`)
   - Pro users: 50 analyses/month (enforced server-side)
   - These limits **prevent runaway API costs**

2. **Model Segregation:**
   - Free tier uses cheaper Haiku model ($0.003/analysis)
   - Pro tier uses premium Sonnet model ($0.009/analysis)

3. **No Auto-Retry:** Failed analyses don't automatically retry, preventing cost loops

### Recommended Additional Safeguards

#### 🚨 HIGH PRIORITY: Monthly Budget Alerts

Implement budget monitoring in your Claude API dashboard:

```swift
// Pseudocode for monthly budget tracking
class BudgetMonitor {
    let monthlyBudgetLimit = 1000.0  // $1,000/month
    let alertThreshold = 0.8         // Alert at 80%
    
    func checkBudgetBeforeAnalysis() async throws {
        let currentSpend = await fetchMonthlySpend()
        if currentSpend > monthlyBudgetLimit {
            throw APIError.budgetExceeded
        }
        if currentSpend > monthlyBudgetLimit * alertThreshold {
            await sendAlertToAdmin()
        }
    }
}
```

#### 🔧 Recommended Implementation Steps:

1. **Set Claude API Budget Cap:**
   - Go to Anthropic Console → Billing → Budget Limits
   - Set monthly limit (e.g., $1,000)
   - Enable email alerts at 50%, 75%, 90%

2. **Add Server-Side Cost Tracking:**
   - Log each API call cost to database
   - Daily cron job to calculate running total
   - Disable API calls if budget exceeded

3. **Implement Rate Limiting:**
   ```swift
   // Prevent abuse: max 10 analyses per user per day
   private let dailyAnalysisLimit = 10
   private let dailyAnalysisKey = "dailyAnalysisCount_"
   ```

4. **Add Emergency Kill Switch:**
   ```swift
   // Remote config flag to disable all AI analysis
   if RemoteConfig.shared.isAIAnalysisDisabled {
       throw APIError.serviceTemporarilyDisabled
   }
   ```

---

## Cost Optimization Opportunities

1. ✅ **Model Selection (IMPLEMENTED):** Using Claude Haiku 4.5 for free tier saves 67% vs Sonnet
2. ⏳ **Prompt Caching (NOT YET IMPLEMENTED):** Could save 90% on input tokens (~$0.0027 per cached request)
   - Currently disabled in code: `// DISABLED CACHING - use fresh prompt every time`
   - Re-enable to save ~$0.006 per analysis
3. **Response Format:** Limiting recommendations to 3 (instead of 5) could save ~100 output tokens
4. **Batch Processing:** For non-urgent analyses, use Claude's batch API for 50% cost savings

---

## 💰 What You Need to Budget

### Realistic Monthly Cost Scenarios

Assuming the following user distribution:

| User Type        | Count | Analyses Each | Model          | Cost Each | **Total Cost** |
| ---------------- | ----- | ------------- | -------------- | --------- | -------------- |
| Free (lifetime)  | 1,000 | 3 (one-time)  | Haiku 4.5      | $0.009    | **$9.00**      |
| Trial (3 days)   | 100   | 3             | Sonnet 4.5     | $0.027    | **$2.70**      |
| Pro (light)      | 50    | 20/month      | Sonnet 4.5     | $0.18     | **$9.00**      |
| Pro (moderate)   | 20    | 50/month      | Sonnet 4.5     | $0.45     | **$9.00**      |
| **MONTHLY TOTAL**|       |               |                |           | **~$30/month** |

### Monthly Budget Recommendation

- **Conservative budget:** $100/month (covers 3x growth)
- **Comfortable budget:** $250/month (covers 8x growth + spikes)
- **Safe budget:** $500/month (covers 16x growth)

### Revenue vs Cost (Healthy Margins)

With 70 paying Pro users at $5.99/month:

- **Revenue:** 70 × $5.99 = **$419.30/month**
- **Claude API Cost:** ~$18.00/month (for Pro users only)
- **Profit Margin:** **95.7%** 🎉

**Conclusion:** Even with just 70 paid subscribers, you're highly profitable. The 3-analysis lifetime limit for free users means they're essentially a one-time $0.009 cost.

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

December 25, 2025 (Complete reanalysis with accurate free tier limits)

## Pricing Source

Claude API pricing as of November 2025:

- https://www.anthropic.com/pricing
- https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching

## Related Documents

- **Comprehensive Analysis:** `.docs/CLAUDE_API_COST_ANALYSIS.md`
- **Implementation:** `MixDoctor/Core/Services/ClaudeAPIService.swift`
