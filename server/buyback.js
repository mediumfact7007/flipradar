'use strict';

const CONDITIONS = new Set([
  'new_sealed',
  'like_new',
  'very_good',
  'used_good',
  'acceptable',
  'defective',
]);

const MAX_AGE_MS = 24 * 60 * 60 * 1000;

function text(value, max = 240) {
  return String(value || '').trim().slice(0, max);
}

function normalizeBuybackOffer(raw, { now = Date.now() } = {}) {
  if (!raw || typeof raw !== 'object') return null;
  const condition = text(raw.condition, 32);
  const price = Number(raw.price);
  const confidence = Number(raw.match_confidence);
  const checkedAt = Date.parse(raw.checked_at);
  const offerUrl = text(raw.offer_url, 1000);
  let parsedUrl;
  try { parsedUrl = new URL(offerUrl); } catch (_) { return null; }

  if (!CONDITIONS.has(condition)) return null;
  if (!Number.isFinite(price) || price < 0) return null;
  if (text(raw.currency, 8) !== 'EUR') return null;
  if (text(raw.price_kind, 40) !== 'indicative_buyback') return null;
  if (!Number.isFinite(confidence) || confidence < 0.9 || confidence > 1) return null;
  if (!Number.isFinite(checkedAt) || checkedAt > now + 5 * 60 * 1000 || now - checkedAt > MAX_AGE_MS) return null;
  if (parsedUrl.protocol !== 'https:') return null;
  if (raw.condition_uncertain === true) return null;

  const providerId = text(raw.provider_id, 80);
  const providerName = text(raw.provider_name, 120);
  const productId = text(raw.product_id, 160);
  const matchedTitle = text(raw.matched_title, 240);
  if (!providerId || !providerName || !productId || !matchedTitle) return null;

  return {
    provider_id: providerId,
    provider_name: providerName,
    product_id: productId,
    matched_title: matchedTitle,
    condition,
    price,
    currency: 'EUR',
    offer_url: parsedUrl.toString(),
    checked_at: new Date(checkedAt).toISOString(),
    price_kind: 'indicative_buyback',
    requires_inspection: raw.requires_inspection !== false,
    match_confidence: confidence,
  };
}

function normalizeBuybackPayload(payload, options) {
  const rawItems = Array.isArray(payload) ? payload : Array.isArray(payload?.items) ? payload.items : [];
  return rawItems.map((item) => normalizeBuybackOffer(item, options)).filter(Boolean);
}

function bestBuybackOffer(items, condition) {
  return items
    .filter((item) => item.condition === condition)
    .reduce((best, item) => (!best || item.price > best.price ? item : best), null);
}

module.exports = { CONDITIONS, MAX_AGE_MS, normalizeBuybackOffer, normalizeBuybackPayload, bestBuybackOffer };
