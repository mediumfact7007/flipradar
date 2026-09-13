import 'package:flipradar/main.dart';
import 'package:flipradar/source_registry.dart';
import 'package:flutter_test/flutter_test.dart';

SourceListing comp(
  double price, {
  String source = 'ebay_de',
  bool live = true,
}) =>
    SourceListing(
      sourceId: source,
      sourceName: source,
      role: 'resale',
      title: 'Test listing',
      price: price,
      shipping: 0,
      url: 'https://example.test/item',
      condition: 'USED',
      live: live,
    );

void main() {
  test('Sandbox/reference data never creates market confidence', () {
    final result = v13MarketConfidence([
      comp(600, live: false),
      comp(620, live: false),
      comp(640, live: false),
    ]);
    expect(result.score, 0);
    expect(result.hasLiveData, isFalse);
    expect(result.label(false), 'Keine Live-Daten');
  });

  test('manual sale price is clearly separated from automatic confidence', () {
    final result = v13MarketConfidence(const <SourceListing>[], manualOverride: true);
    expect(result.manual, isTrue);
    expect(result.label(false), 'Manuell');
  });

  test('many consistent LIVE comps across sources earn very high confidence', () {
    final values = <SourceListing>[];
    for (var i = 0; i < 12; i++) {
      values.add(comp(590 + i * 5.0, source: i.isEven ? 'ebay_de' : 'partner_live'));
    }
    final result = v13MarketConfidence(values);
    expect(result.liveCount, 12);
    expect(result.sourceCount, 2);
    expect(result.score, greaterThanOrEqualTo(85));
    expect(result.label(false), 'Sehr hoch');
  });

  test('one good LIVE source can be high but not very high', () {
    final result = v13MarketConfidence([
      comp(590),
      comp(600),
      comp(610),
      comp(620),
      comp(630),
    ]);
    expect(result.score, inInclusiveRange(70, 84));
    expect(result.label(false), 'Hoch');
  });

  test('removed price outlier is visible in confidence metadata', () {
    final result = v13MarketConfidence([
      comp(24.99),
      comp(599),
      comp(620),
      comp(630),
      comp(650),
      comp(680),
    ]);
    expect(result.liveCount, 5);
    expect(result.removedOutliers, 1);
  });

  test('small widely spread sample stays low confidence', () {
    final result = v13MarketConfidence([
      comp(500),
      comp(900),
      comp(1300),
    ]);
    expect(result.score, lessThan(45));
    expect(result.label(false), 'Niedrig');
  });
}
