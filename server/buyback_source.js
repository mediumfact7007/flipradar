'use strict';

const { normalizeBuybackPayload, bestBuybackOffer } = require('./buyback');

const BUYBACK_SOURCE_TIMEOUT_MS = Number(process.env.BUYBACK_SOURCE_TIMEOUT_MS || 6000);
const BUYBACK_SOURCE_URL = String(process.env.BUYBACK_SOURCE_URL || '').trim();
const BUYBACK_SOURCE_TOKEN = String(process.env.BUYBACK_SOURCE_TOKEN || '').trim();

function configured() {
  if (!BUYBACK_SOURCE_URL) return false;
  try {
    const url = new URL(BUYBACK_SOURCE_URL);
    return url.protocol === 'https:';
  } catch (_) {
    return false;
  }
}

async function fetchBuybackOffers(query, condition, { fetchImpl = fetch, now = Date.now() } = {}) {
  if (!configured()) return { configured: false, items: [], best: null };

  const normalizedQuery = String(query || '').trim().slice(0, 160);
  if (normalizedQuery.length < 3) return { configured: true, items: [], best: null };

  const endpoint = new URL(BUYBACK_SOURCE_URL);
  endpoint.searchParams.set('q', normalizedQuery);
  if (condition) endpoint.searchParams.set('condition', String(condition).trim().slice(0, 32));

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), BUYBACK_SOURCE_TIMEOUT_MS);
  try {
    const headers = { accept: 'application/json' };
    if (BUYBACK_SOURCE_TOKEN) headers.authorization = `Bearer ${BUYBACK_SOURCE_TOKEN}`;
    const response = await fetchImpl(endpoint, { headers, signal: controller.signal });
    if (!response.ok) return { configured: true, items: [], best: null, unavailable: true };
    const payload = await response.json();
    const items = normalizeBuybackPayload(payload, { now });
    return {
      configured: true,
      items,
      best: condition ? bestBuybackOffer(items, condition) : null,
    };
  } catch (_) {
    return { configured: true, items: [], best: null, unavailable: true };
  } finally {
    clearTimeout(timer);
  }
}

function sourceStatus() {
  return {
    configured: configured(),
    mode: configured() ? 'partner_adapter' : 'disabled',
    data_kind: 'indicative_buyback',
    max_age_hours: 24,
    minimum_match_confidence: 0.9,
  };
}

module.exports = { configured, fetchBuybackOffers, sourceStatus };
