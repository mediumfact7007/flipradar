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
const FETCH_TIMEOUT_MS = Number(process.env.UPSTREAM_TIMEOUT_MS || 8_000);
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

async function fetchWithTimeout(url, options = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
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

  const response = await fetchWithTimeout('https://api.ebay.com/identity/v1/oauth2/token', {
    method: 'POST',
    headers: {
      authorization: `Basic ${auth}`,
      'content-type': 'application/x-www-form-urlencoded',
    },
    body,
  });

  if (!response.ok) throw new Error(`eBay OAuth failed (${response.status})`);

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
  url.searchParams.set('limit', '40');
  // eBay documents that buyingOptions filtering is category-sensitive. Filter
  // broad USED here, then enforce FIXED_PRICE on the returned item summaries.
  url.searchParams.set('filter', 'conditions:{USED},buyingOptions:{FIXED_PRICE}');

  const response = await fetchWithTimeout(url, {
    headers: {
      authorization: `Bearer ${token}`,
      'x-ebay-c-marketplace-id': 'EBAY_DE',
      'accept-language': 'de-DE',
    },
  });

  if (!response.ok) throw new Error(`eBay Browse failed (${response.status})`);

  const data = await response.json();
  return (data.itemSummaries || [])
    .map((item) => {
      const buyingOptions = Array.isArray(item.buyingOptions) ? item.buyingOptions : [];
      if (!buyingOptions.includes('FIXED_PRICE')) return null;
      const currency = item.price?.currency || 'EUR';
      if (currency !== 'EUR') return null;

      const shippingValues = (item.shippingOptions || [])
        .map((option) => Number(option?.shippingCost?.value))
        .filter((value) => Number.isFinite(value) && value >= 0);
      const shipping = shippingValues.length > 0 ? Math.min(...shippingValues) : 0;

      return {
        source: 'ebay_de',
        title: item.title || 'eBay listing',
        price: money(item.price?.value),
        shipping,
        currency,
        condition: item.condition || 'USED',
        url: item.itemWebUrl || '',
        live: true,
      };
    })
    .filter((item) => item && item.price > 0);
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

function keepaCondition(value) {
  const labels = {
    0: 'Unknown',
    1: 'New',
    2: 'Used - Like New',
    3: 'Used - Very Good',
    4: 'Used - Good',
    5: 'Used - Acceptable',
    6: 'Refurbished',
    7: 'Collectible - Like New',
    8: 'Collectible - Very Good',
    9: 'Collectible - Good',
    10: 'Collectible - Acceptable',
    11: 'Rental',
  };
  return labels[Number(value)] || 'Unknown';
}

async function searchAmazon(q) {
  const url = keepaRequestUrl(q);
  if (!url) return [];

  const response = await fetchWithTimeout(url, {
    headers: { 'accept-encoding': 'gzip' },
  });

  if (!response.ok) throw new Error(`Keepa request failed (${response.status})`);

  const data = await response.json();
  const product = data.products?.[0];
  if (!product) return [];

  const asin = product.asin || '';
  const title = product.title || `Amazon ${asin}`;
  const offers = Array.isArray(product.offers) ? product.offers : [];
  const liveOrder = new Set(Array.isArray(product.liveOffersOrder) ? product.liveOffersOrder : []);
  const items = [];

  for (let index = 0; index < offers.length; index += 1) {
    const offer = offers[index];
    if (liveOrder.size > 0 && !liveOrder.has(index)) continue;
    if (offer.isShippable === false || offer.isPreorder === true) continue;
    // Amazon is a NEW-price reference in FlipRadar. Used/refurbished
    // marketplace offers must not lower the retail benchmark.
    if (Number(offer.condition) !== 1) continue;

    const csv = offer.offerCSV;
    if (!Array.isArray(csv) || csv.length < 2) continue;
    const rawPrice = Number(csv[csv.length - 2]);
    const rawShipping = Number(csv[csv.length - 1]);
    if (!Number.isFinite(rawPrice) || rawPrice <= 0) continue;
    // Keepa uses -1/-2 for unknown/unavailable shipping. Do not turn that into
    // free shipping, because that would understate the comparison total.
    if (!Number.isFinite(rawShipping) || rawShipping < 0) continue;

    items.push({
      source: 'amazon_de',
      title,
      price: rawPrice / 100,
      shipping: rawShipping / 100,
      currency: 'EUR',
      condition: `Amazon marketplace · ${keepaCondition(offer.condition)}`,
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
      return json(res, 200, { ok: true, service: 'flipradar-api', version: '0.9.1' });
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
        const message = error?.name === 'AbortError'
          ? 'upstream_timeout'
          : error instanceof Error
            ? error.message
            : String(error);
        return json(res, 503, { source, query: q, items: [], error: message });
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
