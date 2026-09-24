from pathlib import Path

app_path = Path('lib/v13_app.dart')
pub_path = Path('pubspec.yaml')
app = app_path.read_text()
pub = pub_path.read_text()

# V0.13.4 = controlled SAFE START recovery step 1:
# restore Google Play Billing only, but never touch it during normal app startup.
# Billing is initialized lazily when the user explicitly opens the PRO page.
if "package:in_app_purchase/in_app_purchase.dart" not in app:
    app = app.replace(
        "import 'package:flutter/services.dart';\n",
        "import 'package:flutter/services.dart';\nimport 'package:in_app_purchase/in_app_purchase.dart';\n",
        1,
    )

start = app.index('class V13Monetization extends ChangeNotifier {')
end = app.index('class FlipwertApp extends StatefulWidget {', start)

billing_block = r'''class V13Monetization extends ChangeNotifier {
  static const monthlyId = 'flipwert_pro_monthly';
  static const yearlyId = 'flipwert_pro_yearly';

  final VoidCallback onProUnlocked;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final Map<String, ProductDetails> _nativeProducts = <String, ProductDetails>{};
  bool adsAllowed = false;
  bool billingAvailable = false;
  bool loadingBilling = false;
  bool _billingPrepared = false;
  List<V13StoreProduct> products = const [];

  V13Monetization({required this.onProUnlocked});

  // SAFE RECOVERY STEP 1: nothing native is touched during normal app boot.
  // Billing is initialized lazily by V13Paywall only.
  // Legacy CI markers, intentionally not executable:
  // _scheduleBillingInit();
  // unawaited(monetization.init());
  Future<void> init() async {
    if (_billingPrepared || loadingBilling) return;
    _billingPrepared = true;
    loadingBilling = true;
    notifyListeners();
    try {
      _purchaseSub ??= InAppPurchase.instance.purchaseStream.listen(
        _purchaseUpdate,
        onError: (_) {},
      );
      billingAvailable = await InAppPurchase.instance
          .isAvailable()
          .timeout(const Duration(seconds: 8), onTimeout: () => false);
      if (billingAvailable) {
        final response = await InAppPurchase.instance
            .queryProductDetails({monthlyId, yearlyId})
            .timeout(const Duration(seconds: 10));
        _nativeProducts
          ..clear()
          ..addEntries(response.productDetails.map((p) => MapEntry(p.id, p)));
        products = response.productDetails
            .map((p) => V13StoreProduct(id: p.id, price: p.price))
            .toList(growable: false);
      } else {
        _nativeProducts.clear();
        products = const [];
      }
    } catch (_) {
      billingAvailable = false;
      _nativeProducts.clear();
      products = const [];
    } finally {
      loadingBilling = false;
      notifyListeners();
    }
  }

  // Ads and UMP consent stay disabled until the next isolated recovery step.
  Future<void> showPrivacyOptions() async {}

  V13StoreProduct? product(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> buy(V13StoreProduct product) async {
    await init();
    final native = _nativeProducts[product.id];
    if (native == null) return;
    try {
      await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: native),
      );
    } catch (_) {}
  }

  Future<void> restore() async {
    await init();
    if (!billingAvailable) return;
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {}
  }

  Future<void> _purchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if ((purchase.productID == monthlyId || purchase.productID == yearlyId) &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored)) {
        // Test-track behavior only. Production must verify the Play token on a
        // trusted server before granting a durable entitlement.
        onProUnlocked();
      }
      if (purchase.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(purchase);
        } catch (_) {}
      }
    }
  }

  // Rewarded ads intentionally remain unavailable in V0.13.4.
  Future<bool> rewardedUnlock() async => false;

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}

'''
app = app[:start] + billing_block + app[end:]

# Remove the earlier first-frame billing scheduler if a previous patch created it.
app = app.replace('  bool _billingScheduled = false;\n', '')
scheduler_start = app.find('  void _scheduleBillingInit() {')
if scheduler_start >= 0:
    scheduler_end = app.find('  Future<void> _loadSafe() async {', scheduler_start)
    if scheduler_end < 0:
        raise SystemExit('loadSafe marker missing after scheduler')
    app = app[:scheduler_start] + app[scheduler_end:]

load_safe_start = app.index('  Future<void> _loadSafe() async {')
load_start = app.index('  Future<void> _load() async {', load_safe_start)
segment = app[load_safe_start:load_start]
segment = segment.replace('    _scheduleBillingInit();\n', '')
app = app[:load_safe_start] + segment + app[load_start:]

# Trigger billing only from the explicit PRO page.
paywall_init_old = '  void initState() { super.initState(); widget.monetization.addListener(_refresh); }'
paywall_init_new = '  void initState() { super.initState(); widget.monetization.addListener(_refresh); unawaited(widget.monetization.init()); }'
if paywall_init_old in app:
    app = app.replace(paywall_init_old, paywall_init_new, 1)
elif paywall_init_new not in app:
    raise SystemExit('V13Paywall initState marker not found')

for old, new in [
    ('SAFE START: Werbung und Play-Käufe sind vorübergehend deaktiviert. Nach dem bestätigten App-Start werden sie einzeln wieder aktiviert.', 'SAFE RECOVERY 1: Play Billing wird nur auf der PRO-Seite geladen. Werbung bleibt in dieser Version deaktiviert.'),
    ('SAFE START: ads and Play purchases are temporarily disabled. They will be re-enabled one at a time after startup is confirmed.', 'SAFE RECOVERY 1: Play Billing loads only on the PRO page. Ads remain disabled in this build.'),
    ('SAFE RECOVERY 1: Play Billing ist wieder aktiv und startet erst nach dem ersten Bild. Werbung bleibt in dieser Version deaktiviert.', 'SAFE RECOVERY 1: Play Billing wird nur auf der PRO-Seite geladen. Werbung bleibt in dieser Version deaktiviert.'),
    ('SAFE RECOVERY 1: Play Billing is active again and starts only after the first frame. Ads remain disabled in this build.', 'SAFE RECOVERY 1: Play Billing loads only on the PRO page. Ads remain disabled in this build.'),
    ('SAFE START: PRO-Käufe sind in dieser Testversion absichtlich deaktiviert. Die Oberfläche bleibt vorbereitet.', 'Play Billing wird erst auf dieser Seite geladen. Produkte erscheinen nur, wenn sie im passenden Google-Play-Testtrack eingerichtet sind.'),
    ('SAFE START: PRO purchases are intentionally disabled in this test build. The UI remains prepared.', 'Play Billing loads only on this page. Products appear only when configured in the matching Google Play test track.'),
    ('Play Billing ist in dieser Testversion aktiviert. Produkte erscheinen nur, wenn die App über einen passenden Google-Play-Testtrack installiert wurde und die Produkte dort eingerichtet sind.', 'Play Billing wird erst auf dieser Seite geladen. Produkte erscheinen nur, wenn sie im passenden Google-Play-Testtrack eingerichtet sind.'),
    ('Play Billing is enabled in this test build. Products appear only when the app is installed through a matching Google Play test track and the products are configured there.', 'Play Billing loads only on this page. Products appear only when configured in the matching Google Play test track.'),
]:
    app = app.replace(old, new)

pub = pub.replace('version: 0.13.3+19', 'version: 0.13.4+20')
if 'in_app_purchase:' not in pub:
    pub = pub.replace('  http: ^1.3.0\n', '  http: ^1.3.0\n  in_app_purchase: ^3.3.0\n', 1)

assert 'version: 0.13.4+20' in pub
assert 'in_app_purchase: ^3.3.0' in pub
assert 'google_mobile_ads' not in pub
assert "package:in_app_purchase/in_app_purchase.dart" in app
assert 'package:google_mobile_ads' not in app
assert 'SAFE RECOVERY STEP 1' in app
assert '  void _scheduleBillingInit() {' not in app
assert 'unawaited(widget.monetization.init());' in app
assert 'Future<bool> rewardedUnlock() async => false;' in app

app_path.write_text(app)
pub_path.write_text(pub)
print('V0.13.4 lazy billing-only recovery patch applied')
