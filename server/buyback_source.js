'use strict';

const { CONDITIONS, normalizeBuybackPayload, bestBuybackOffer } = require('./buyback');
const { matchesBuybackQuery } = require('./buyback_match');

const configuredTimeoutMs = Number(process.env.BUYBACK_SOURCE_TIMEOUT_MS || 6000);
const BUYBACK_SOURCE_TIMEOUT_MS = Number.isFinite(configuredTimeoutMs)
  ? Math.min(15000, Math.max(1000, configuredTimeoutMs))
  : 6000;
const BUYBACK_SOURCE_URL = String(process.env.BUYBACK_SOURCE_URL || '').trim();
const BUYBACK_SOURCE_TOKEN = String(process.env.BUYBACK_SOURCE_TOKEN || '').trim();
const BUYBACK_SOURCE_POLICY_ACK = String(process.env.BUYBACK_SOURCE_POLICY_ACK || '').trim();
const BUYBACK_SOURCE_PROVIDER_IDS = String(process.env.BUYBACK_SOURCE_PROVIDER_IDS || '').trim();
const BUYBACK_SOURCE_APPROVAL_VALID_UNTIL = String(process.env.BUYBACK_SOURCE_APPROVAL_VALID_UNTIL || '').trim();
const REQUIRED_POLICY_ACK = 'approved-feed-and-price-display-v1';

function approvedProviderIds() {
  const values = BUYBACK_SOURCE_PROVIDER_IDS
    .split(',')
    .map((value) => value.trim().toLowerCase())
    .filter(Boolean);
  if (!values.length || values.some((value) => !/^[a-z0-9][a-z0-9_-]{1,63}$/.test(value))) {
    return new Set();
  }
  return new Set(values);
}

function hasCurrentApproval(now = Date.now()) {
  if (BUYBACK_SOURCE_POLICY_ACK !== REQUIRED_POLICY_ACK) return false;
  if (!approvedProviderIds().size) return false;
  if (!/(?:Z|[+-]\d{2}:?\d{2})$/.test(BUYBACK_SOURCE_APPROVAL_VALID_UNTIL)) return false;
  const validUntil = Date.parse(BUYBACK_SOURCE_APPROVAL_VALID_UNTIL);
  return Number.isFinite(validUntil) && validUntil > now;
}

function hasPublicSourceHost(hostname) {
  const host = String(hostname || '').toLowerCase().replace(/^\[|\]$/g, '');
  if (!host || host === 'localhost' || host.endsWith('.local') || host === '::' || host === '::1') return false;
  if (host.includes(':')) {
    return !host.startsWith('::ffff:') && !host.startsWith('fc') && !host.startsWith('fd') &&
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

function configured(now = Date.now()) {
  if (!BUYBACK_SOURCE_URL || !hasCurrentApproval(now)) return false;
  try {
    const url = new URL(BUYBACK_SOURCE_URL);
    return url.protocol === 'https:' && !url.username && !url.password && hasPublicSourceHost(url.hostname);
  } catch (_) {
    return false;
  }
}

async function fetchBuybackOffers(query, condition, { fetchImpl = fetch, now = Date.now() } = {}) {
  if (!configured(now)) return { configured: false, items: [], best: null };

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
    const rawItems = Array.isArray(payload) ? payload : Array.isArray(payload?.items) ? payload.items : [];
    const allowedProviders = approvedProviderIds();
    const items = normalizeBuybackPayload(rawItems.filter((item) => {
      const providerId = String(item?.provider_id || '').trim().toLowerCase();
      return allowedProviders.has(providerId) && matchesBuybackQuery(normalizedQuery, item);
    }), { now });
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
  const isConfigured = configured();
  return {
    configured: isConfigured,
    mode: isConfigured ? 'approved_partner_adapter' : 'disabled',
    data_kind: 'indicative_buyback',
    max_age_hours: 24,
    minimum_match_confidence: 0.9,
    rights_gate: isConfigured ? 'approved' : 'not_approved_or_expired',
    approved_provider_count: isConfigured ? approvedProviderIds().size : 0,
  };
}

module.exports = { configured, fetchBuybackOffers, sourceStatus, hasCurrentApproval };
