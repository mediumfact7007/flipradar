import 'package:flipradar/deal_alert.dart';
import 'package:flipradar/deal_alert_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('concurrent saves from separate cards preserve every preference', () async {
    final firstStore = DealAlertStore();
    final secondStore = DealAlertStore();
    final first = DealAlertPreference.defaults(
      'flip-1',
      now: DateTime.utc(2026, 9, 18, 10),
    );
    final second = DealAlertPreference.defaults(
      'flip-2',
      now: DateTime.utc(2026, 9, 18, 10, 1),
    );

    final results = await Future.wait(<Future<bool>>[
      firstStore.save(first),
      secondStore.save(second),
    ]);

    expect(results, everyElement(isTrue));
    final loaded = await DealAlertStore().load();
    expect(loaded.map((item) => item.flipId).toSet(), {'flip-1', 'flip-2'});
  });

  test('concurrent remove and save do not resurrect the removed deal', () async {
    final store = DealAlertStore();
    expect(await store.save(DealAlertPreference.defaults('flip-old')), isTrue);

    final results = await Future.wait(<Future<bool>>[
      DealAlertStore().remove('flip-old'),
      DealAlertStore().save(DealAlertPreference.defaults('flip-new')),
    ]);

    expect(results, everyElement(isTrue));
    final loaded = await DealAlertStore().load();
    expect(loaded.map((item) => item.flipId), contains('flip-new'));
    expect(loaded.map((item) => item.flipId), isNot(contains('flip-old')));
  });
}
