import re
from pathlib import Path

app_path = Path('lib/v13_app.dart')
pub_path = Path('pubspec.yaml')
server_path = Path('server/index.js')

app = app_path.read_text()
pub = pub_path.read_text()
server = server_path.read_text()

# Backend: reject obvious accessory/defect/wrong-variant eBay results before
# they can reach the mobile valuation layer.
import_line = "const { filterMarketListings } = require('./market_quality');\n"
if import_line not in server:
    server = server.replace(
        "const { URL, URLSearchParams } = require('url');\n",
        "const { URL, URLSearchParams } = require('url');\n" + import_line,
        1,
    )

old_ebay = """  const data = await response.json();
  return (data.itemSummaries || [])
    .map((item) => {
      const buyingOptions = Array.isArray(item.buyingOptions) ? item.buyingOptions : [];
      if (!buyingOptions.includes('FIXED_PRICE')) return null;
      const currency = item.price?.currency || 'EUR';
      if (currency !== 'EUR') return null;

      const shippingValues = (item.shippingOptions || [])
        .map((option) => Number(option?.shippingCost?.value))
        .filter((value) => Number.isFinite(value) && value >= 0);
      const shipping = shippingValues.length > 0 ? Math.min(...shippingValues) : 0;

      return {
        source: 'ebay_de',
        title: item.title || 'eBay listing',
        price: money(item.price?.value),
        shipping,
        currency,
        condition: item.condition || 'USED',
        url: item.itemWebUrl || '',
        live: EBAY_ENV === 'production',
        environment: EBAY_ENV,
      };
    })
    .filter((item) => item && item.price > 0);
"""
new_ebay = """  const data = await response.json();
  const items = (data.itemSummaries || [])
    .map((item) => {
      const buyingOptions = Array.isArray(item.buyingOptions) ? item.buyingOptions : [];
      if (!buyingOptions.includes('FIXED_PRICE')) return null;
      const currency = item.price?.currency || 'EUR';
      if (currency !== 'EUR') return null;

      const shippingValues = (item.shippingOptions || [])
        .map((option) => Number(option?.shippingCost?.value))
        .filter((value) => Number.isFinite(value) && value >= 0);
      const shipping = shippingValues.length > 0 ? Math.min(...shippingValues) : 0;

      return {
        source: 'ebay_de',
        title: item.title || 'eBay listing',
        price: money(item.price?.value),
        shipping,
        currency,
        condition: item.condition || 'USED',
        url: item.itemWebUrl || '',
        live: EBAY_ENV === 'production',
        environment: EBAY_ENV,
      };
    })
    .filter((item) => item && item.price > 0);
  return filterMarketListings(q, items);
"""
if old_ebay in server:
    server = server.replace(old_ebay, new_ebay, 1)
elif 'return filterMarketListings(q, items);' not in server:
    raise SystemExit('eBay result mapping block not found')

# App: use robust price fences. With 3-4 values, remove only severe ratio
# outliers. With 5+ values, combine ratio fences with an IQR fence.
helper = r'''List<double> v13CleanMarketValues(List<double> raw) {
  final values = raw.where((e) => e.isFinite && e > 0).toList()..sort();
  if (values.length < 3) return values;

  double median(List<double> input) {
    final mid = input.length ~/ 2;
    return input.length.isOdd
        ? input[mid]
        : (input[mid - 1] + input[mid]) / 2;
  }

  double quantile(List<double> input, double q) {
    if (input.length == 1) return input.first;
    final position = (input.length - 1) * q;
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return input[lower];
    final fraction = position - lower;
    return input[lower] + (input[upper] - input[lower]) * fraction;
  }

  final med = median(values);
  final ratioFiltered = values
      .where((v) => v >= med * .45 && v <= med * 1.85)
      .toList();
  final working = ratioFiltered.length >= 2 ? ratioFiltered : values;
  if (working.length < 5) return working;

  final q1 = quantile(working, .25);
  final q3 = quantile(working, .75);
  final iqr = q3 - q1;
  if (iqr <= 0) return working;

  final lowerFence = math.max(med * .45, q1 - iqr * 1.5);
  final upperFence = math.min(med * 1.85, q3 + iqr * 1.5);
  final filtered = working
      .where((v) => v >= lowerFence && v <= upperFence)
      .toList();
  return filtered.length >= 3 ? filtered : working;
}

'''
marker = 'enum V13Decision { waiting, buy, negotiate, skip }\n'
if 'List<double> v13CleanMarketValues' not in app:
    if marker not in app:
        raise SystemExit('V13 decision marker not found')
    app = app.replace(marker, helper + marker, 1)

old_clean = """  List<double> _clean(List<double> raw) {
    final values = [...raw]..sort();
    if (values.length < 5) return values;
    final med = _median(values)!;
    final filtered = values.where((v) => v >= med * .60 && v <= med * 1.60).toList();
    return filtered.length >= 3 ? filtered : values;
  }
"""
new_clean = """  List<double> _clean(List<double> raw) => v13CleanMarketValues(raw);
"""
if old_clean in app:
    app = app.replace(old_clean, new_clean, 1)
elif 'v13CleanMarketValues(raw)' not in app:
    raise SystemExit('V13 _clean block not found')

# Bump only the real version line, never compatibility comments used by older
# regression tests.
pub = re.sub(
    r'^version: 0\.14\.2\+25$',
    'version: 0.14.3+26',
    pub,
    count=1,
    flags=re.MULTILINE,
)

assert re.search(r'^version: 0\.14\.3\+26$', pub, flags=re.MULTILINE)
assert "require('./market_quality')" in server
assert 'return filterMarketListings(q, items);' in server
assert 'List<double> v13CleanMarketValues' in app
assert 'v13CleanMarketValues(raw)' in app

server_path.write_text(server)
app_path.write_text(app)
pub_path.write_text(pub)
print('V0.14.3 market-quality filters applied')
