# App Store Connect Setup Guide

## Current Status
❌ **Products not created in App Store Connect yet**

The error you're seeing is expected - RevenueCat is trying to fetch products from Apple, but they don't exist yet.

## Required Steps

### 1. Create App in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **Apps** → **+** (Add App)
3. Fill in details:
   - **Platform**: iOS
   - **Name**: MixDoctor
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: `com.yevgenylevin.animated.MixDoctor`
   - **SKU**: `mixdoctor-001` (or any unique identifier)
   - **User Access**: Full Access

### 2. Create In-App Purchases

Go to your app → **Monetization** → **Subscriptions** → **+** (Create Subscription Group)

#### Create Subscription Group
- **Reference Name**: MixDoctor Pro Subscriptions
- **Display Name**: MixDoctor Pro

#### Create Monthly Subscription
1. Click **+** in the subscription group
2. **Product ID**: `mixdoctor_pro_monthly` ⚠️ MUST MATCH EXACTLY
3. **Reference Name**: MixDoctor Pro Monthly
4. **Subscription Duration**: 1 Month
5. **Price**: Select $19.99/month
6. **Localizations**:
   - **Display Name**: MixDoctor Pro
   - **Description**: Unlimited audio analysis with advanced AI-powered insights

#### Create Annual Subscription
1. Click **+** in the subscription group
2. **Product ID**: `mixdoctor_pro_annual` ⚠️ MUST MATCH EXACTLY
3. **Reference Name**: MixDoctor Pro Annual
4. **Subscription Duration**: 1 Year
5. **Price**: Select $191.88/year (or closest to $192)
6. **Localizations**:
   - **Display Name**: MixDoctor Pro (Annual)
   - **Description**: Unlimited audio analysis with advanced AI-powered insights. Save 20% with annual billing!

### 3. Add App Review Information

For each subscription, add:
- **Screenshot**: Take a screenshot of your paywall
- **Review Notes**: "This subscription unlocks unlimited audio analysis features"

### 4. Submit for Review

⚠️ **Important**: Subscriptions must be approved by Apple before they work in production.

However, they will work **immediately in Sandbox** for testing!

### 5. Create Sandbox Tester Account

1. Go to App Store Connect → **Users and Access** → **Sandbox** → **Testers**
2. Click **+** to add tester
3. Fill in:
   - **First Name**: Test
   - **Last Name**: User
   - **Email**: Create a NEW email (not used for Apple ID)
   - **Password**: Create strong password
   - **App Store Territory**: United States

### 6. Test on Device

1. On your iPhone:
   - Settings → App Store → Sandbox Account
   - Sign in with sandbox tester email

2. Run MixDoctor from Xcode

3. Trigger the paywall (try to analyze more than 5 tracks)

4. Complete purchase with sandbox account
   - It will say "Environment: Sandbox"
   - No real money charged
   - Purchase completes immediately

## Product IDs Created in RevenueCat

These MUST match exactly in App Store Connect:

```
mixdoctor_pro_monthly  → $20.00/month
mixdoctor_pro_annual   → $192.00/year ($16.00/month)
```

## Troubleshooting

### "Cannot connect to App Store"
- Products not created yet in App Store Connect
- Product IDs don't match exactly
- Subscription status is "Draft" (needs to be "Ready to Submit")

### "This product is not available"
- Product not approved yet (use sandbox account)
- Wrong product ID in code
- Bundle ID mismatch

### "Purchase failed"
- Not signed in with sandbox account
- Sandbox account not created properly
- Using production Apple ID instead of sandbox

## Next Steps After Setup

1. ✅ Create products in App Store Connect
2. ✅ Create sandbox tester account
3. ✅ Test purchase flow
4. ✅ Verify subscription grants "pro" entitlement
5. ✅ Test restore purchases
6. ✅ Test subscription expiration (sandbox expires quickly)
7. Submit app for review when ready

## Important Notes

- **Sandbox subscriptions expire quickly** (5 minutes for 1 month, 1 hour for 1 year)
- **Renewals happen automatically** (up to 6 times in sandbox)
- **Can test all scenarios** without real money
- **Products must be "Ready to Submit"** to work in sandbox
- **App Review required** for production

## Current RevenueCat Configuration

✅ Project ID: `projaaea241b`
✅ App ID: `appa9f457a2bd`
✅ API Key: `appl_qdVVvPCyMxWWSjogkPdkKribRUK`
✅ Entitlement: `pro`
✅ Offering: `default`
✅ Products: 2 (monthly + annual)
✅ Packages: 2 configured

Everything is ready on the RevenueCat side - just needs App Store Connect setup!
