import 'package:shared_preferences/shared_preferences.dart';

// Tracks which next-of-kin alerts have already been read, stored locally
// on-device rather than in Supabase since it's just UI read/unread state.
const _kReadAlertKeysKey = 'next_of_kin_read_alert_keys';

// Cap how many read-alert keys we keep around so this doesn't grow forever.
const _kMaxStoredKeys = 300;

Future<Set<String>> getReadAlertKeys() async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getStringList(_kReadAlertKeysKey) ?? const []).toSet();
}

// Marks the given alert keys as read, trimming the oldest ones once we're
// over the cap.
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

// The first time a milestone alert for a given week is seen, we stamp and
// store the timestamp so it stays stable on every later call instead of
// drifting forward each time "now" is read.
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
