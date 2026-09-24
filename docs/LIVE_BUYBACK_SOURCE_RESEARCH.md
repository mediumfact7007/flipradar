# LIVE buyback source research

Verified 2026-09-23. Goal: connect at least one permitted, real buyback-price source before further non-critical UI/alarm polish.

## Confirmed partner paths

- **Clevertronic**: official partner-program page explicitly targets comparison sites and pays for successful Ankauf referrals. The official page routes publishers to AWIN. This remains a strong contact/integration candidate because Flipwert is a comparison product. Clevertronic also publicly documents an existing CHECK24 handset-buyback partnership, which confirms that comparison-platform cooperation is a supported business model.
  - https://www.clevertronic.de/partnerprogramm
  - https://www.clevertronic.de/presse/check24
- **ZOXS**: official partner page offers separate Ankauf and Verkauf affiliate programs via ADCELL, tracking links, and explicitly states that partners receive access to an **Angebotsfeed** after signup. This is now the clearest documented feed path and should be the first source investigated after publisher approval. The public page does not document the feed schema or license terms, so Flipwert must inspect those only after approved access before consuming or republishing price fields.
  - https://www.zoxs.de/partnerprogramm6.html
- **mySWOOOP**: ADCELL program supports Ankauf referrals and exposes advertising assets/deep links; any product/price feed must only be used after publisher approval and according to its feed terms.
  - https://www.adcell.de/partnerprogramme/myswooop

## Important limitation

None of the public pages above documents an unauthenticated public API that Flipwert may safely call for live device buyback quotes. Affiliate/deep-link permission does **not** imply permission to scrape quote pages or republish prices. ZOXS now publicly confirms an affiliate Angebotsfeed exists, but public documentation does not establish that it contains Ankauf prices or permits price republication. Therefore Flipwert must not add a scraper or label these providers LIVE until an approved feed/API/partner endpoint and its permitted fields are verified.

## Integration order

1. **ZOXS first**: obtain ADCELL publisher approval, open the documented Angebotsfeed, and verify whether the Ankauf program feed contains product identifier/EAN, condition, current EUR Ankauf price, destination/deep link, update timestamp and explicit permission to display the price in a comparison product.
2. Clevertronic: request/obtain approved publisher access and ask specifically for product/Ankauf price feed or API/deep-link parameters; reference the comparison-site use case.
3. mySWOOOP: inspect approved ADCELL feed fields after publisher acceptance; use only fields licensed for publisher use.
4. Keep `BUYBACK_SOURCE_URL` server-side adapter as the boundary. Provider credentials/tokens must never ship in the APK.
5. Only emit a `BuybackOffer` when the source supplies a current EUR quote, exact/strong product match, explicit condition, HTTPS offer URL, and timestamp. Otherwise return no verified price.

## Provider-access checklist

Before wiring a provider into LIVE mode, record: feed/API owner, approval date, allowed use/republication scope, identifier fields, condition mapping, price semantics (fixed vs indicative), freshness/update field, deep-link/tracking rules, rate limits, and credential storage requirements. If any of these are unclear, keep the source disabled in LIVE mode. The server configuration then needs one per-provider approval record confirming feed access, price display, offer links and provider-identity display, with review/expiry timestamps and an internal agreement reference.

## Definition of the next data milestone

A release is a meaningful LIVE-buyback milestone only when a real product query reaches an approved provider source end-to-end and the app displays a current provider quote with provider, condition, checked-at time and direct offer action. A green build alone is not that milestone.
