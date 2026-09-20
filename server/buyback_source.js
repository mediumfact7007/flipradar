'use strict';

const { CONDITIONS, normalizeBuybackPayload, bestBuybackOffer } = require('./buyback');

const configuredTimeoutMs = Number(process.env.BUYBACK_SOURCE_TIMEOUT_MS || 6000);
const BUYBACK_SOURCE_TIMEOUT_MS = Number.isFinite(configuredTimeoutMs)
  ? Math.min(15000, Math.max(1000, configuredTimeoutMs))
  : 6000;
const BUYBACK_SOURCE_URL = String(process.env.BUYBACK_SOURCE_URL || '').trim();
const BUYBACK_SOURCE_TOKEN = String(process.env.BUYBACK_SOURCE_TOKEN || '').trim();

function configured() {
  if (!BUYBACK_SOURCE_URL) return false;
  try {
    const url = new URL(BUYBACK_SOURCE_URL);
    return url.protocol === 'https:' && !url.username && !url.password;
  } catch (_) {
    return false;
  }
}

async function fetchBuybackOffers(query, condition, { fetchImpl = fetch, now = Date.now() } = {}) {
  if (!configured()) return { configured: false, items: [], best: null };

  const normalizedQuery = String(query || '').trim().slice(0, 160);
  if (normalizedQuery.length < 3) return { configured: true, items: [], best: null };
  const normalizedCondition = String(condition || '').trim().slice(0, 32);
  if (normalizedCondition && !CONDITIONS.has(normalizedCondition)) {
    return { configured: true, items: [], best: null };
  }

  const endpoint = new URL(BUYBACK_SOURCE_URL);
  endpoint.searchParams.set('q', normalizedQuery);
  if (normalizedCondition) endpoint.searchParams.set('condition', normalizedCondition);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), BUYBACK_SOURCE_TIMEOUT_MS);
  try {
    const headers = { accept: 'application/json' };
    if (BUYBACK_SOURCE_TOKEN) headers.authorization = `Bearer ${BUYBACK_SOURCE_TOKEN}`;
    const response = await fetchImpl(endpoint, { headers, signal: controller.signal, redirect: 'error' });
    if (!response.ok) return { configured: true, items: [], best: null, unavailable: true };
    const contentType = String(response.headers?.get?.('content-type') || '').toLowerCase();
    if (contentType && !contentType.includes('application/json')) {
      return { configured: true, items: [], best: null, unavailable: true };
    }
    const payload = await response.json();
    const items = normalizeBuybackPayload(payload, { now });
    return {
      configured: true,
      items,
      best: normalizedCondition ? bestBuybackOffer(items, normalizedCondition) : null,
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
