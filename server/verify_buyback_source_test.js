'use strict';

const assert = require('assert');
const { verifyBuybackSource } = require('./verify_buyback_source');

function fakeSource({ status, result }) {
  return {
    sourceStatus: () => status,
    fetchBuybackOffers: async () => result,
  };
}

(async () => {
  assert.deepStrictEqual(
    await verifyBuybackSource({ query: 'x', condition: 'like_new' }),
    { ok: false, reason: 'invalid_query' },
  );
  assert.deepStrictEqual(
    await verifyBuybackSource({ query: 'iPhone 15', condition: 'unknown' }),
    { ok: false, reason: 'invalid_condition' },
  );

  const disabled = fakeSource({
    status: { configured: false, readiness: 'missing_current_provider_approval' },
  });
  assert.deepStrictEqual(
    await verifyBuybackSource({
      query: 'iPhone 15 Pro 256 GB',
      condition: 'like_new',
      source: disabled,
    }),
    {
      ok: false,
      reason: 'source_not_ready',
      readiness: 'missing_current_provider_approval',
    },
  );

  const unavailable = fakeSource({
    status: { configured: true, readiness: 'ready' },
    result: { configured: true, items: [], best: null, unavailable: true },
  });
  assert.deepStrictEqual(
    await verifyBuybackSource({
      query: 'iPhone 15 Pro 256 GB',
      condition: 'like_new',
      source: unavailable,
    }),
    { ok: false, reason: 'source_unavailable', readiness: 'ready' },
  );

  const empty = fakeSource({
    status: { configured: true, readiness: 'ready' },
    result: { configured: true, items: [], best: null },
  });
  assert.deepStrictEqual(
    await verifyBuybackSource({
      query: 'iPhone 15 Pro 256 GB',
      condition: 'like_new',
      source: empty,
    }),
    { ok: false, reason: 'no_exact_matching_offer', readiness: 'ready' },
  );

  const mixedCondition = fakeSource({
    status: { configured: true, readiness: 'ready' },
    result: {
      configured: true,
      items: [{ provider_id: 'zoxs', condition: 'used_good' }],
      best: null,
    },
  });
  assert.deepStrictEqual(
    await verifyBuybackSource({
      query: 'iPhone 15 Pro 256 GB',
      condition: 'like_new',
      source: mixedCondition,
    }),
    {
      ok: false,
      reason: 'unexpected_condition_in_result',
      readiness: 'ready',
    },
  );

  const ready = fakeSource({
    status: { configured: true, readiness: 'ready' },
    result: {
      configured: true,
      items: [
        {
          provider_id: 'ZOXS',
          condition: 'like_new',
          checked_at: '2026-09-24T08:00:00Z',
        },
        {
          provider_id: 'zoxs',
          condition: 'like_new',
          checked_at: '2026-09-24T08:01:00Z',
        },
        {
          provider_id: 'clevertronic',
          condition: 'like_new',
          checked_at: '2026-09-24T07:59:00Z',
        },
      ],
    },
  });
  assert.deepStrictEqual(
    await verifyBuybackSource({
      query: '  iPhone   15 Pro 256 GB  ',
      condition: 'like_new',
      source: ready,
    }),
    {
      ok: true,
      readiness: 'ready',
      condition: 'like_new',
      offer_count: 3,
      provider_count: 2,
      provider_ids: ['clevertronic', 'zoxs'],
      newest_checked_at: '2026-09-24T08:01:00.000Z',
    },
  );

  console.log('buyback source verification tests passed');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
