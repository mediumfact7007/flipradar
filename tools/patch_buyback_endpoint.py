#!/usr/bin/env python3
"""Add the isolated /v1/buyback/search API route without touching market search."""
from pathlib import Path

PATH = Path("server/index.js")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count == 0 and new in text:
        print(f"{label}: already applied")
        return text
    if count != 1:
        raise SystemExit(f"{label}: expected one anchor, found {count}; refusing to write")
    print(f"{label}: applied")
    return text.replace(old, new, 1)


def main() -> None:
    original = PATH.read_text(encoding="utf-8")
    updated = original

    updated = replace_once(
        updated,
        "const { resolvePublicListing } = require('./listing_resolver');\n",
        "const { resolvePublicListing } = require('./listing_resolver');\nconst { fetchBuybackOffers, sourceStatus: buybackSourceStatus } = require('./buyback_source');\n",
        "buyback-import",
    )

    updated = replace_once(
        updated,
        "    idealo: { configured: false, mode: 'official_search_link' },\n",
        "    idealo: { configured: false, mode: 'official_search_link' },\n    buyback: buybackSourceStatus(),\n",
        "buyback-status",
    )

    anchor = "    if (req.method === 'GET' && url.pathname === '/v1/market/search') {\n"
    route = """    if (req.method === 'GET' && url.pathname === '/v1/buyback/search') {
      pruneRateBuckets();
      if (!allowRequest(req)) {
        return json(res, 429, { error: 'rate_limit', items: [], best: null });
      }

      const q = normalizeQuery(url.searchParams.get('q'));
      const condition = String(url.searchParams.get('condition') || '').trim().slice(0, 32);
      if (!q) return json(res, 400, { error: 'q is required', items: [], best: null });
      if (!condition) return json(res, 400, { error: 'condition is required', items: [], best: null });

      const started = Date.now();
      try {
        const result = await fetchBuybackOffers(q, condition);
        return json(res, 200, {
          source: 'buyback',
          query: q,
          condition,
          configured: result.configured,
          live: result.configured && result.items.length > 0,
          items: result.items,
          best: result.best,
          meta: {
            count: result.items.length,
            elapsed_ms: Date.now() - started,
            data_kind: 'indicative_buyback',
            note: result.configured
              ? 'Indicative provider offers; final payout may depend on provider inspection.'
              : 'Buyback provider is not configured; no price is estimated or fabricated.',
          },
        });
      } catch (error) {
        const message = error?.name === 'AbortError'
          ? 'upstream_timeout'
          : error instanceof Error
            ? error.message
            : String(error);
        return json(res, 503, {
          source: 'buyback',
          query: q,
          condition,
          items: [],
          best: null,
          error: message,
        });
      }
    }

"""
    updated = replace_once(updated, anchor, route + anchor, "buyback-route")

    if updated == original:
        print("No changes needed.")
        return
    PATH.write_text(updated, encoding="utf-8")
    print(f"Updated {PATH}")


if __name__ == "__main__":
    main()
