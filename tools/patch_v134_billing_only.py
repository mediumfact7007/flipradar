from pathlib import Path

app_path = Path('lib/v13_app.dart')
pub_path = Path('pubspec.yaml')

app = app_path.read_text()
pub = pub_path.read_text()

# V0.13.4 is the first controlled SAFE START recovery step:
# Play Billing returns, but AdMob/UMP stays completely absent.
if "package:in_app_purchase/in_app_purchase.dart" not in app:
    app = app.replace(
        "import 'package:flutter/services.dart';\n",
        "import 'package:flutter/services.dart';\nimport 'package:in_app_purchase/in_app_purchase.dart';\n",
        1,
    )

start = app.index('class V13Monetization extends ChangeNotifier {')
end = app.index('class FlipRadarV13App extends StatefulWidget {', start)

billing_block = r'''class V13Monetization extends ChangeNotifier {
  static const monthlyId = 'flipradar_pro_monthly';
  static const yearlyId = 'flipradar_pro_yearly';

  final VoidCallback onProUnlocked;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final Map<String, ProductDetails> _nativeProducts = <String, ProductDetails>{};
  bool adsAllowed = false;
  bool billingAvailable = false;
  bool loadingBilling = true;
  List<V13StoreProduct> products = const [];

  V13Monetization({required this.onProUnlocked});

  // SAFE RECOVERY STEP 1: Billing is initialized only after the first frame.
  // Ads/consent remain disabled so any startup regression stays attributable.
  Future<void> init() async {
    if (_purchaseSub != null) return;
    try {
      _purchaseSub = InAppPurchase.instance.purchaseStream.listen(
        _purchaseUpdate,
        onError: (_) {},
      );
    } catch (_) {}
    await _initBilling();
  }

  Future<void> _initBilling() async {
    loadingBilling = true;
    notifyListeners();
    try {
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
    }
    loadingBilling = false;
    notifyListeners();
  }

  // Ad privacy remains a no-op until SAFE RECOVERY STEP 2.
  Future<void> showPrivacyOptions() async {}

  V13StoreProduct? product(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> buy(V13StoreProduct product) async {
    final native = _nativeProducts[product.id];
    if (native == null) return;
    try {
      await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: native),
      );
    } catch (_) {}
  }

  Future<void> restore() async {
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
        // Test-track behavior. Production launch must verify the Play token on
        // a trusted server before granting the durable entitlement.
        onProUnlocked();
      }
      if (purchase.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(purchase);
        } catch (_) {}
      }
    }
  }

  // Ads remain intentionally disabled in V0.13.4.
  Future<bool> rewardedUnlock() async => false;

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}

'''

app = app[:start] + billing_block + app[end:]

first_frame_marker = """      sources = loadedSources;\n      loading = false;\n    });\n  }\n\n  void _unlockPro()"""
first_frame_replacement = """      sources = loadedSources;\n      loading = false;\n    });\n    WidgetsBinding.instance.addPostFrameCallback((_) {\n      unawaited(monetization.init());\n    });\n  }\n\n  void _unlockPro()"""
if first_frame_marker in app:
    app = app.replace(first_frame_marker, first_frame_replacement, 1)
elif 'unawaited(monetization.init());' not in app:
    raise SystemExit('Could not place post-frame billing initialization')

app = app.replace(
    "SAFE START: Werbung und Play-Käufe sind vorübergehend deaktiviert. Nach dem bestätigten App-Start werden sie einzeln wieder aktiviert.",
    "SAFE RECOVERY 1: Play Billing ist wieder aktiv und startet erst nach dem ersten Bild. Werbung bleibt in dieser Version deaktiviert.",
)
app = app.replace(
    "SAFE START: ads and Play purchases are temporarily disabled. They will be re-enabled one at a time after startup is confirmed.",
    "SAFE RECOVERY 1: Play Billing is active again and starts only after the first frame. Ads remain disabled in this build.",
)
app = app.replace(
    "SAFE START: PRO-Käufe sind in dieser Testversion absichtlich deaktiviert. Die Oberfläche bleibt vorbereitet.",
    "Play Billing ist in dieser Testversion aktiviert. Produkte erscheinen nur, wenn die App über einen passenden Google-Play-Testtrack installiert wurde und die Produkte dort eingerichtet sind.",
)
app = app.replace(
    "SAFE START: PRO purchases are intentionally disabled in this test build. The UI remains prepared.",
    "Play Billing is enabled in this test build. Products appear only when the app is installed through a matching Google Play test track and the products are configured there.",
)

pub = pub.replace('version: 0.13.3+19', 'version: 0.13.4+20')
if 'in_app_purchase:' not in pub:
    pub = pub.replace('  http: ^1.3.0\n', '  http: ^1.3.0\n  in_app_purchase: ^3.3.0\n', 1)

assert "version: 0.13.4+20" in pub
assert "in_app_purchase: ^3.3.0" in pub
assert "google_mobile_ads" not in pub
assert "package:in_app_purchase/in_app_purchase.dart" in app
assert "package:google_mobile_ads" not in app
assert "SAFE RECOVERY STEP 1" in app
assert "unawaited(monetization.init());" in app
assert "Future<bool> rewardedUnlock() async => false;" in app

app_path.write_text(app)
pub_path.write_text(pub)
print('V0.13.4 billing-only recovery patch applied')
