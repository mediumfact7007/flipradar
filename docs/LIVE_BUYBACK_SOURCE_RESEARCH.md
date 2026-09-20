# LIVE buyback source research

Verified 2026-09-20. Goal: connect at least one permitted, real buyback-price source before further non-critical UI/alarm polish.

## Confirmed partner paths

- **Clevertronic**: official partner-program page explicitly targets comparison sites and pays for successful Ankauf referrals. The official page routes publishers to AWIN. This is the strongest first contact/integration candidate because FlipRadar is a comparison product.
  - https://www.clevertronic.de/partnerprogramm
- **ZOXS**: official partner page offers a dedicated Ankauf affiliate program via ADCELL, tracking links, and invites individual cooperation via B2B contact.
  - https://www.zoxs.de/partnerprogramm6.html
- **mySWOOOP**: ADCELL program supports Ankauf referrals and exposes advertising assets/deep links; any product/price feed must only be used after publisher approval and according to its feed terms.
  - https://www.adcell.de/partnerprogramme/myswooop

## Important limitation

None of the public pages above documents an unauthenticated public API that FlipRadar may safely call for live device buyback quotes. Affiliate/deep-link permission does **not** imply permission to scrape quote pages or republish prices. Therefore FlipRadar must not add a scraper or label these providers LIVE until an approved feed/API/partner endpoint is available.

## Integration order

1. Clevertronic: request/obtain approved publisher access and ask specifically for product/Ankauf price feed or API/deep-link parameters.
2. ZOXS: same, using its official partner/B2B route.
3. mySWOOOP: inspect approved ADCELL feed fields after publisher acceptance; use only fields licensed for publisher use.
4. Keep `BUYBACK_SOURCE_URL` server-side adapter as the boundary. Provider credentials/tokens must never ship in the APK.
5. Only emit a `BuybackOffer` when the source supplies a current EUR quote, exact/strong product match, explicit condition, HTTPS offer URL, and timestamp. Otherwise return no verified price.

## Definition of the next data milestone

A release is a meaningful LIVE-buyback milestone only when a real product query reaches an approved provider source end-to-end and the app displays a current provider quote with provider, condition, checked-at time and direct offer action. A green build alone is not that milestone.
