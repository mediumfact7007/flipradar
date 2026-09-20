'use strict';

const assert = require('assert');

const MODULE = require.resolve('./buyback_source');

function loadSource(env = {}) {
  const previous = {
    BUYBACK_SOURCE_URL: process.env.BUYBACK_SOURCE_URL,
    BUYBACK_SOURCE_TOKEN: process.env.BUYBACK_SOURCE_TOKEN,
  };
  if (env.url === undefined) delete process.env.BUYBACK_SOURCE_URL;
  else process.env.BUYBACK_SOURCE_URL = env.url;
  if (env.token === undefined) delete process.env.BUYBACK_SOURCE_TOKEN;
  else process.env.BUYBACK_SOURCE_TOKEN = env.token;
  delete require.cache[MODULE];
  const source = require('./buyback_source');
  return {
    source,
    restore() {
      delete require.cache[MODULE];
      for (const [key, value] of Object.entries(previous)) {
        if (value === undefined) delete process.env[key];
        else process.env[key] = value;
      }
    },
  };
}

(async () => {
  let loaded = loadSource();
  assert.strictEqual(loaded.source.configured(), false);
  assert.deepStrictEqual(await loaded.source.fetchBuybackOffers('iPhone 15', 'like_new'), {
    configured: false,
    items: [],
    best: null,
  });
  loaded.restore();

  loaded = loadSource({ url: 'http://partner.example/quotes' });
  assert.strictEqual(loaded.source.configured(), false, 'plain HTTP must never become a live source');
  loaded.restore();

  loaded = loadSource({ url: 'https://partner.example/quotes', token: 'server-secret' });
  let fetchCalls = 0;
  const emptyResult = await loaded.source.fetchBuybackOffers('  ', 'like_new', {
    fetchImpl: async () => { fetchCalls += 1; throw new Error('must not fetch an empty query'); },
  });
  assert.deepStrictEqual(emptyResult, { configured: true, items: [], best: null });
  assert.strictEqual(fetchCalls, 0);

  let requestedUrl;
  let requestedOptions;
  const now = Date.parse('2026-09-20T08:00:00Z');
  const result = await loaded.source.fetchBuybackOffers(' Apple iPhone 15 Pro 256 GB ', 'like_new', {
    now,
    fetchImpl: async (url, options) => {
      requestedUrl = new URL(url.toString());
      requestedOptions = options;
      return {
        ok: true,
        async json() {
          return { items: [{
            provider_id: 'clevertronic',
            provider_name: 'Clevertronic',
            product_id: 'iphone-15-pro-256',
            matched_title: 'Apple iPhone 15 Pro 256 GB',
            condition: 'like_new',
            price: 615,
            currency: 'EUR',
            offer_url: 'https://partner.example/offer/123',
            checked_at: '2026-09-20T07:55:00Z',
            price_kind: 'indicative_buyback',
            requires_inspection: true,
            match_confidence: 0.98,
          }] };
        },
      };
    },
  });

  assert.strictEqual(requestedUrl.origin + requestedUrl.pathname, 'https://partner.example/quotes');
  assert.strictEqual(requestedUrl.searchParams.get('q'), 'Apple iPhone 15 Pro 256 GB');
  assert.strictEqual(requestedUrl.searchParams.get('condition'), 'like_new');
  assert.strictEqual(requestedOptions.headers.authorization, 'Bearer server-secret');
  assert.strictEqual(result.configured, true);
  assert.strictEqual(result.items.length, 1);
  assert.strictEqual(result.best.provider_id, 'clevertronic');
  assert.strictEqual(result.best.price, 615);
  loaded.restore();

  console.log('buyback source tests passed');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
