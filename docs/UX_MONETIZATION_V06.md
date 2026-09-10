# FlipRadar V0.6 — UX, retention and monetization strategy

## Product rule

The core job is sacred: **scan/search -> compare -> decide**. Ads or paywalls must never cover the scanner, delay a price check, hide BUY MAX, or interrupt the user while entering a purchase price.

## Beginner-first UX

- One dominant action on Home: barcode scan, with search as the alternative.
- Plain-language decision signal: **KAUFEN / VERHANDELN / LASSEN**.
- BUY MAX explained as the maximum purchase price for the user's ROI target.
- Price Sources are not a permanent bottom-navigation item; they live behind a simple source status card and in More.
- Recent searches support one-tap repeat checks.
- Watchlist stores the user's target buy price so a deal can be rechecked without rebuilding the calculation.
- Advanced backend/API configuration is hidden under an Advanced section.
- Every source says either `Direkt live in FlipRadar` or `Offizielle Website-Suche`; never imply simulated data is live.

## Retention loops

1. **Recent checks** — one-tap recheck from Home.
2. **Watchlist** — save interesting products with BUY MAX.
3. **Price alerts** — later server-side Pro feature; notify only when a meaningful threshold is crossed.
4. **Flip tracker** — Bought -> Listed -> Sold with profit/ROI.
5. **Useful notification, not spam** — no generic daily push just to increase opens.

## Ad inventory without damaging the core experience

### FREE

- One native-style sponsored placement on Home after useful content.
- One native-style placement after the deal result/source section, never above the verdict or BUY MAX.
- One compact sponsored strip in long watchlists only after several organic items.
- Later: optional rewarded ad for an explicit bonus such as a limited extra premium market check.
- Later: app-open ad only if real usage frequency supports it, with strict frequency capping and never on the user's first session.

### PRO / PRO+

- No advertising.

### Never do

- No surprise interstitial while scanning.
- No interstitial between Search and Result.
- No ad covering BUY MAX or the decision signal.
- No fake system dialogs or misleading ad labels.
- No excessive ad density that makes sponsored content look like organic marketplace results.

## Premium timing

Do not hard-block the first useful result. Let a new user reach the first clear price decision quickly. Present Premium after value has been demonstrated — for example when the user saves multiple watches, requests automatic alerts, wants advanced market history, or reaches a reasonable live-check allowance.

Test pricing and packaging rather than assuming one paywall wins everywhere. Keep FREE genuinely useful so it can support referrals, retention and ad revenue.

## Candidate plans

### FREE
- Core checks and official source searches
- Barcode scanning
- Basic BUY MAX / ROI
- Local flip tracking
- Watchlist with manual recheck
- Calm ad placements

### PRO — target 9.99 EUR/month
- Ad-free
- Higher/unlimited live-check allowance subject to API economics
- Automatic price alerts
- Advanced market confidence/history
- Saved search profiles

### PRO+ — target 19.99 EUR/month
- Everything in Pro
- Custom/partner source integrations
- Cross-border markets
- Advanced exports/analytics
- Higher alert/profile limits

## Metrics that actually matter

Track together, not in isolation:

- first useful price check completion
- time-to-first-result
- live source success rate
- search -> watch conversion
- watch -> recheck rate
- saved flip and sold flip rate
- D1 / D7 / D30 retention
- ad impressions per active FREE user
- ad revenue per active FREE user
- FREE -> paywall -> trial -> paid conversion
- paid churn
- marketplace/API cost per active user
- net contribution margin per plan

The optimization target is not maximum ad impressions. It is maximum **long-term contribution per retained user**.
