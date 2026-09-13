'use strict';

const assert = require('assert');
const { isAllowedListingUrl, parseKleinanzeigenHtml } = require('./listing_resolver');

assert.strictEqual(
  isAllowedListingUrl('https://www.kleinanzeigen.de/s-anzeige/nintendo-switch-oled/1234567890-279-1234'),
  true,
);
assert.strictEqual(isAllowedListingUrl('https://www.kleinanzeigen.de/s-nintendo-switch/k0'), false);
assert.strictEqual(isAllowedListingUrl('https://example.com/s-anzeige/nintendo-switch/123'), false);
assert.strictEqual(isAllowedListingUrl('http://www.kleinanzeigen.de/s-anzeige/nintendo-switch/123'), false);

const jsonLdHtml = `
<html>
<head>
<meta property="og:title" content="Nintendo Switch OLED | Kleinanzeigen">
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "Nintendo Switch OLED weiß mit OVP",
  "offers": {
    "@type": "Offer",
    "price": "219,00",
    "priceCurrency": "EUR"
  }
}
</script>
</head>
<body></body>
</html>`;
const parsedJsonLd = parseKleinanzeigenHtml(jsonLdHtml);
assert.strictEqual(parsedJsonLd.title, 'Nintendo Switch OLED weiß mit OVP');
assert.strictEqual(parsedJsonLd.price, 219);
assert.strictEqual(parsedJsonLd.currency, 'EUR');

const metaHtml = `
<html><head>
<meta content="Nintendo Switch OLED - Kleinanzeigen" property="og:title">
<meta content="184.50" property="product:price:amount">
<meta property="product:price:currency" content="EUR">
</head></html>`;
const parsedMeta = parseKleinanzeigenHtml(metaHtml);
assert.strictEqual(parsedMeta.title, 'Nintendo Switch OLED');
assert.strictEqual(parsedMeta.price, 184.5);
assert.strictEqual(parsedMeta.currency, 'EUR');

console.log('listing_resolver_test: ok');
