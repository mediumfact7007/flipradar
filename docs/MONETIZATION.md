# FlipRadar monetization plan

## Product principle

Monetization must not interrupt the core job: scan/search -> compare -> decide. Free users should understand why ads exist and what Pro removes.

## Free

- Core search and official source links
- Barcode scan
- Basic BUY MAX / ROI calculation
- Local flip tracking
- Calm banner/native ad placements only
- Optional rewarded ad can later grant temporary extra premium checks

## Pro — target 9.99 EUR/month

- No ads
- Unlimited live in-app checks
- Watchlists and price alerts
- Advanced market statistics / confidence
- Faster multi-source aggregation
- Saved search profiles

## Pro+ — target 19.99 EUR/month

- Everything in Pro
- Custom/partner source integrations
- Cross-border markets
- Advanced exports and analytics
- More alerts/search profiles

## Implementation path

1. Test APK: UI and plan preview only; no real payment.
2. Store test track: connect Google Play Billing / App Store products.
3. Optional RevenueCat layer to keep Android/iOS entitlements in sync.
4. AdMob: use test ads during development, then production ad units after consent/privacy setup.
5. Server-side entitlements for premium backend endpoints and expensive API calls.

## Ad placement policy

- Prefer adaptive banner/native placements on Home, Market result tails, and other natural low-attention areas.
- Never show a surprise interstitial while the user is scanning, entering a purchase price, or reading BUY MAX.
- Rewarded ads should always be optional and clearly state what the user receives.
- Pro/Pro+ removes advertising.

## Business metrics to track later

- activation: first completed price check
- source connection rate
- live-result success rate by source
- saved flip conversion
- 7/30-day retention
- free -> paywall view -> trial -> paid conversion
- ad revenue per active free user
- API/data cost per active user
- net contribution margin per plan
