from pathlib import Path

app = Path('lib/v13_app.dart')
text = app.read_text()

# V0.13 introduced AdMob and Play Billing at the same time. The physical-device
# startup crash must be isolated before either SDK is re-enabled. Keep the UI
# contract, but remove both native SDKs from this SAFE build.
text = text.replace("import 'dart:io';\n", '')
text = text.replace("import 'package:google_mobile_ads/google_mobile_ads.dart';\n", '')
text = text.replace("import 'package:in_app_purchase/in_app_purchase.dart';\n", '')

start = text.index('class V13Monetization extends ChangeNotifier {')
end = text.index('class FlipRadarV13App extends StatefulWidget {')
text = text[:start] + r'''class V13StoreProduct {
  final String id;
  final String price;
  const V13StoreProduct({required this.id, required this.price});
}

class V13Monetization extends ChangeNotifier {
  static const monthlyId = 'flipradar_pro_monthly';
  static const yearlyId = 'flipradar_pro_yearly';

  final VoidCallback onProUnlocked;
  bool adsAllowed = false;
  bool billingAvailable = false;
  bool loadingBilling = false;
  List<V13StoreProduct> products = const [];

  V13Monetization({required this.onProUnlocked});

  // SAFE START: no native ads/billing SDK is touched. This deliberately keeps
  // startup independent from Google Play Services and ad-consent state.
  Future<void> init() async {}
  Future<void> showPrivacyOptions() async {}

  V13StoreProduct? product(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> buy(V13StoreProduct product) async {}
  Future<void> restore() async {}
  Future<bool> rewardedUnlock() async => false;
}

''' + text[end:]

banner_start = text.index('class V13BannerAd extends StatefulWidget {')
banner_end = text.index('class _V13Pill extends StatelessWidget {')
text = text[:banner_start] + r'''class V13BannerAd extends StatelessWidget {
  final V13Monetization monetization;
  const V13BannerAd({super.key, required this.monetization});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

''' + text[banner_end:]

text = text.replace(
    'Test-APK: AdMob verwendet offizielle Google-Testanzeigen. Für Einnahmen müssen später deine AdMob-IDs eingesetzt werden.',
    'SAFE START: Werbung und Play-Käufe sind vorübergehend deaktiviert. Nach dem bestätigten App-Start werden sie einzeln wieder aktiviert.',
)
text = text.replace(
    'Test APK: AdMob uses official Google test ads. Your AdMob IDs are required for real revenue.',
    'SAFE START: ads and Play purchases are temporarily disabled. They will be re-enabled one at a time after startup is confirmed.',
)
text = text.replace(
    'In dieser Test-APK sind die Play-Store-Produkte noch nicht veröffentlicht. Die Kaufoberfläche ist bereits technisch angebunden.',
    'SAFE START: PRO-Käufe sind in dieser Testversion absichtlich deaktiviert. Die Oberfläche bleibt vorbereitet.',
)
text = text.replace(
    'The Play Store products are not published for this test APK yet. The purchase flow is already integrated.',
    'SAFE START: PRO purchases are intentionally disabled in this test build. The UI remains prepared.',
)
text = text.replace("t('1× MIT WERBUNG', '1× WITH AD')", "t('WERBUNG SPÄTER', 'ADS LATER')")

app.write_text(text)

pubspec = Path('pubspec.yaml')
pub = pubspec.read_text()
pub = pub.replace('version: 0.13.2+18', 'version: 0.13.3+19')
pub = pub.replace('  google_mobile_ads: ^9.1.0\n', '')
pub = pub.replace('  in_app_purchase: ^3.3.0\n', '')
pubspec.write_text(pub)

print('V0.13.3 SAFE native-start patch applied')
