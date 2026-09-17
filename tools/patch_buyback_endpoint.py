#!/usr/bin/env python3
"""Add the isolated /v1/buyback/search API route without touching market search."""
from pathlib import Path

PATH = Path("server/index.js")
BUYBACK_IMPORT = "const { fetchBuybackOffers, sourceStatus: buybackSourceStatus } = require('./buyback_source');\n"
BUYBACK_STATUS = "    buyback: buybackSourceStatus(),\n"


def ensure_single_after(text: str, anchor: str, line: str, label: str) -> str:
    """Keep exactly one generated line immediately after a stable anchor."""
    if text.count(anchor) != 1:
        raise SystemExit(f"{label}: expected one anchor; refusing to write")
    cleaned = text.replace(line, "")
    print(f"{label}: normalized")
    return cleaned.replace(anchor, anchor + line, 1)


def main() -> None:
    original = PATH.read_text(encoding="utf-8")
    updated = original

    updated = ensure_single_after(
        updated,
        "const { resolvePublicListing } = require('./listing_resolver');\n",
        BUYBACK_IMPORT,
        "buyback-import",
    )

    updated = ensure_single_after(
        updated,
        "    idealo: { configured: false, mode: 'official_search_link' },\n",
        BUYBACK_STATUS,
        "buyback-status",
    )

    anchor = "    if (req.method === 'GET' && url.pathname === '/v1/market/search') {\n"
    route_marker = "    if (req.method === 'GET' && url.pathname === '/v1/buyback/search') {\n"
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
    if route_marker not in updated:
        if updated.count(anchor) != 1:
            raise SystemExit("buyback-route: expected one market-search anchor; refusing to write")
        updated = updated.replace(anchor, route + anchor, 1)
        print("buyback-route: applied")
    elif updated.count(route_marker) == 1:
        print("buyback-route: already applied")
    else:
        raise SystemExit("buyback-route: duplicate routes found; refusing to write")

    if updated == original:
        print("No changes needed.")
        return
    PATH.write_text(updated, encoding="utf-8")
    print(f"Updated {PATH}")


if __name__ == "__main__":
    main()
