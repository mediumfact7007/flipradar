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
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB funktioniert nicht'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB ohne Funktion'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB nicht funktionsfähig'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB does not work'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB funktioniert nicht', 'Apple iPhone 15 Pro 256GB funktioniert nicht'),
  true,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB nur Karton'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB nur Verpackung'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB packaging only'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB Karton ohne Gerät'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB Verpackung ohne Gerät'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB box without device'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB box no device'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB original box only'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB empty original box'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB leere Originalverpackung'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB Originalverpackung leer'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB leere OVP'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB OVP leer'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB nur OVP'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB OVP only'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB OVP vollständig'),
  true,
);
assert.strictEqual(
  listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB empty packaging'),
  false,
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
assert.strictEqual(
  listingMatchesQuery('Xbox Series X', 'Microsoft Xbox Series X 1TB Konsole'),
  true,
);
assert.strictEqual(
  listingMatchesQuery('Xbox Series X', 'Microsoft Xbox Series S 512GB Konsole'),
  false,
);
assert.strictEqual(
  listingMatchesQuery('Xbox Series S', 'Microsoft Xbox Series X 1TB Konsole'),
  false,
);

const filtered = filterMarketListings('Apple iPhone 15 Pro 256GB', [
  { title: 'Apple iPhone 15 Pro 256GB Titan' },
  { title: 'Apple iPhone 15 Pro 128GB' },
  { title: 'Case für Apple iPhone 15 Pro 256GB' },
  { title: 'Apple iPhone 15 Pro Max 256GB' },
  { title: 'Apple iPhone 15 Pro 256GB funktioniert nicht' },
  { title: 'Apple iPhone 15 Pro 256GB nur Karton' },
  { title: 'Apple iPhone 15 Pro 256GB Karton ohne Gerät' },
  { title: 'Apple iPhone 15 Pro 256GB box without device' },
  { title: 'Apple iPhone 15 Pro 256GB original box only' },
  { title: 'Apple iPhone 15 Pro 256GB Originalverpackung leer' },
  { title: 'Apple iPhone 15 Pro 256GB OVP leer' },
  { title: 'Apple iPhone 15 Pro 256GB nur OVP' },
]);
assert.deepStrictEqual(filtered.map((item) => item.title), ['Apple iPhone 15 Pro 256GB Titan']);

console.log('market_quality_test: ok');
