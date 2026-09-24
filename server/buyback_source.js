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
const BUYBACK_SOURCE_APPROVALS_JSON = String(process.env.BUYBACK_SOURCE_APPROVALS_JSON || '').trim();
const REQUIRED_POLICY_ACK = 'approved-feed-and-price-display-v1';
const PROVIDER_ID_PATTERN = /^[a-z0-9][a-z0-9_-]{1,63}$/;

function explicitTimestamp(value) {
  const raw = String(value || '').trim();
  if (!/(?:Z|[+-]\d{2}:?\d{2})$/.test(raw)) return null;
  const parsed = Date.parse(raw);
  return Number.isFinite(parsed) ? parsed : null;
}

function currentProviderApprovals(now = Date.now()) {
  if (!BUYBACK_SOURCE_APPROVALS_JSON) return new Map();
  let rows;
  try {
    rows = JSON.parse(BUYBACK_SOURCE_APPROVALS_JSON);
  } catch (_) {
    return new Map();
  }
  if (!Array.isArray(rows) || !rows.length) return new Map();

  const approvals = new Map();
  const seenProviderIds = new Set();
  for (const row of rows) {
    if (!row || typeof row !== 'object' || Array.isArray(row)) return new Map();
    const providerId = String(row.provider_id || '').trim().toLowerCase();
    const reference = String(row.approval_reference || '').trim();
    const reviewedAt = explicitTimestamp(row.reviewed_at);
    const validUntil = explicitTimestamp(row.valid_until);
    if (!PROVIDER_ID_PATTERN.test(providerId) || seenProviderIds.has(providerId) ||
        !reference || reference.length > 160 || reviewedAt === null ||
        validUntil === null) {
      return new Map();
    }
    seenProviderIds.add(providerId);
    if (reviewedAt > now || validUntil <= now ||
        row.feed_access !== true || row.price_display !== true ||
        row.offer_links !== true || row.provider_identity_display !== true) continue;
    approvals.set(providerId, {
      providerId,
      approvalReference: reference,
      reviewedAt,
      validUntil,
    });
  }
  return approvals;
}

function hasCurrentApproval(now = Date.now()) {
  if (BUYBACK_SOURCE_POLICY_ACK !== REQUIRED_POLICY_ACK) return false;
  return currentProviderApprovals(now).size > 0;
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
    const allowedProviders = currentProviderApprovals(now);
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

function sourceStatus(now = Date.now()) {
  const approvals = currentProviderApprovals(now);
  const isConfigured = configured(now);
  return {
    configured: isConfigured,
    mode: isConfigured ? 'approved_partner_adapter' : 'disabled',
    data_kind: 'indicative_buyback',
    max_age_hours: 24,
    minimum_match_confidence: 0.9,
    rights_gate: isConfigured ? 'approved' : 'not_approved_or_expired',
    approval_model: 'per_provider_v1',
    approved_provider_count: isConfigured ? approvals.size : 0,
  };
}

module.exports = { configured, fetchBuybackOffers, sourceStatus, hasCurrentApproval };
