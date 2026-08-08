import 'package:shared_preferences/shared_preferences.dart';

const _kReadAlertKeysKey = 'next_of_kin_read_alert_keys';

const _kMaxStoredKeys = 300;

Future<Set<String>> getReadAlertKeys() async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getStringList(_kReadAlertKeysKey) ?? const []).toSet();
}

Future<void> markAlertKeysRead(Iterable<String> keys) async {
  final newKeys = keys.toSet();
  if (newKeys.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  final current = (prefs.getStringList(_kReadAlertKeysKey) ?? const []).toSet();
  current.addAll(newKeys);

  final trimmed = current.length > _kMaxStoredKeys
      ? current.skip(current.length - _kMaxStoredKeys).toSet()
      : current;

  await prefs.setStringList(_kReadAlertKeysKey, trimmed.toList());
}

const _kMilestoneTimestampPrefix = 'next_of_kin_milestone_seen_week_';

Future<DateTime> getOrRecordMilestoneTimestamp(int week) async {
  final prefs = await SharedPreferences.getInstance();
  final key = '$_kMilestoneTimestampPrefix$week';
  final raw = prefs.getString(key);
  if (raw != null) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
  }
  final now = DateTime.now();
  await prefs.setString(key, now.toIso8601String());
  return now;
}
