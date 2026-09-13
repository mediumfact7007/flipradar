from pathlib import Path

p = Path('lib/v13_app.dart')
s = p.read_text()

old_available = """      billingAvailable = await InAppPurchase.instance
          .isAvailable()
          .timeout(const Duration(seconds: 8), onTimeout: () => false);
"""
new_available = """      billingAvailable = await InAppPurchase.instance.isAvailable();
"""
old_products = """        final response = await InAppPurchase.instance
            .queryProductDetails({monthlyId, yearlyId})
            .timeout(const Duration(seconds: 10));
"""
new_products = """        final response = await InAppPurchase.instance.queryProductDetails({monthlyId, yearlyId});
"""

s = s.replace(old_available, new_available)
s = s.replace(old_products, new_products)

assert '.timeout(const Duration(seconds: 8)' not in s
assert '.timeout(const Duration(seconds: 10)' not in s
assert 'billingAvailable = await InAppPurchase.instance.isAvailable();' in s

p.write_text(s)
print('V0.13.4 billing startup timers removed')
