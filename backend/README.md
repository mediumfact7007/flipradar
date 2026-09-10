# FlipRadar V0.4 live data sources

## eBay DE — official Browse API

The app can call `GET /api/market/ebay?q=...&marketplace=EBAY_DE` on the included Cloudflare Worker. The Worker keeps the eBay client secret out of the APK, obtains an application token with client credentials and queries the official Browse API. Numeric EAN/GTIN input is sent as `gtin`; text is sent as `q`.

Required Worker secrets:

- `EBAY_CLIENT_ID`
- `EBAY_CLIENT_SECRET`

After deployment, paste the Worker base URL into **FlipRadar > Setup > eBay DE Backend**.

Important: Browse API data represents current/active listings. Do not label it as sold history. eBay's Marketplace Insights sales-history API is limited/restricted, so V0.4 keeps sold-history separate instead of fabricating it.

## Amazon DE — Keepa

V0.4 supports an optional user-supplied Keepa API key directly on the test device. For EAN/UPC/ASIN inputs it queries Keepa with Amazon Germany domain id `3` and reads current Amazon/new/used price fields. Keepa is a paid/token-based third-party API.

For a production app, move the Keepa key server-side or use secure device storage and add rate limiting.

## MediaMarkt / SATURN

Both stores expose partner programs. Their official shop partner programs currently run through an EasyMarketing private network. V0.4 therefore provides live shop searches immediately and leaves automated price-feed ingestion behind a partner-feed adapter. Do not scrape their storefronts as the production data strategy.

Recommended production adapter contract:

`GET /api/market/retail?q=<term>&gtin=<ean>`

Normalize each permitted partner feed to: `source`, `title`, `gtin`, `price`, `shipping`, `availability`, `url`, `updatedAt`.

## Kleinanzeigen

V0.4 opens the real Kleinanzeigen search for the product. It intentionally does not use private or reverse-engineered marketplace APIs. If an official commercial/partner interface becomes available, add it behind the same normalized market adapter.

## idealo

V0.4 includes idealo as a one-tap new-price reference. A production automatic integration should use a licensed/partner data source rather than HTML scraping.
