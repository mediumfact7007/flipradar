# FlipRadar Buyback Comparison v1

## Product goal

FlipRadar should compare two different exit paths after a deal check:

1. **Private-market resale** — expected resale value based on trustworthy market evidence.
2. **Instant buyback** — current indicative purchase offers from buyback portals for the matched product and condition.

This turns a deal result into an actionable choice: higher expected margin with more selling effort versus a faster, simpler exit through a buyback provider.

## Normalized condition model

Providers use different condition vocabularies. FlipRadar must not compare provider prices until the provider-specific state has been mapped to a common condition.

Canonical states:

- `new_sealed` — new / factory sealed / OVP sealed
- `like_new` — no visible wear, fully functional
- `very_good` — light wear, fully functional
- `used_good` — normal visible wear, fully functional
- `acceptable` — heavier wear but functional
- `defective` — functional defect or provider-defined defective state

Every provider adapter owns its own mapping. If a provider condition cannot be mapped with sufficient confidence, the offer must be marked `condition_uncertain` and excluded from automatic best-offer claims.

## Normalized buyback offer

A backend/partner adapter should return normalized records such as:

```json
{
  "provider_id": "example-buyback",
  "provider_name": "Example Buyback",
  "product_id": "provider-product-id",
  "matched_title": "Apple iPhone 15 Pro 256 GB",
  "condition": "like_new",
  "price": 620.00,
  "currency": "EUR",
  "offer_url": "https://example.com/...",
  "checked_at": "2026-09-16T08:30:00+02:00",
  "price_kind": "indicative_buyback",
  "requires_inspection": true,
  "match_confidence": 0.98
}
```

Required fields: provider, matched product, normalized condition, price/currency, destination URL, timestamp and price kind.

## Trust rules

- Never mix asking prices, sold-market evidence and buyback offers into one unlabeled number.
- A buyback price is an **indicative exit price**, not guaranteed profit. Providers may inspect the item and revise/reject an offer.
- Display when the price was checked.
- Product identity must include relevant variants where available (storage, model generation, network/version, color only where price-relevant).
- Only compare offers with compatible normalized conditions.
- Low-confidence product matches must not participate in `best buyback` calculations.
- The server checks provider titles against query model, variant and storage before accepting provider-reported match confidence. Barcode-only searches require the provider to return a matching EAN/GTIN or product ID; ambiguous or broad searches yield no comparable price.
- Missing data is shown as unavailable, never estimated as if it were a live provider quote.
- A new search invalidates an in-flight buyback request and rechecks the selected condition for the new product, so a late response cannot be attached to another deal.
- Provider credentials, partner tokens and feed secrets stay server-side.

## Provider integration priority

Use, in order:

1. official API or documented partner API;
2. official affiliate/partner/product feed that permits price-comparison use;
3. explicit provider cooperation / FlipRadar adapter;
4. official search/deep link as a fallback without claiming an in-app live price.

Do not make fragile scraping a core dependency without an explicit technical/legal review.

Initial providers to investigate include reBuy, ZOXS and Clevertronic. They publicly operate condition-dependent electronics buyback flows; ZOXS and Clevertronic also advertise partner/affiliate programs. Availability of an affiliate program alone does **not** imply permission or an API for ingesting live buyback prices, so each integration must be verified separately before enabling live quotes.

## Deal-result UX

The result should eventually expose:

- `Private sale`: expected market value and estimated net margin.
- `Instant buyback`: highest eligible current indicative offer and estimated margin versus the user's purchase price.
- `Compare offers`: provider list, condition, checked time and important inspection caveat.

The primary deal verdict should remain understandable even if no buyback provider is available.

## Free / Pro direction

Do not lock the basic usefulness of a deal check behind Pro. A possible later split, to validate with real usage data:

- Free: private-market valuation plus existence/range of instant-buyback options.
- Pro: full provider comparison, condition-by-condition comparison, buyback price history, automatic rechecks and price alerts.

This is a product hypothesis, not a final paywall decision.

## Implementation phases

1. Add normalized buyback condition/offer models and fixtures independent of providers.
2. Add backend adapter contract and validation, including timestamps and confidence.
3. Implement one provider only after its permitted data-access path is verified.
4. Add the buyback block to deal results without changing existing market valuation semantics.
5. Add rechecks/history and then evaluate Pro gating.
