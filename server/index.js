'use strict';

const http = require('http');
const { URL, URLSearchParams } = require('url');

const PORT = Number(process.env.PORT || 8080);
const EBAY_CLIENT_ID = process.env.EBAY_CLIENT_ID || '';
const EBAY_CLIENT_SECRET = process.env.EBAY_CLIENT_SECRET || '';
const KEEPA_API_KEY = process.env.KEEPA_API_KEY || '';

const RATE_WINDOW_MS = 60_000;
const RATE_MAX = Number(process.env.RATE_LIMIT_PER_MINUTE || 90);
const CACHE_TTL_MS = 45_000;
const CACHE_MAX = 400;
const ALLOWED_SOURCES = new Set(['ebay_de', 'amazon_de', 'all']);

let ebayToken = null;
let ebayTokenExpiresAt = 0;
const rateBuckets = new Map();
const searchCache = new Map();

function json(res, status, body) {
  const data = JSON.stringify(body);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(data),
    'access-control-allow-origin': '*',
    'cache-control': status >= 200 && status < 300 ? 'public, max-age=30' : 'no-store',
    'x-content-type-options': 'nosniff',
  });
  res.end(data);
}

function money(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

function normalizeQuery(value) {
  return String(value || '').replace(/\s+/g, ' ').trim().slice(0, 160);
}

function clientIp(req) {
  const forwarded = String(req.headers['x-forwarded-for'] || '').split(',')[0].trim();
  return forwarded || req.socket.remoteAddress || 'unknown';
}

function allowRequest(req) {
  const now = Date.now();
  const key = clientIp(req);
  const current = rateBuckets.get(key);
  if (!current || now - current.startedAt >= RATE_WINDOW_MS) {
    rateBuckets.set(key, { startedAt: now, count: 1 });
    return true;
  }
  current.count += 1;
  return current.count <= RATE_MAX;
}

function pruneRateBuckets() {
  if (rateBuckets.size < 1000) return;
  const cutoff = Date.now() - RATE_WINDOW_MS * 2;
  for (const [key, value] of rateBuckets) {
    if (value.startedAt < cutoff) rateBuckets.delete(key);
  }
}

function cacheGet(source, q) {
  const key = `${source}:${q.toLowerCase()}`;
  const entry = searchCache.get(key);
  if (!entry) return null;
  if (Date.now() - entry.createdAt > CACHE_TTL_MS) {
    searchCache.delete(key);
    return null;
  }
  return entry.items;
}

function cacheSet(source, q, items) {
  const key = `${source}:${q.toLowerCase()}`;
  if (searchCache.size >= CACHE_MAX) {
    const oldest = searchCache.keys().next().value;
    if (oldest) searchCache.delete(oldest);
  }
  searchCache.set(key, { createdAt: Date.now(), items });
}

async function getEbayToken() {
  if (!EBAY_CLIENT_ID || !EBAY_CLIENT_SECRET) {
    throw new Error('eBay credentials are not configured');
  }
  if (ebayToken && Date.now() < ebayTokenExpiresAt - 60_000) return ebayToken;

  const auth = Buffer.from(`${EBAY_CLIENT_ID}:${EBAY_CLIENT_SECRET}`).toString('base64');
  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    scope: 'https://api.ebay.com/oauth/api_scope',
  });

  const response = await fetch('https://api.ebay.com/identity/v1/oauth2/token', {
    method: 'POST',
    headers: {
      authorization: `Basic ${auth}`,
      'content-type': 'application/x-www-form-urlencoded',
    },
    body,
  });

  if (!response.ok) {
    throw new Error(`eBay OAuth failed (${response.status})`);
  }

  const data = await response.json();
  ebayToken = data.access_token;
  ebayTokenExpiresAt = Date.now() + Number(data.expires_in || 7200) * 1000;
  return ebayToken;
}

async function searchEbay(q) {
  const token = await getEbayToken();
  const url = new URL('https://api.ebay.com/buy/browse/v1/item_summary/search');
  if (/^\d{8,14}$/.test(q)) {
    url.searchParams.set('gtin', q);
  } else {
    url.searchParams.set('q', q);
  }
  url.searchParams.set('limit', '30');
  // FlipRadar's beginner resale estimate deliberately uses used, fixed-price
  // listings. Auction bids and new retail inventory would distort the asking
  // price median used by the mobile app.
  url.searchParams.set('filter', 'conditions:{USED},buyingOptions:{FIXED_PRICE}');

  const response = await fetch(url, {
    headers: {
      authorization: `Bearer ${token}`,
      'x-ebay-c-marketplace-id': 'EBAY_DE',
      'accept-language': 'de-DE',
    },
  });

  if (!response.ok) {
    throw new Error(`eBay Browse failed (${response.status})`);
  }

  const data = await response.json();
  return (data.itemSummaries || []).map((item) => {
    const shipping = item.shippingOptions?.[0]?.shippingCost?.value || 0;
    return {
      source: 'ebay_de',
      title: item.title || 'eBay listing',
      price: money(item.price?.value),
      shipping: money(shipping),
      currency: item.price?.currency || 'EUR',
      condition: item.condition || 'USED',
      url: item.itemWebUrl || '',
      live: true,
    };
  }).filter((x) => x.price > 0);
}

function keepaRequestUrl(q) {
  if (!KEEPA_API_KEY) throw new Error('Keepa API key is not configured');

  const value = q.trim();
  const url = new URL('https://api.keepa.com/product');
  url.searchParams.set('key', KEEPA_API_KEY);
  url.searchParams.set('domain', '3');
  url.searchParams.set('offers', '20');
  url.searchParams.set('only-live-offers', '1');
  url.searchParams.set('history', '0');

  if (/^[A-Z0-9]{10}$/i.test(value) && /[A-Z]/i.test(value)) {
    url.searchParams.set('asin', value.toUpperCase());
  } else if (/^\d{8,14}$/.test(value)) {
    url.searchParams.set('code', value);
  } else {
    return null;
  }
  return url;
}

async function searchAmazon(q) {
  const url = keepaRequestUrl(q);
  if (!url) return [];

  const response = await fetch(url, {
    headers: { 'accept-encoding': 'gzip' },
  });

  if (!response.ok) {
    throw new Error(`Keepa request failed (${response.status})`);
  }

  const data = await response.json();
  const product = data.products?.[0];
  if (!product) return [];

  const asin = product.asin || '';
  const title = product.title || `Amazon ${asin}`;
  const offers = Array.isArray(product.offers) ? product.offers : [];
  const items = [];

  for (const offer of offers) {
    const csv = offer.offerCSV;
    if (!Array.isArray(csv) || csv.length < 2) continue;
    const rawPrice = Number(csv[csv.length - 2]);
    const rawShipping = Number(csv[csv.length - 1]);
    if (!Number.isFinite(rawPrice) || rawPrice <= 0) continue;

    items.push({
      source: 'amazon_de',
      title,
      price: rawPrice / 100,
      shipping: Number.isFinite(rawShipping) && rawShipping > 0 ? rawShipping / 100 : 0,
      currency: 'EUR',
      condition: `Amazon marketplace · condition ${offer.condition ?? ''}`.trim(),
      url: asin ? `https://www.amazon.de/dp/${encodeURIComponent(asin)}` : 'https://www.amazon.de/',
      live: true,
    });
  }

  return items;
}

async function marketSearch(source, q) {
  switch (source) {
    case 'ebay_de':
      return searchEbay(q);
    case 'amazon_de':
      return searchAmazon(q);
    case 'all': {
      const results = await Promise.allSettled([searchEbay(q), searchAmazon(q)]);
      return results.flatMap((r) => r.status === 'fulfilled' ? r.value : []);
    }
    default:
      return [];
  }
}

async function marketSearchCached(source, q) {
  const cached = cacheGet(source, q);
  if (cached) return { items: cached, cached: true };
  const items = await marketSearch(source, q);
  cacheSet(source, q, items);
  return { items, cached: false };
}

function sourceStatus() {
  return {
    ebay_de: {
      configured: Boolean(EBAY_CLIENT_ID && EBAY_CLIENT_SECRET),
      mode: 'official_api',
      estimate: 'used_fixed_price_active_listings',
    },
    amazon_de: {
      configured: Boolean(KEEPA_API_KEY),
      mode: 'keepa',
      estimate: 'retail_reference',
    },
    kleinanzeigen: { configured: false, mode: 'official_search_link' },
    mediamarkt: { configured: false, mode: 'official_search_link' },
    saturn: { configured: false, mode: 'official_search_link' },
    idealo: { configured: false, mode: 'official_search_link' },
  };
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

    if (req.method === 'OPTIONS') {
      res.writeHead(204, {
        'access-control-allow-origin': '*',
        'access-control-allow-methods': 'GET,OPTIONS',
        'access-control-allow-headers': 'content-type',
      });
      return res.end();
    }

    if (req.method === 'GET' && url.pathname === '/health') {
      return json(res, 200, { ok: true, service: 'flipradar-api', version: '0.9.0' });
    }

    if (req.method === 'GET' && url.pathname === '/v1/status') {
      return json(res, 200, { sources: sourceStatus() });
    }

    if (req.method === 'GET' && url.pathname === '/v1/market/search') {
      pruneRateBuckets();
      if (!allowRequest(req)) {
        return json(res, 429, { error: 'rate_limit', items: [] });
      }

      const source = String(url.searchParams.get('source') || '').trim();
      const q = normalizeQuery(url.searchParams.get('q'));
      if (!ALLOWED_SOURCES.has(source)) {
        return json(res, 400, { error: 'unsupported_source', items: [] });
      }
      if (!q) {
        return json(res, 400, { error: 'q is required', items: [] });
      }

      const started = Date.now();
      try {
        const result = await marketSearchCached(source, q);
        return json(res, 200, {
          source,
          query: q,
          live: result.items.length > 0,
          items: result.items,
          meta: {
            count: result.items.length,
            elapsed_ms: Date.now() - started,
            cached: result.cached,
            note: source === 'ebay_de'
              ? 'eBay Browse: used fixed-price active listings, not verified sold prices.'
              : source === 'amazon_de'
                ? 'Amazon reference data is provided through Keepa when configured.'
                : '',
          },
        });
      } catch (error) {
        return json(res, 503, {
          source,
          query: q,
          items: [],
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    return json(res, 404, { error: 'not_found' });
  } catch (error) {
    return json(res, 500, { error: error instanceof Error ? error.message : String(error) });
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`FlipRadar API listening on :${PORT}`);
});