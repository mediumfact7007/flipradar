// FlipRadar V0.4 - minimal Cloudflare Worker backend for eBay DE.
// Configure secrets with:
//   wrangler secret put EBAY_CLIENT_ID
//   wrangler secret put EBAY_CLIENT_SECRET
// Then deploy and paste the Worker URL into FlipRadar > Setup > eBay DE Backend.

let cachedToken = null;
let tokenExpiresAt = 0;

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

async function ebayToken(env) {
  if (cachedToken && Date.now() < tokenExpiresAt - 60000) return cachedToken;
  if (!env.EBAY_CLIENT_ID || !env.EBAY_CLIENT_SECRET) {
    throw new Error('Missing EBAY_CLIENT_ID / EBAY_CLIENT_SECRET');
  }
  const basic = btoa(`${env.EBAY_CLIENT_ID}:${env.EBAY_CLIENT_SECRET}`);
  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    scope: 'https://api.ebay.com/oauth/api_scope',
  });
  const r = await fetch('https://api.ebay.com/identity/v1/oauth2/token', {
    method: 'POST',
    headers: {
      Authorization: `Basic ${basic}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  });
  if (!r.ok) throw new Error(`eBay token HTTP ${r.status}`);
  const d = await r.json();
  cachedToken = d.access_token;
  tokenExpiresAt = Date.now() + Number(d.expires_in || 7200) * 1000;
  return cachedToken;
}

function median(values) {
  const v = [...values].sort((a, b) => a - b);
  if (!v.length) return null;
  const m = Math.floor(v.length / 2);
  return v.length % 2 ? v[m] : (v[m - 1] + v[m]) / 2;
}

async function ebaySearch(url, env) {
  const q = (url.searchParams.get('q') || '').trim();
  if (!q) return json({ error: 'Missing q' }, 400);
  const marketplace = url.searchParams.get('marketplace') || 'EBAY_DE';
  const token = await ebayToken(env);
  const p = new URLSearchParams({ limit: '50' });
  if (/^\d{8,14}$/.test(q)) p.set('gtin', q);
  else p.set('q', q);

  const r = await fetch(`https://api.ebay.com/buy/browse/v1/item_summary/search?${p}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      'X-EBAY-C-MARKETPLACE-ID': marketplace,
    },
  });
  if (!r.ok) {
    const text = await r.text();
    return json({ error: `eBay HTTP ${r.status}`, detail: text.slice(0, 600) }, r.status);
  }
  const d = await r.json();
  const items = Array.isArray(d.itemSummaries) ? d.itemSummaries : [];
  const normalized = items
    .map((x) => {
      const value = Number(x?.price?.value);
      const shipping = Array.isArray(x.shippingOptions)
        ? Number(x.shippingOptions[0]?.shippingCost?.value || 0)
        : 0;
      return {
        id: x.itemId,
        title: x.title,
        price: Number.isFinite(value) ? value : null,
        shipping: Number.isFinite(shipping) ? shipping : 0,
        total: Number.isFinite(value) ? value + (Number.isFinite(shipping) ? shipping : 0) : null,
        currency: x?.price?.currency || null,
        condition: x.condition || null,
        image: x?.image?.imageUrl || null,
        url: x.itemWebUrl || null,
        seller: x?.seller?.username || null,
      };
    })
    .filter((x) => x.total != null && (!x.currency || x.currency === 'EUR'));

  const prices = normalized.map((x) => x.total);
  return json({
    source: 'eBay DE',
    query: q,
    marketplace,
    live: true,
    count: normalized.length,
    min: prices.length ? Math.min(...prices) : null,
    max: prices.length ? Math.max(...prices) : null,
    median: median(prices),
    items: normalized.slice(0, 25),
    note: 'Active listings. Sold-history is not inferred from active listings.',
    fetchedAt: new Date().toISOString(),
  });
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
    const url = new URL(request.url);
    try {
      if (url.pathname === '/api/market/ebay') return await ebaySearch(url, env);
      if (url.pathname === '/api/source/status') {
        return json({
          ebay: Boolean(env.EBAY_CLIENT_ID && env.EBAY_CLIENT_SECRET),
          amazonKeepa: 'client-configured',
          mediaMarkt: 'partner-feed-required',
          saturn: 'partner-feed-required',
          kleinanzeigen: 'portal-search-only',
        });
      }
      return json({ name: 'FlipRadar API', version: '0.4', ok: true });
    } catch (e) {
      return json({ error: String(e?.message || e) }, 500);
    }
  },
};
