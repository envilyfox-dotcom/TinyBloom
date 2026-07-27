import 'package:shared_preferences/shared_preferences.dart';

// ── Next-of-kin alert "read" tracking ─────────────────────────────────
// There's no backend read-receipt table for these derived alerts (unlike
// the mum's `notifications` table), so read state is tracked locally per
// device via SharedPreferences. Shared between the full Notifications
// Centre (which marks alerts read as they're viewed) and the dashboard's
// notification-bell badge (which needs to know how many are still
// unread), so both always agree.
const _kReadAlertKeysKey = 'next_of_kin_read_alert_keys';

// Keys naturally stay few and recent (alerts age out as consultations
// resolve, logs scroll past, milestones advance), so this cap just
// guards against unbounded growth over months of use.
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

// ── Milestone "received at" timestamp ─────────────────────────────────
// The milestone alert has no real backing row/timestamp (it's derived
// from the linked mum's current pregnancy week), so it used to be
// stamped with DateTime.now() on every single load — which made it look
// artificially "Just now" forever and always sort above genuinely recent
// alerts like a fresh volunteer reply. This records the first time a
// given week's milestone was seen, and returns that same stable time on
// every later load, only advancing once the week itself changes.
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
