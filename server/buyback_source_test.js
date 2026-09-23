'use strict';

const assert = require('assert');

const MODULE = require.resolve('./buyback_source');

function loadSource(env = {}) {
  const previous = {
    BUYBACK_SOURCE_URL: process.env.BUYBACK_SOURCE_URL,
    BUYBACK_SOURCE_TOKEN: process.env.BUYBACK_SOURCE_TOKEN,
    BUYBACK_SOURCE_TIMEOUT_MS: process.env.BUYBACK_SOURCE_TIMEOUT_MS,
    BUYBACK_SOURCE_POLICY_ACK: process.env.BUYBACK_SOURCE_POLICY_ACK,
    BUYBACK_SOURCE_PROVIDER_IDS: process.env.BUYBACK_SOURCE_PROVIDER_IDS,
    BUYBACK_SOURCE_APPROVAL_VALID_UNTIL: process.env.BUYBACK_SOURCE_APPROVAL_VALID_UNTIL,
  };
  if (env.url === undefined) delete process.env.BUYBACK_SOURCE_URL;
  else process.env.BUYBACK_SOURCE_URL = env.url;
  if (env.token === undefined) delete process.env.BUYBACK_SOURCE_TOKEN;
  else process.env.BUYBACK_SOURCE_TOKEN = env.token;
  if (env.timeout === undefined) delete process.env.BUYBACK_SOURCE_TIMEOUT_MS;
  else process.env.BUYBACK_SOURCE_TIMEOUT_MS = String(env.timeout);
  if (env.policyAck === undefined) delete process.env.BUYBACK_SOURCE_POLICY_ACK;
  else process.env.BUYBACK_SOURCE_POLICY_ACK = env.policyAck;
  if (env.providerIds === undefined) delete process.env.BUYBACK_SOURCE_PROVIDER_IDS;
  else process.env.BUYBACK_SOURCE_PROVIDER_IDS = env.providerIds;
  if (env.validUntil === undefined) delete process.env.BUYBACK_SOURCE_APPROVAL_VALID_UNTIL;
  else process.env.BUYBACK_SOURCE_APPROVAL_VALID_UNTIL = env.validUntil;
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

function approvedEnv(overrides = {}) {
  return {
    url: 'https://partner.example/quotes',
    policyAck: 'approved-feed-and-price-display-v1',
    providerIds: 'clevertronic',
    validUntil: '2099-12-31T23:59:59Z',
    ...overrides,
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

  loaded = loadSource({ url: 'https://partner.example/quotes' });
  assert.strictEqual(loaded.source.configured(), false, 'a URL alone must never enable live provider prices');
  assert.strictEqual(loaded.source.sourceStatus().rights_gate, 'not_approved_or_expired');
  loaded.restore();

  loaded = loadSource(approvedEnv({ policyAck: 'affiliate-link-only' }));
  assert.strictEqual(loaded.source.configured(), false, 'affiliate access is not price-display approval');
  loaded.restore();

  loaded = loadSource(approvedEnv({ providerIds: '' }));
  assert.strictEqual(loaded.source.configured(), false, 'approved provider ids are required');
  loaded.restore();

  loaded = loadSource(approvedEnv({ validUntil: '2020-01-01T00:00:00Z' }));
  assert.strictEqual(loaded.source.configured(), false, 'expired approval must fail closed');
  loaded.restore();

  loaded = loadSource({ url: 'https://user:password@partner.example/quotes' });
  assert.strictEqual(loaded.source.configured(), false, 'credentials must not be embedded in the partner URL');
  loaded.restore();

  for (const url of ['https://localhost/quotes', 'https://partner.local/quotes', 'https://127.0.0.1/quotes', 'https://10.0.0.8/quotes', 'https://169.254.1.2/quotes', 'https://192.168.1.5/quotes', 'https://[::1]/quotes', 'https://[fd12:3456::1]/quotes']) {
    loaded = loadSource({ url });
    assert.strictEqual(loaded.source.configured(), false, `non-public partner host must be rejected: ${url}`);
    loaded.restore();
  }

  loaded = loadSource(approvedEnv({ token: 'server-secret' }));
  let fetchCalls = 0;
  const emptyResult = await loaded.source.fetchBuybackOffers('  ', 'like_new', {
    fetchImpl: async () => { fetchCalls += 1; throw new Error('must not fetch an empty query'); },
  });
  assert.deepStrictEqual(emptyResult, { configured: true, items: [], best: null });
  assert.strictEqual(fetchCalls, 0);

  const invalidConditionResult = await loaded.source.fetchBuybackOffers('iPhone 15', 'mint-ish', {
    fetchImpl: async () => { fetchCalls += 1; throw new Error('must not fetch an invalid condition'); },
  });
  assert.deepStrictEqual(invalidConditionResult, { configured: true, items: [], best: null });
  assert.strictEqual(fetchCalls, 0, 'invalid conditions must not consume partner requests');

  const outageResult = await loaded.source.fetchBuybackOffers('iPhone 15', 'like_new', {
    fetchImpl: async () => { throw new Error('partner offline'); },
  });
  assert.deepStrictEqual(outageResult, { configured: true, items: [], best: null, unavailable: true });
  loaded.restore();

  loaded = loadSource(approvedEnv({ timeout: 1 }));
  let timeoutSignal;
  const timeoutResult = await loaded.source.fetchBuybackOffers('iPhone 15', 'like_new', {
    fetchImpl: async (_url, options) => {
      timeoutSignal = options.signal;
      return new Promise((resolve, reject) => {
        options.signal.addEventListener('abort', () => reject(new Error('aborted')), { once: true });
      });
    },
  });
  assert.strictEqual(timeoutSignal.aborted, true, 'partner request must be aborted at the bounded timeout');
  assert.deepStrictEqual(timeoutResult, { configured: true, items: [], best: null, unavailable: true });
  loaded.restore();

  loaded = loadSource(approvedEnv({ token: 'server-secret' }));
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
            provider_id: 'clevertronic', provider_name: 'Clevertronic', product_id: 'iphone-15-pro-256',
            matched_title: 'Apple iPhone 15 Pro 256 GB', condition: 'like_new', price: 615, currency: 'EUR',
            offer_url: 'https://partner.example/offer/123', checked_at: '2026-09-20T07:55:00Z',
            price_kind: 'indicative_buyback', requires_inspection: true, match_confidence: 0.98,
          }] };
        },
      };
    },
  });

  assert.strictEqual(requestedUrl.origin + requestedUrl.pathname, 'https://partner.example/quotes');
  assert.strictEqual(requestedUrl.searchParams.get('q'), 'Apple iPhone 15 Pro 256 GB');
  assert.strictEqual(requestedUrl.searchParams.get('condition'), 'like_new');
  assert.strictEqual(requestedOptions.headers.authorization, 'Bearer server-secret');
  assert.strictEqual(requestedOptions.redirect, 'error', 'partner auth requests must never follow redirects');
  assert.strictEqual(result.configured, true);
  assert.strictEqual(result.items.length, 1);
  assert.strictEqual(result.best.provider_id, 'clevertronic');
  assert.strictEqual(result.best.price, 615);
  const mixed = await loaded.source.fetchBuybackOffers('Apple iPhone 15 Pro 256 GB', 'like_new', {
    now,
    fetchImpl: async () => ({
      ok: true,
      async json() {
        const good = {
          provider_id: 'clevertronic', provider_name: 'Clevertronic', product_id: 'iphone-15-pro-256',
          matched_title: 'Apple iPhone 15 Pro 256 GB', condition: 'like_new', price: 615,
          currency: 'EUR', offer_url: 'https://partner.example/offer/good',
          checked_at: '2026-09-20T07:55:00Z', price_kind: 'indicative_buyback',
          match_confidence: 0.98,
        };
        return { items: [good, {
          ...good, provider_id: 'wrong-variant', product_id: 'iphone-15-pro-max-256',
          matched_title: 'Apple iPhone 15 Pro Max 256 GB', price: 900, match_confidence: 1,
        }] };
      },
    }),
  });
  assert.strictEqual(mixed.items.length, 1, 'higher priced wrong model must not enter the comparison');
  assert.strictEqual(mixed.best.provider_id, 'clevertronic');
  loaded.restore();

  loaded = loadSource(approvedEnv({ providerIds: 'clevertronic, zoxs' }));
  const approvalFiltered = await loaded.source.fetchBuybackOffers('Apple iPhone 15 Pro 256 GB', 'like_new', {
    now,
    fetchImpl: async () => ({
      ok: true,
      async json() {
        const offer = {
          provider_name: 'Approved provider', product_id: 'iphone-15-pro-256',
          matched_title: 'Apple iPhone 15 Pro 256 GB', condition: 'like_new', price: 615,
          currency: 'EUR', offer_url: 'https://partner.example/offer/good',
          checked_at: '2026-09-20T07:55:00Z', price_kind: 'indicative_buyback',
          requires_inspection: true, match_confidence: 0.98,
        };
        return { items: [
          { ...offer, provider_id: 'clevertronic' },
          { ...offer, provider_id: 'unapproved-provider', provider_name: 'Unknown', price: 999 },
        ] };
      },
    }),
  });
  assert.strictEqual(approvalFiltered.items.length, 1, 'unapproved feed providers must never become live offers');
  assert.strictEqual(approvalFiltered.items[0].provider_id, 'clevertronic');
  assert.deepStrictEqual(loaded.source.sourceStatus(), {
    configured: true,
    mode: 'approved_partner_adapter',
    data_kind: 'indicative_buyback',
    max_age_hours: 24,
    minimum_match_confidence: 0.9,
    rights_gate: 'approved',
    approved_provider_count: 2,
  });
  loaded.restore();

  console.log('buyback source tests passed');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
