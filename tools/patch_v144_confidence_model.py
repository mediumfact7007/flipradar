import re
from pathlib import Path

app_path = Path('lib/v13_app.dart')
pub_path = Path('pubspec.yaml')
app = app_path.read_text()
pub = pub_path.read_text()

model = r'''class V13MarketConfidence {
  final int score;
  final int liveCount;
  final int sourceCount;
  final int removedOutliers;
  final bool manual;

  const V13MarketConfidence({
    required this.score,
    required this.liveCount,
    required this.sourceCount,
    required this.removedOutliers,
    this.manual = false,
  });

  bool get hasLiveData => liveCount > 0;

  String label(bool english) {
    if (manual) return english ? 'Manual' : 'Manuell';
    if (!hasLiveData) return english ? 'No live data' : 'Keine Live-Daten';
    if (score >= 85) return english ? 'Very high' : 'Sehr hoch';
    if (score >= 70) return english ? 'High' : 'Hoch';
    if (score >= 45) return english ? 'Medium' : 'Mittel';
    return english ? 'Low' : 'Niedrig';
  }

  String note(bool english) {
    if (manual) {
      return english
          ? 'Sale price set manually; automatic market confidence does not rate that value.'
          : 'Verkaufspreis manuell gesetzt; die Markt-Confidence bewertet diesen Wert nicht.';
    }
    if (!hasLiveData) {
      return english
          ? 'Sandbox and reference values are deliberately excluded.'
          : 'Sandbox- und Referenzwerte werden absichtlich nicht mitgerechnet.';
    }
    final removed = removedOutliers > 0
        ? (english ? '$removedOutliers outlier(s) removed.' : '$removedOutliers Ausreißer entfernt.')
        : (english ? 'No severe outliers removed.' : 'Keine starken Ausreißer entfernt.');
    return english
        ? '$liveCount LIVE comps from $sourceCount source(s). $removed'
        : '$liveCount LIVE-Vergleiche aus $sourceCount Quelle(n). $removed';
  }
}

V13MarketConfidence v13MarketConfidence(
  List<SourceListing> listings, {
  bool manualOverride = false,
}) {
  final live = listings
      .where((e) => e.live && (e.role == 'resale' || e.role == 'local') && e.total.isFinite && e.total > 0)
      .toList();
  final raw = live.map((e) => e.total).toList();
  final cleaned = v13CleanMarketValues(raw);
  final used = cleaned.length;
  final sources = live.map((e) => e.sourceId).toSet().length;
  final removed = raw.length > used ? raw.length - used : 0;
  if (raw.isEmpty) {
    return V13MarketConfidence(score: 0, liveCount: 0, sourceCount: 0, removedOutliers: 0, manual: manualOverride);
  }

  final sorted = [...cleaned]..sort();
  final mid = sorted.length ~/ 2;
  final median = sorted.isEmpty
      ? 0.0
      : sorted.length.isOdd
          ? sorted[mid]
          : (sorted[mid - 1] + sorted[mid]) / 2;
  final spread = sorted.length < 2 || median <= 0 ? 1.0 : (sorted.last - sorted.first) / median;
  final sample = used >= 12 ? 45 : used >= 8 ? 38 : used >= 5 ? 30 : used >= 3 ? 20 : 8;
  final consistency = spread <= .18 ? 30 : spread <= .30 ? 26 : spread <= .45 ? 20 : spread <= .65 ? 12 : 4;
  final diversity = sources >= 3 ? 15 : sources == 2 ? 11 : 7;
  final retention = raw.isEmpty ? 0.0 : used / raw.length;
  final hygiene = retention >= .85 ? 10 : retention >= .65 ? 7 : 3;
  var score = (sample + consistency + diversity + hygiene).clamp(0, 100).toInt();
  if (used < 3 && score > 34) score = 34;
  if (used < 5 && score > 69) score = 69;
  if (sources == 1 && score > 84) score = 84;
  return V13MarketConfidence(score: score, liveCount: used, sourceCount: sources, removedOutliers: removed, manual: manualOverride);
}

'''
marker = 'enum V13Decision { waiting, buy, negotiate, skip }\n'
if 'class V13MarketConfidence {' not in app:
    if marker not in app:
        raise SystemExit('V13Decision marker not found')
    app = app.replace(marker, model + marker, 1)

old = """  String get confidence {
    final values = _clean(_valuesFor({'resale', 'local'}));
    if (values.length < 3) return t('Niedrig', 'Low');
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final med = _median(values) ?? 1;
    final spread = (maxV - minV) / med;
    if (values.length >= 10 && spread < .35) return t('Hoch', 'High');
    if (values.length >= 5 && spread < .65) return t('Mittel', 'Medium');
    return t('Niedrig', 'Low');
  }
"""
new = """  V13MarketConfidence get marketConfidence => v13MarketConfidence(
        listings,
        manualOverride: manualCommitted != null && manualCommitted! > 0,
      );
  String get confidence => marketConfidence.label(widget.english);
"""
if old in app:
    app = app.replace(old, new, 1)
elif 'V13MarketConfidence get marketConfidence' not in app:
    raise SystemExit('confidence getter not found')

pub = re.sub(r'^version: 0\.14\.3\+26$', 'version: 0.14.4+27', pub, count=1, flags=re.MULTILINE)
assert re.search(r'^version: 0\.14\.4\+27$', pub, flags=re.MULTILINE)
assert 'class V13MarketConfidence {' in app
assert 'V13MarketConfidence get marketConfidence' in app
app_path.write_text(app)
pub_path.write_text(pub)
print('V0.14.4 confidence model applied')
