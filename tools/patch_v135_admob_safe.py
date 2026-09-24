from pathlib import Path

app_path = Path('lib/v13_app.dart')
pub_path = Path('pubspec.yaml')
app = app_path.read_text()
pub = pub_path.read_text()

# V0.13.5 = SAFE RECOVERY STEP 2.
# Reintroduce Google Mobile Ads in test mode only, but do not initialize ads
# during normal app startup. Consent/ads are touched only after an explicit
# privacy or rewarded-ad action. Banner ads remain disabled in this step.
if "import 'dart:io';" not in app:
    app = app.replace("import 'dart:convert';\n", "import 'dart:convert';\nimport 'dart:io';\n", 1)
if "package:google_mobile_ads/google_mobile_ads.dart" not in app:
    app = app.replace(
        "import 'package:flutter/services.dart';\n",
        "import 'package:flutter/services.dart';\nimport 'package:google_mobile_ads/google_mobile_ads.dart';\n",
        1,
    )

if "static const androidBanner" not in app:
    app = app.replace(
        "  static const yearlyId = 'flipwert_pro_yearly';\n",
        "  static const yearlyId = 'flipwert_pro_yearly';\n"
        "  static const androidBanner = 'ca-app-pub-3940256099942544/6300978111';\n"
        "  static const androidRewarded = 'ca-app-pub-3940256099942544/5224354917';\n"
        "  static const iosBanner = 'ca-app-pub-3940256099942544/2934735716';\n"
        "  static const iosRewarded = 'ca-app-pub-3940256099942544/1712485313';\n",
        1,
    )

if "bool _adsPrepared = false;" not in app:
    app = app.replace(
        "  bool _billingPrepared = false;\n",
        "  bool _billingPrepared = false;\n  bool _adsPrepared = false;\n  bool _adsLoading = false;\n",
        1,
    )

if "String get bannerId" not in app:
    app = app.replace(
        "  V13Monetization({required this.onProUnlocked});\n",
        "  V13Monetization({required this.onProUnlocked});\n\n"
        "  String get bannerId => Platform.isAndroid ? androidBanner : iosBanner;\n"
        "  String get rewardedId => Platform.isAndroid ? androidRewarded : iosRewarded;\n",
        1,
    )

privacy_stub = "  // Ads and UMP consent stay disabled until the next isolated recovery step.\n  Future<void> showPrivacyOptions() async {}\n"
privacy_impl = r'''  // SAFE RECOVERY STEP 2: test ads are prepared only after an explicit
  // ad/privacy action. Normal app boot never calls this method.
  Future<bool> prepareAds() async {
    if (_adsPrepared) return adsAllowed;
    if (_adsLoading) return adsAllowed;
    _adsLoading = true;
    notifyListeners();
    try {
      final completer = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          ConsentForm.loadAndShowConsentFormIfRequired((_) {
            if (!completer.isCompleted) completer.complete();
          });
        },
        (_) {
          if (!completer.isCompleted) completer.complete();
        },
      );
      await completer.future.timeout(const Duration(seconds: 30), onTimeout: () {});
      adsAllowed = await ConsentInformation.instance.canRequestAds();
      if (adsAllowed) {
        await MobileAds.instance.initialize();
      }
    } catch (_) {
      adsAllowed = false;
    } finally {
      _adsPrepared = true;
      _adsLoading = false;
      notifyListeners();
    }
    return adsAllowed;
  }

  Future<void> showPrivacyOptions() async {
    await prepareAds();
    try {
      ConsentForm.showPrivacyOptionsForm((_) {});
    } catch (_) {}
  }
'''
if privacy_stub in app:
    app = app.replace(privacy_stub, privacy_impl, 1)
elif "Future<bool> prepareAds() async" not in app:
    raise SystemExit('Ad privacy stub not found')

reward_stub = "  // Rewarded ads intentionally remain unavailable in V0.13.4.\n  Future<bool> rewardedUnlock() async => false;\n"
reward_impl = r'''  Future<bool> rewardedUnlock() async {
    if (!await prepareAds()) return false;
    final completer = Completer<bool>();
    var earned = false;
    try {
      await RewardedAd.load(
        adUnitId: rewardedId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (value) {
                value.dispose();
                if (!completer.isCompleted) completer.complete(earned);
              },
              onAdFailedToShowFullScreenContent: (value, _) {
                value.dispose();
                if (!completer.isCompleted) completer.complete(false);
              },
            );
            ad.show(onUserEarnedReward: (_, __) => earned = true);
          },
          onAdFailedToLoad: (_) {
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
    } catch (_) {
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future.timeout(const Duration(seconds: 45), onTimeout: () => false);
  }
'''
if reward_stub in app:
    app = app.replace(reward_stub, reward_impl, 1)
elif "Future<bool> rewardedUnlock() async" not in app:
    raise SystemExit('Rewarded stub not found')

app = app.replace(
    "SAFE RECOVERY 1: Play Billing wird nur auf der PRO-Seite geladen. Werbung bleibt in dieser Version deaktiviert.",
    "SAFE RECOVERY 2: Test-AdMob wird nur nach einer Werbe-/Datenschutz-Aktion geladen. Banner bleiben in dieser Version deaktiviert.",
)
app = app.replace(
    "SAFE RECOVERY 1: Play Billing loads only on the PRO page. Ads remain disabled in this build.",
    "SAFE RECOVERY 2: Test AdMob loads only after an ad/privacy action. Banner ads remain disabled in this build.",
)

pub = pub.replace('version: 0.13.4+20', 'version: 0.13.5+21')
if 'google_mobile_ads:' not in pub:
    pub = pub.replace('  cupertino_icons: ^1.0.8\n', '  cupertino_icons: ^1.0.8\n  google_mobile_ads: ^9.1.0\n', 1)

assert 'version: 0.13.5+21' in pub
assert 'google_mobile_ads: ^9.1.0' in pub
assert "package:google_mobile_ads/google_mobile_ads.dart" in app
assert 'Future<bool> prepareAds() async' in app
assert 'if (!await prepareAds()) return false;' in app
assert 'MobileAds.instance.initialize()' in app
assert 'ca-app-pub-3940256099942544/5224354917' in app
assert 'class V13BannerAd extends StatelessWidget' in app
assert 'Widget build(BuildContext context) => const SizedBox.shrink();' in app
assert 'unawaited(monetization.prepareAds())' not in app
startup_slice = app[app.index('class _FlipwertAppState'):app.index('class V13Home extends StatefulWidget')]
assert 'prepareAds()' not in startup_slice
assert 'MobileAds.instance.initialize()' not in startup_slice

app_path.write_text(app)
pub_path.write_text(pub)
print('V0.13.5 lazy test-AdMob recovery patch applied')
