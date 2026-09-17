import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'deal_alert.dart';

/// Small local persistence layer for deal-alert opt-ins.
///
/// Keeping this provider-independent lets FlipRadar ship useful alert settings
/// before any push service is introduced. Corrupt entries are ignored rather
/// than breaking the watchlist or deal-check flow.
class DealAlertStore {
  static const _storageKey = 'deal_alert_preferences_v1';

  Future<List<DealAlertPreference>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final byFlip = <String, DealAlertPreference>{};
      for (final item in decoded) {
        if (item is! Map) continue;
        final preference = DealAlertPreference.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (preference == null) continue;
        final existing = byFlip[preference.flipId];
        if (existing == null || preference.updatedAt.isAfter(existing.updatedAt)) {
          byFlip[preference.flipId] = preference;
        }
      }
      final result = byFlip.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return result;
    } catch (_) {
      return const [];
    }
  }

  Future<DealAlertPreference?> forFlip(String flipId) async {
    final id = flipId.trim();
    if (id.isEmpty) return null;
    final all = await load();
    for (final preference in all) {
      if (preference.flipId == id) return preference;
    }
    return null;
  }

  Future<bool> save(DealAlertPreference preference) async {
    final all = await load();
    final next = <DealAlertPreference>[
      preference,
      ...all.where((item) => item.flipId != preference.flipId),
    ];
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(
      _storageKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }

  Future<bool> remove(String flipId) async {
    final id = flipId.trim();
    if (id.isEmpty) return true;
    final all = await load();
    final next = all.where((item) => item.flipId != id).toList();
    if (next.length == all.length) return true;
    final prefs = await SharedPreferences.getInstance();
    if (next.isEmpty) return prefs.remove(_storageKey);
    return prefs.setString(
      _storageKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }
}
