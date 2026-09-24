'use strict';

const { CONDITIONS } = require('./buyback');
const defaultSource = require('./buyback_source');

function cleanQuery(value) {
  return String(value || '').trim().replace(/\s+/g, ' ').slice(0, 160);
}

async function verifyBuybackSource({
  query,
  condition,
  source = defaultSource,
} = {}) {
  const normalizedQuery = cleanQuery(query);
  const normalizedCondition = String(condition || '').trim();

  if (normalizedQuery.length < 3) {
    return { ok: false, reason: 'invalid_query' };
  }
  if (!CONDITIONS.has(normalizedCondition)) {
    return { ok: false, reason: 'invalid_condition' };
  }

  const status = source.sourceStatus();
  if (!status.configured) {
    return {
      ok: false,
      reason: 'source_not_ready',
      readiness: status.readiness || 'unknown',
    };
  }

  const result = await source.fetchBuybackOffers(
    normalizedQuery,
    normalizedCondition,
  );
  if (result.unavailable === true) {
    return { ok: false, reason: 'source_unavailable', readiness: 'ready' };
  }

  const items = Array.isArray(result.items) ? result.items : [];
  if (!items.length) {
    return {
      ok: false,
      reason: 'no_exact_matching_offer',
      readiness: 'ready',
    };
  }
  if (items.some((item) => item.condition !== normalizedCondition)) {
    return {
      ok: false,
      reason: 'unexpected_condition_in_result',
      readiness: 'ready',
    };
  }

  const providers = [...new Set(items.map((item) =>
    String(item.provider_id || '').trim().toLowerCase()).filter(Boolean))].sort();
  const checkedTimes = items
    .map((item) => Date.parse(String(item.checked_at || '')))
    .filter(Number.isFinite);

  return {
    ok: true,
    readiness: 'ready',
    condition: normalizedCondition,
    offer_count: items.length,
    provider_count: providers.length,
    provider_ids: providers,
    newest_checked_at: checkedTimes.length
      ? new Date(Math.max(...checkedTimes)).toISOString()
      : null,
  };
}

async function main() {
  const result = await verifyBuybackSource({
    query: process.env.BUYBACK_VERIFY_QUERY,
    condition: process.env.BUYBACK_VERIFY_CONDITION,
  });
  process.stdout.write(`${JSON.stringify(result)}\n`);
  if (!result.ok) process.exitCode = 1;
}

if (require.main === module) {
  main().catch(() => {
    process.stdout.write('{"ok":false,"reason":"verification_failed"}\n');
    process.exitCode = 1;
  });
}

module.exports = { verifyBuybackSource };
