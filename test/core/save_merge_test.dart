import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/core/cloud/save_merge.dart';
import 'package:masala_sort/core/storage/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('fresh reinstall takes the cloud progress', () {
    final local = <String, Object>{'current_level': 1, 'coins': 0};
    final cloud = <String, Object>{
      'current_level': 42,
      'coins': 380,
      'stars_map': '{"1":3,"2":2}',
      'chests_claimed': ['0'],
      'setting_sound_on': false,
    };
    final m = SaveMerge.merge(local, cloud);
    expect(SaveMerge.cloudIsAhead(local, cloud), isTrue);
    expect(m['current_level'], 42);
    expect(m['coins'], 380);
    expect(m['stars_map'], '{"1":3,"2":2}');
    expect(m['chests_claimed'], ['0']);
    expect(m['setting_sound_on'], false);
  });

  test('keeps the best of both sides', () {
    final local = <String, Object>{
      'current_level': 10,
      'coins': 50,
      'stars_map': '{"1":1,"5":3}',
      'daily_completed_dates': ['2026-11-14'],
      'remove_ads': true,
      'restarts_7': 2,
    };
    final cloud = <String, Object>{
      'current_level': 8,
      'coins': 500,
      'stars_map': '{"1":3,"2":2}',
      'daily_completed_dates': ['2026-11-10'],
      'restarts_3': 5,
    };
    final m = SaveMerge.merge(local, cloud);
    expect(m['current_level'], 10); // local is further
    expect(m['coins'], 50); // coins follow the side that is ahead
    expect(m['stars_map'], '{"1":3,"5":3,"2":2}');
    expect(m['daily_completed_dates'], ['2026-11-10', '2026-11-14']);
    expect(m['remove_ads'], true);
    expect(m['restarts_7'], 2); // per-session keys stay local
    expect(m.containsKey('restarts_3'), isFalse);
  });

  test('login streak follows the latest claim', () {
    final m = SaveMerge.merge(
      {
        'current_level': 5,
        'login_last_claim': '2026-11-10T00:00:00.000',
        'login_day': 2,
      },
      {
        'current_level': 3,
        'login_last_claim': '2026-11-13T00:00:00.000',
        'login_day': 5,
      },
    );
    expect(m['login_day'], 5);
  });

  test('SaveService snapshot round-trips through import', () async {
    SharedPreferences.setMockInitialValues({});
    await SaveService.init();
    final svc = SaveService.instance;
    await svc.advanceLevel(12);
    await svc.setCoins(99);
    await svc.markChestClaimed(0);
    final snap = svc.exportSnapshot();

    SharedPreferences.setMockInitialValues({});
    await SaveService.init();
    await SaveService.instance.importSnapshot({
      ...snap,
      // Firestore returns lists as List<dynamic>.
      'chests_claimed': <dynamic>['0'],
    });
    expect(SaveService.instance.currentLevel, 12);
    expect(SaveService.instance.coins, 99);
    expect(SaveService.instance.chestsClaimed, {0});
  });
}
