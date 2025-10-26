//
//  TESTING_GUIDE.md
//  MixDoctor
//
//  Guide for testing RevenueCat integration
//

# Testing RevenueCat Integration

## 🚀 Quick Test (No App Store Connect Required)

I've created mock services that simulate the full subscription flow. This lets you test the entire user experience immediately!

### Files Created:
1. `MockSubscriptionService.swift` - Simulates subscription state
2. `MockPaywallView.swift` - Full paywall UI with mock purchases

### To Test Now:

#### 1. Update ResultsView to use Mock

In `ResultsView.swift`, temporarily change:
```swift
@State private var subscriptionService = SubscriptionService.shared
```
to:
```swift
@State private var mockService = MockSubscriptionService.shared
```

And update the analysis check from:
```swift
if !subscriptionService.canPerformAnalysis() {
    showPaywall = true
    return
}
```
to:
```swift
if !mockService.canPerformAnalysis() {
    showPaywall = true
    return
}
```

And show MockPaywallView instead:
```swift
.sheet(isPresented: $showPaywall) {
    MockPaywallView {
        // Refresh after purchase
    }
}
```

#### 2. Update SettingsView to use Mock

In `SettingsView.swift`, change:
```swift
@State private var subscriptionService = SubscriptionService.shared
```
to:
```swift
@State private var mockService = MockSubscriptionService.shared
```

Update all references accordingly.

### What You Can Test:

✅ **Free Tier Limits**
- Run 5 analyses (watch counter decrease)
- Hit the limit and see paywall
- See "4 remaining", "3 remaining", etc.

✅ **Paywall Display**
- Beautiful gradient UI
- Feature list with icons
- Monthly vs Annual packages
- Price display
- "SAVE 20%" badge on annual

✅ **Purchase Flow**
- Select package (monthly/annual)
- Click "Start Free Trial"
- See loading spinner
- 90% success rate (simulated)
- Auto-dismiss on success

✅ **Restore Purchases**
- Click "Restore Purchases"
- 50% chance to find purchase (simulated)
- Updates status

✅ **Subscription Status**
- Settings shows "Free (X/5 analyses)"
- After purchase: "Pro"
- Checkmark badge for pro users

✅ **Reset Testing**
- Use "Reset to Free User" button in mock paywall
- Test flow multiple times

### Testing Checklist:

```
[ ] Launch app and go to Import view
[ ] Import an audio file
[ ] Click "Analyze Mix"
[ ] See analysis count: "Free (4/5 remaining)"
[ ] Analyze 4 more times until limit hit
[ ] See paywall appear automatically
[ ] Review paywall design and features
[ ] Select monthly package
[ ] Click "Start Free Trial"
[ ] See loading state
[ ] Confirm purchase completes
[ ] See "Pro" status in Settings
[ ] Try another analysis (should work unlimited)
[ ] Test "Restore Purchases" button
[ ] Test "Reset to Free User" to test again
```

---

## 🍎 Full Test (With App Store Connect)

Once you create products in App Store Connect, switch back to real services:

### 1. Remove Custom Entitlement Computation Package

Open Xcode:
1. Select MixDoctor project
2. Select MixDoctor target
3. Go to "Frameworks, Libraries, and Embedded Content"
4. Remove `RevenueCat_CustomEntitlementComputation`
5. Keep only `RevenueCat` and `RevenueCatUI`

### 2. Create Products in App Store Connect

Follow `APP_STORE_CONNECT_SETUP.md` to create:
- `mixdoctor_pro_monthly` - $19.99/month
- `mixdoctor_pro_annual` - $191.88/year

### 3. Create Sandbox Tester

App Store Connect → Users and Access → Sandbox → Testers

### 4. Switch Back to Real Services

Change all `MockSubscriptionService.shared` back to `SubscriptionService.shared`
Change all `MockPaywallView` back to `PaywallView`

### 5. Test on Device

1. Sign out of App Store on device
2. Settings → App Store → Sandbox Account → Sign in
3. Run app from Xcode
4. Trigger paywall
5. Complete purchase (no real money!)

---

## 💡 Pro Tips

### Mock Testing Advantages:
- ✅ Test instantly (no waiting)
- ✅ No App Store Connect setup needed
- ✅ Test edge cases easily
- ✅ Predictable behavior
- ✅ Can reset state anytime
- ✅ No network delays

### When to Use Real RevenueCat:
- 🔄 When you need to test actual App Store integration
- 🔄 Before submitting to App Review
- 🔄 To verify products are configured correctly
- 🔄 To test receipt validation
- 🔄 To test subscription renewals

### Best Practice Workflow:
1. **Week 1**: Use mock services to perfect UI/UX
2. **Week 2**: Set up App Store Connect
3. **Week 3**: Test with sandbox
4. **Week 4**: Submit for review

---

## 🐛 Troubleshooting

### Mock service not working?
- Check that you changed ALL references from `SubscriptionService` to `MockSubscriptionService`
- Check that you're using `MockPaywallView` not `PaywallView`

### Purchase not completing in mock?
- It has a 90% success rate by design
- Try again (simulates real-world failures)
- Or modify `mockPurchase` to always return `true`

### Want to test error states?
- Modify `mockPurchase` to return `false` sometimes
- Great for testing error handling!

---

## 📊 Current Status

✅ Mock services created and ready
✅ Real RevenueCat backend configured
✅ Products defined in RevenueCat
⏳ Products need creation in App Store Connect
⏳ Sandbox testing pending

**You can start testing RIGHT NOW with the mock services!** 🎉
