'use strict';

const { CONDITIONS, normalizeBuybackPayload, bestBuybackOffer } = require('./buyback');

const configuredTimeoutMs = Number(process.env.BUYBACK_SOURCE_TIMEOUT_MS || 6000);
const BUYBACK_SOURCE_TIMEOUT_MS = Number.isFinite(configuredTimeoutMs)
  ? Math.min(15000, Math.max(1000, configuredTimeoutMs))
  : 6000;
const BUYBACK_SOURCE_URL = String(process.env.BUYBACK_SOURCE_URL || '').trim();
const BUYBACK_SOURCE_TOKEN = String(process.env.BUYBACK_SOURCE_TOKEN || '').trim();

function hasPublicSourceHost(hostname) {
  const host = String(hostname || '').toLowerCase();
  if (!host || host === 'localhost' || host.endsWith('.local') || host === '::' || host === '::1') return false;
  if (host.includes(':')) {
    return !host.startsWith('fc') && !host.startsWith('fd') &&
      !host.startsWith('fe8') && !host.startsWith('fe9') &&
      !host.startsWith('fea') && !host.startsWith('feb');
  }
  const octets = host.split('.');
  if (octets.length !== 4) return true;
  const parts = octets.map(Number);
  if (parts.some((part) => !Number.isInteger(part) || part < 0 || part > 255)) return false;
  const [a, b, c] = parts;
  return !(a === 0 || a === 10 || a === 127 ||
    (a === 100 && b >= 64 && b <= 127) ||
    (a === 169 && b === 254) ||
    (a === 172 && b >= 16 && b <= 31) ||
    (a === 192 && b === 0 && (c === 0 || c === 2)) ||
    (a === 192 && b === 168) ||
    (a === 198 && (b === 18 || b === 19)) ||
    (a === 198 && b === 51 && c === 100) ||
    (a === 203 && b === 0 && c === 113) || a >= 224);
}

function configured() {
  if (!BUYBACK_SOURCE_URL) return false;
  try {
    const url = new URL(BUYBACK_SOURCE_URL);
    return url.protocol === 'https:' && !url.username && !url.password && hasPublicSourceHost(url.hostname);
  } catch (_) {
    return false;
  }
}

async function fetchBuybackOffers(query, condition, { fetchImpl = fetch, now = Date.now() } = {}) {
  if (!configured()) return { configured: false, items: [], best: null };

  const normalizedQuery = String(query || '').trim().replace(/\s+/g, ' ').slice(0, 160);
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
