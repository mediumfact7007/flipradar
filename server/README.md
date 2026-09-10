# FlipRadar API v0.6

This tiny Node.js service keeps marketplace credentials out of the mobile app and normalizes live price results for FlipRadar.

## What is live

- **eBay DE:** official eBay Browse API, active listings only. These are current offers, **not verified sold prices**.
- **Amazon DE:** Keepa Product API for ASIN / EAN / UPC lookups. Germany uses Keepa domain `3`. The adapter requests live offers.
- **Kleinanzeigen, MediaMarkt, SATURN, idealo, rebuy, Back Market:** remain official website searches until an approved API/feed/partner adapter is available.

## One-time deployment

Recommended simple route: deploy the `server` folder as a Node.js service (for example Railway). Start command:

```bash
node index.js
```

Set environment variables in the hosting dashboard, never in the Flutter app or Git:

```text
EBAY_CLIENT_ID=...
EBAY_CLIENT_SECRET=...
KEEPA_API_KEY=...
```

`PORT` is normally provided automatically by the host.

After deployment, open FlipRadar -> **Mehr -> Erweitert: FlipRadar-Server** and enter the HTTPS base URL, for example `https://your-service.example`.

## Endpoints

- `GET /health`
- `GET /v1/status`
- `GET /v1/market/search?source=ebay_de&q=iPhone%2015%20Pro`
- `GET /v1/market/search?source=amazon_de&q=<ASIN-or-EAN>`
- `GET /v1/market/search?source=all&q=...`

The response format is normalized to objects containing source, title, price, shipping, currency, condition, URL and a live flag.

## Third-party sources

Simple shops do not need backend code. They can be added from the app with a search template containing `{query}`.

Partners that want in-app prices can publish a FlipRadar source manifest with an HTTPS `adapter_url`. Their adapter should return either an `items` array or a JSON array with entries like:

```json
{
  "title": "Example product",
  "price": 199.99,
  "shipping": 4.99,
  "condition": "Used - Good",
  "url": "https://partner.example/item/123",
  "live": true
}
```

Keep adapters legally compliant with the source website/API terms. Do not put third-party secrets in manifests.
