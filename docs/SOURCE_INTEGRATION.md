# FlipRadar Source Integration v1

FlipRadar supports two source types so normal users and third-party partners can add price sources without changing the mobile app.

## 1) Search-link source — easiest

A source only needs a name and an official search URL containing `{query}`.

Example:

```json
{
  "id": "example-shop",
  "name": "Example Shop",
  "subtitle": "Official shop search",
  "search_url": "https://example.com/search?q={query}",
  "color": "5746E8"
}
```

The app replaces `{query}` with the URL-encoded product name/EAN/ASIN and opens the official site.

## 2) Live in-app adapter — for partners/developers

Add `adapter_url` when the source can return normalized live price data.

```json
{
  "id": "example-shop",
  "name": "Example Shop",
  "subtitle": "Live prices in FlipRadar",
  "search_url": "https://example.com/search?q={query}",
  "adapter_url": "https://adapter.example.com/search?q={query}",
  "color": "5746E8"
}
```

The adapter endpoint must return either an array of items or an object with an `items` array.

```json
{
  "items": [
    {
      "title": "Product title",
      "price": 399.99,
      "shipping": 4.99,
      "url": "https://example.com/product/123",
      "condition": "New"
    }
  ]
}
```

Required fields per item: `title`, `price`, `url`.
Optional: `shipping`, `condition`.

## Security and marketplace rules

- Keep private API credentials on the adapter/backend. Never put private secrets in a manifest or mobile app.
- Prefer official APIs, affiliate feeds, partner feeds, public product feeds, or explicit permission from the source.
- A search-link integration is the safe fallback when a direct price API is not available.
- Each source should identify whether a result is an asking price, retailer price, buyback price, or verified sold price. FlipRadar should not treat them as equivalent.

## Partner onboarding

A partner can host the JSON manifest at a stable HTTPS URL and give that URL to a FlipRadar user. The user opens Sources > Add your own source > Manifest link. No app update is needed.

## Future registry

A hosted FlipRadar source registry can later list approved partner manifests. The mobile app can download that registry so new shops become available remotely after review.
