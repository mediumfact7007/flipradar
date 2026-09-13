'use strict';

const ALLOWED_LISTING_HOSTS = new Set(['kleinanzeigen.de', 'www.kleinanzeigen.de']);
const MAX_HTML_BYTES = 2 * 1024 * 1024;
const FETCH_TIMEOUT_MS = 7000;

function cleanText(value) {
  return decodeHtml(String(value || ''))
    .replace(/\s+/g, ' ')
    .replace(/\s*[|\-–—]\s*Kleinanzeigen\s*$/i, '')
    .trim();
}

function decodeHtml(value) {
  const named = {
    amp: '&', quot: '"', apos: "'", lt: '<', gt: '>', nbsp: ' ', euro: '€',
  };
  return String(value || '')
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
    .replace(/&([a-z]+);/gi, (m, name) => named[name.toLowerCase()] ?? m);
}

function parseMoney(value) {
  let raw = String(value ?? '').trim().replace(/\s+/g, '').replace(/€/g, '').replace(/[^0-9,.-]/g, '');
  if (!raw) return 0;
  const comma = raw.lastIndexOf(',');
  const dot = raw.lastIndexOf('.');
  if (comma >= 0 && dot >= 0) {
    raw = comma > dot ? raw.replace(/\./g, '').replace(',', '.') : raw.replace(/,/g, '');
  } else if (comma >= 0) {
    const decimals = raw.length - comma - 1;
    raw = decimals === 3 && comma > 0 ? raw.replace(/,/g, '') : raw.replace(',', '.');
  } else if (dot >= 0) {
    const decimals = raw.length - dot - 1;
    if (decimals === 3 && dot > 0) raw = raw.replace(/\./g, '');
  }
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 && n <= 1000000 ? n : 0;
}

function attrs(tag) {
  const out = {};
  const re = /([:\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/g;
  let match;
  while ((match = re.exec(tag)) !== null) {
    out[match[1].toLowerCase()] = decodeHtml(match[2] ?? match[3] ?? match[4] ?? '');
  }
  return out;
}

function metaValue(html, keys) {
  const wanted = new Set(keys.map((k) => k.toLowerCase()));
  const tags = String(html || '').match(/<meta\b[^>]*>/gi) || [];
  for (const tag of tags) {
    const a = attrs(tag);
    const key = String(a.property || a.name || a.itemprop || '').toLowerCase();
    if (wanted.has(key) && a.content) return a.content.trim();
  }
  return '';
}

function jsonLdObjects(html) {
  const out = [];
  const re = /<script\b[^>]*type\s*=\s*["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let match;
  while ((match = re.exec(String(html || ''))) !== null) {
    try {
      const parsed = JSON.parse(decodeHtml(match[1]).trim());
      if (Array.isArray(parsed)) out.push(...parsed);
      else out.push(parsed);
    } catch (_) {}
  }
  return out;
}

function firstProductData(value) {
  if (!value || typeof value !== 'object') return null;
  if (Array.isArray(value)) {
    for (const item of value) {
      const found = firstProductData(item);
      if (found) return found;
    }
    return null;
  }
  const type = String(value['@type'] || '').toLowerCase();
  if (type === 'product' || type === 'offer') {
    const offers = value.offers && typeof value.offers === 'object' ? value.offers : value;
    const offer = Array.isArray(offers) ? offers[0] || {} : offers;
    const price = parseMoney(offer.price ?? offer.lowPrice ?? value.price ?? value.lowPrice);
    const title = cleanText(value.name || value.headline || '');
    const currency = String(offer.priceCurrency || value.priceCurrency || '').toUpperCase();
    if (price > 0 || title) return { title, price, currency };
  }
  for (const child of Object.values(value)) {
    const found = firstProductData(child);
    if (found) return found;
  }
  return null;
}

function parseKleinanzeigenHtml(html) {
  const ld = jsonLdObjects(html).map(firstProductData).find(Boolean) || {};
  const title = cleanText(
    ld.title ||
    metaValue(html, ['og:title', 'twitter:title']) ||
    ((String(html || '').match(/<title[^>]*>([\s\S]*?)<\/title>/i) || [])[1] || '')
  );

  let price = parseMoney(ld.price);
  if (price <= 0) {
    price = parseMoney(metaValue(html, [
      'product:price:amount',
      'og:price:amount',
      'price',
      'product:price',
    ]));
  }
  if (price <= 0) {
    const pricePatterns = [
      /"price"\s*:\s*"?([0-9][0-9., ]{0,12})"?/i,
      /data-testid\s*=\s*["'][^"']*price[^"']*["'][^>]*>[\s\S]{0,160}?([0-9][0-9., ]{0,12})\s*(?:€|EUR)/i,
      /class\s*=\s*["'][^"']*price[^"']*["'][^>]*>[\s\S]{0,160}?([0-9][0-9., ]{0,12})\s*(?:€|EUR)/i,
    ];
    for (const pattern of pricePatterns) {
      const match = String(html || '').match(pattern);
      if (!match) continue;
      price = parseMoney(match[1]);
      if (price > 0) break;
    }
  }

  const currency = String(
    ld.currency || metaValue(html, ['product:price:currency', 'og:price:currency', 'pricecurrency']) || 'EUR'
  ).toUpperCase();

  return {
    title,
    price,
    currency: currency || 'EUR',
  };
}

function isAllowedListingUrl(rawUrl) {
  try {
    const url = new URL(String(rawUrl || '').trim());
    return url.protocol === 'https:' && ALLOWED_LISTING_HOSTS.has(url.hostname.toLowerCase()) && /\/s-anzeige\//.test(url.pathname);
  } catch (_) {
    return false;
  }
}

async function fetchHtmlAllowed(rawUrl) {
  let current = new URL(rawUrl);
  for (let hop = 0; hop < 4; hop += 1) {
    if (!isAllowedListingUrl(current.toString())) throw new Error('unsupported_listing_url');
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
    let response;
    try {
      response = await fetch(current, {
        redirect: 'manual',
        signal: controller.signal,
        headers: {
          'user-agent': 'Mozilla/5.0 (Linux; Android 16) AppleWebKit/537.36 Chrome/140 Mobile Safari/537.36 FlipRadar/0.14.6',
          'accept-language': 'de-DE,de;q=0.9,en;q=0.5',
          accept: 'text/html,application/xhtml+xml',
        },
      });
    } finally {
      clearTimeout(timer);
    }

    if (response.status >= 300 && response.status < 400) {
      const location = response.headers.get('location');
      if (!location) throw new Error('listing_redirect_without_location');
      current = new URL(location, current);
      continue;
    }
    if (!response.ok) throw new Error(`listing_fetch_failed_${response.status}`);
    const type = String(response.headers.get('content-type') || '').toLowerCase();
    if (type && !type.includes('text/html') && !type.includes('application/xhtml+xml')) {
      throw new Error('listing_not_html');
    }
    const bytes = new Uint8Array(await response.arrayBuffer());
    if (bytes.byteLength > MAX_HTML_BYTES) throw new Error('listing_too_large');
    return { html: new TextDecoder('utf-8').decode(bytes), url: current.toString() };
  }
  throw new Error('too_many_redirects');
}

async function resolvePublicListing(rawUrl) {
  if (!isAllowedListingUrl(rawUrl)) throw new Error('unsupported_listing_url');
  const fetched = await fetchHtmlAllowed(rawUrl);
  const parsed = parseKleinanzeigenHtml(fetched.html);
  if (!parsed.title && parsed.price <= 0) throw new Error('listing_metadata_missing');
  return {
    source: 'kleinanzeigen',
    title: parsed.title,
    price: parsed.price,
    currency: parsed.currency,
    url: fetched.url,
    kind: 'listing_asking_price',
  };
}

module.exports = {
  isAllowedListingUrl,
  parseKleinanzeigenHtml,
  resolvePublicListing,
};
