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

function robustPriceSample(values) {
  const v = values.filter(Number.isFinite).sort((a, b) => a - b);
  if (v.length < 5) return v;
  const midpoint = Math.floor(v.length / 2);
  const lower = v.slice(0, midpoint);
  const upper = v.slice(v.length % 2 ? midpoint + 1 : midpoint);
  const q1 = median(lower);
  const q3 = median(upper);
  const iqr = q3 - q1;
  if (!Number.isFinite(iqr) || iqr <= 0) return v;
  const low = q1 - 1.5 * iqr;
  const high = q3 + 1.5 * iqr;
  const filtered = v.filter((price) => price >= low && price <= high);
  return filtered.length >= 3 ? filtered : v;
}

const accessoryIntent = /\b(h[uü]lle|case|cover|schutzglas|displayfolie|ladeger[aä]t|charger|ladekabel|cable|kabel|adapter|halterung|mount|akku|battery|ovp|verpackung|karton|box)\b/i;

function isUsefulFixedPriceListing(item, query = '') {
  const options = Array.isArray(item?.buyingOptions) ? item.buyingOptions : [];
  if (options.length && !options.includes('FIXED_PRICE')) return false;

  const title = String(item?.title || '').toLowerCase();
  if (/\b(ersatzteil|ersatzteile|defekt|bastler|for parts|parts only|not working)\b/.test(title)) return false;

  // Accessory-only hits are noise for normal product searches, but accessories
  // are valid products too. Keep them when the user's query explicitly asks
  // for an accessory instead of turning an intentional search into zero hits.
  const queryWantsAccessory = accessoryIntent.test(String(query || ''));
  if (!queryWantsAccessory && /\b(nur\s+(ovp|verpackung|karton)|leerverpackung|leerpackung|empty\s+box|box\s+only|schutzh[uü]lle|schutzglas|displayfolie|case\s+for|cover\s+for|charger\s+for|ladekabel\s+f[uü]r|adapter\s+f[uü]r|halterung\s+f[uü]r|mount\s+for|akku\s+f[uü]r|battery\s+for)\b/.test(title)) return false;

  const condition = String(item?.condition || '').toLowerCase();
  const conditionId = String(item?.conditionId || '').trim();
  if (conditionId === '7000') return false;
  if (/for parts|not working|parts only|defekt|ersatzteil|ersatzteile|bastler/.test(condition)) return false;

  return true;
}

function cheapestShipping(item) {
  if (!Array.isArray(item?.shippingOptions) || !item.shippingOptions.length) return 0;
  const costs = item.shippingOptions
    .map((option) => Number(option?.shippingCost?.value))
    .filter((value) => Number.isFinite(value) && value >= 0);
  return costs.length ? Math.min(...costs) : 0;
}

async function ebaySearch(url, env) {
  const q = (url.searchParams.get('q') || '').trim();
  if (!q) return json({ error: 'Missing q' }, 400);
  const marketplace = url.searchParams.get('marketplace') || 'EBAY_DE';
  const token = await ebayToken(env);
  const p = new URLSearchParams({
    limit: '50',
    filter: 'buyingOptions:{FIXED_PRICE}',
  });
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
    .filter((item) => isUsefulFixedPriceListing(item, q))
    .map((x) => {
      const value = Number(x?.price?.value);
      const shipping = cheapestShipping(x);
      return {
        id: x.itemId,
        title: x.title,
        price: Number.isFinite(value) ? value : null,
        shipping,
        total: Number.isFinite(value) ? value + shipping : null,
        currency: x?.price?.currency || null,
        condition: x.condition || null,
        image: x?.image?.imageUrl || null,
        url: x.itemWebUrl || null,
        seller: x?.seller?.username || null,
      };
    })
    .filter((x) => x.total != null && x.total > 0 && (!x.currency || x.currency === 'EUR'))
    .sort((a, b) => a.total - b.total);

  const prices = normalized.map((x) => x.total);
  const estimatePrices = robustPriceSample(prices);
  return json({
    source: 'eBay DE',
    query: q,
    marketplace,
    live: true,
    count: normalized.length,
    estimateCount: estimatePrices.length,
    min: estimatePrices.length ? Math.min(...estimatePrices) : null,
    max: estimatePrices.length ? Math.max(...estimatePrices) : null,
    median: median(estimatePrices),
    items: normalized.slice(0, 25),
    note: 'Active fixed-price listings after parts/repair, accessory-only and statistical outlier filtering for the price estimate. Sold-history is not inferred from active listings.',
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
