'use strict';

const assert = require('assert');
const { filterMarketListings, listingMatchesQuery } = require('./market_quality');

assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB Titan'),
  true,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Hülle Case für Apple iPhone 15 Pro 256GB'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 128GB'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro Max 256GB'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB defekt für Bastler'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB defekt', 'Apple iPhone 15 Pro 256GB defekt'),
  true,
);
assert.strictEqual(
  listingMatchesQuery('PlayStation 5 Slim', 'Sony PS5 Slim Konsole 1TB'),
  true,
);
assert.strictEqual(
  listingMatchesQuery('PlayStation 5 Slim', 'PS5 Slim Halterung Wall Mount'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Nintendo Switch', 'Nintendo Switch OLED Konsole'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Nintendo Switch OLED', 'Nintendo Switch OLED Konsole'),
  true,
);

const filtered = filterMarketListings('Apple iPhone 15 Pro 256GB', [
  { title: 'Apple iPhone 15 Pro 256GB Titan' },
  { title: 'Apple iPhone 15 Pro 128GB' },
  { title: 'Case für Apple iPhone 15 Pro 256GB' },
  { title: 'Apple iPhone 15 Pro Max 256GB' },
]);
assert.deepStrictEqual(filtered.map((item) => item.title), ['Apple iPhone 15 Pro 256GB Titan']);

console.log('market_quality_test: ok');
