# MixDoctor Subscription Testing Guide

## ✅ What's Been Fixed

1. **Removed "Skip Trial" button** - Simplified to single "Subscribe Now" button
2. **Updated footer text** - Removed confusing trial messaging
3. **Clearer pricing display** - Shows actual cost per month/year
4. **50 analyses/month limit** - Updated throughout code and docs

---

## 🔧 Required Setup Before Testing

### Step 1: Configure Subscription Trial in App Store Connect

**Important**: Apple requires you to configure trial offers in App Store Connect, not in RevenueCat.

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Select **MixDoctor** app
3. Go to **Features → Subscriptions**
4. Click on **Pro Monthly** (`mixdoctor_pro_monthly`)

**Add Introductory Offer:**
- Click **Introductory Offers** section
- Click **+** to add offer
- **Type**: Free Trial
- **Duration**: 7 days (or choose: 3 days, 1 week, 2 weeks, 1 month, 2 months, 3 months, 6 months, 1 year)
- **Territories**: Select "All Territories" or specific countries
- Click **Save**

**Repeat for Pro Yearly** (`mixdoctor_pro_yearly`)

### Step 2: Attach Products to Entitlement in RevenueCat

1. Go to [RevenueCat Dashboard](https://app.revenuecat.com/)
2. Navigate to **Product catalog → Entitlements**
3. Click on **Pro** entitlement (or create it if missing)
4. Click **Attach Products**
5. Select both:
   - `mixdoctor_pro_monthly`
   - `mixdoctor_pro_yearly`
6. Click **Save**

### Step 3: Verify Offering Configuration

1. In RevenueCat Dashboard, go to **Offerings**
2. Click on **default** offering
3. Verify you see:
   - ✅ **Monthly** package → `mixdoctor_pro_monthly`
   - ✅ **Annual** package → `mixdoctor_pro_yearly`
4. Click the ⭐ icon to make it "Current" if not already

### Step 4: Upload App Store Connect API Key to RevenueCat

**This is REQUIRED for purchases to work!**

1. Go to App Store Connect → **Users and Access → Integrations → App Store Connect API**
2. You should see your key: **skillsy-sub** (Key ID: `45CS7R5K94`)
3. **If you have the .p8 file**:
   - Go to RevenueCat Dashboard → **Project Settings → Integrations**
   - Click **App Store**
   - Upload the .p8 file
   - Enter **Issuer ID**: `495f750e-fc78-487a-8c7f-ee4694be8d36`
   - Enter **Key ID**: `45CS7R5K94`
   - Click **Save**

4. **If you DON'T have the .p8 file** (you can only download once):
   - Create a new API key in App Store Connect
   - Download the new .p8 file immediately
   - Upload to RevenueCat

---

## 🧪 Testing Checklist

### Pre-Test Setup

- [ ] RevenueCat SDK added to Xcode (via Swift Package Manager)
- [ ] Products created in RevenueCat (monthly & yearly)
- [ ] Entitlement created and products attached
- [ ] Offering created with both packages
- [ ] App Store Connect API key uploaded to RevenueCat
- [ ] Build and run app on device or simulator

### Test 1: Free User Flow

1. **Fresh Install**
   - Delete app from device
   - Clean build folder in Xcode (`Cmd+Shift+K`)
   - Build and run

2. **Import 3 Tracks**
   - Import and analyze 3 audio files
   - **Expected**: All 3 analyses work
   - Check Settings → Should show "Free (X/3 analyses)"

3. **Trigger Paywall**
   - Try to analyze 4th track
   - **Expected**: Paywall appears
   - **If fails**: Check `ResultsView.swift` paywall integration

4. **Verify Paywall Content**
   - [ ] See "Upgrade to Pro" title
   - [ ] See both Monthly and Annual options
   - [ ] See prices displayed correctly
   - [ ] Annual option is pre-selected (best value)
   - [ ] "Subscribe Now" button is enabled
   - [ ] "Restore Purchases" button visible

### Test 2: Purchase Flow (Sandbox Testing)

**Setup Sandbox Tester:**
1. App Store Connect → **Users and Access → Sandbox Testers**
2. Create test account (e.g., `test@example.com`)
3. On your test device: **Settings → App Store → Sign Out**

**Test Purchase:**
1. Open MixDoctor app
2. Trigger paywall (try 4th analysis)
3. Select **Monthly** subscription
4. Click **"Subscribe Now"**
5. **Expected**: StoreKit purchase sheet appears
6. **If fails**: 
   - Check RevenueCat Dashboard logs
   - Verify API key is uploaded
   - Check Xcode console for errors

7. Sign in with sandbox tester account
8. Complete purchase
9. **Expected**: 
   - Paywall dismisses
   - Analysis completes
   - Settings shows "Pro (50/50 analyses)"

### Test 3: Trial Behavior (If Configured)

**Only if you added free trial in App Store Connect:**

1. Complete purchase flow
2. **During trial period**:
   - Settings should show "Trial (X/3 analyses)" OR "Pro (X/50)"
   - Check `SubscriptionService.swift` → `isInTrialPeriod`
   - Current code treats trial users as FREE tier (3 analyses)

3. **After trial ends**:
   - User should convert to paid Pro (50 analyses/month)
   - Automatic billing starts

### Test 4: Subscription Status

1. **After Purchase**:
   - Open Settings tab
   - **Expected**: Shows "Pro (50/50 analyses this month)"
   
2. **Perform Analyses**:
   - Analyze 5 tracks
   - Settings updates to "Pro (45/50 analyses this month)"

3. **Monthly Reset**:
   - Can't test immediately (wait 1 month)
   - Or manually change device date to next month
   - **Expected**: Resets to "Pro (50/50 analyses)"

### Test 5: Restore Purchases

1. Delete app
2. Reinstall app
3. Try to analyze 4th track (trigger paywall)
4. Click **"Restore Purchases"**
5. **Expected**: 
   - Subscription restored
   - Pro status activated
   - Paywall dismisses

### Test 6: Annual vs Monthly

1. Trigger paywall
2. Select **Annual** subscription
3. Verify:
   - Shows annual price (₪X.XX/year or $/year)
   - Shows monthly equivalent (₪X.XX/month)
   - "SAVE 25%" badge visible
4. Complete purchase
5. **Expected**: Same Pro features as monthly

---

## 🐛 Common Issues & Solutions

### Issue: "Failed to load subscription options"

**Causes:**
- RevenueCat offerings not configured
- No internet connection
- RevenueCat API key incorrect

**Solutions:**
1. Check RevenueCat Dashboard → Offerings → default is "Current"
2. Verify API key in `Config.swift` matches RevenueCat project
3. Check Xcode console for specific error

### Issue: "Purchase failed: User cancelled"

**Cause:** Normal behavior - user clicked "Cancel" on StoreKit sheet

**Solution:** No action needed - this is expected

### Issue: Paywall doesn't show both packages

**Causes:**
- Only one package configured in RevenueCat
- Products not attached to offering

**Solutions:**
1. RevenueCat Dashboard → Offerings → default
2. Verify both Monthly and Annual packages listed
3. Click each package → verify product is attached

### Issue: "Connection issue" in RevenueCat Dashboard

**Cause:** App Store Connect API key not uploaded

**Solution:**
1. Create/download .p8 key from App Store Connect
2. Upload to RevenueCat Dashboard → Integrations → App Store
3. Wait 5-10 minutes for sync

### Issue: Price shows as $0.00 or empty

**Causes:**
- StoreKit can't find products in App Store Connect
- Product IDs don't match exactly
- Not testing on real device (sandbox requires device)

**Solutions:**
1. Verify Product IDs match exactly:
   - App Store Connect: `mixdoctor_pro_monthly`
   - RevenueCat: `mixdoctor_pro_monthly`
   - Must be identical!
2. Test on real device, not simulator
3. Sign out of App Store and use sandbox tester

### Issue: Trial users get 50 analyses instead of 3

**Cause:** Code logic in `SubscriptionService.swift`

**Current Behavior:**
```swift
if proEntitlement.periodType == .trial {
    isInTrialPeriod = true
    isProUser = false // Treat trial users as free tier (3 analyses)
}
```

**To Change:** If you want trial users to get 50 analyses:
```swift
if proEntitlement.periodType == .trial {
    isInTrialPeriod = true
    isProUser = true // Trial users get Pro features (50 analyses)
}
```

---

## 📊 Expected Results Summary

| User Type | Analyses/Month | Cost | Resets |
|-----------|----------------|------|--------|
| **Free** | 3 | $0 | Monthly (1st of month) |
| **Trial** | 3 (or 50 if changed) | $0 | N/A (trial period only) |
| **Pro Monthly** | 50 | Depends on App Store price | Monthly from purchase date |
| **Pro Annual** | 50 | Depends on App Store price | Monthly from purchase date |

---

## 🎯 Final Validation

Before submitting to App Store:

- [ ] Test complete purchase flow with sandbox account
- [ ] Verify both monthly and annual work
- [ ] Test restore purchases works
- [ ] Check Settings shows correct subscription status
- [ ] Verify analysis limits work (free: 3, pro: 50)
- [ ] Test monthly reset (change device date)
- [ ] Screenshots of paywall for App Review
- [ ] Privacy policy URL added to app
- [ ] Terms of service URL added to app

---

## 📝 Notes

### Current Pricing

Update these prices in App Store Connect to match your actual pricing:

- **Monthly**: Set your price (e.g., $7.99 USD or ₪29.90 ILS)
- **Annual**: Set your price (e.g., $71.88 USD or equivalent)

### Trial Configuration

If you add a free trial:
- RevenueCat automatically handles trial logic
- Apple manages trial eligibility (one per user per subscription)
- Cancellations during trial = no charge

### Important Files

- **SubscriptionService.swift**: Main subscription logic
- **PaywallView.swift**: Paywall UI
- **Config.swift**: RevenueCat API key
- **ResultsView.swift**: Paywall trigger logic

---

**Questions or issues?** Check RevenueCat Dashboard → Charts to see:
- Active subscriptions
- Trial conversions
- Revenue
- Errors/failures
