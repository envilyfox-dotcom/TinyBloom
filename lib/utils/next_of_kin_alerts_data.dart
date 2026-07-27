import 'pregnancy_log_danger_scan.dart';

// ── Next-of-kin alert sources ──────────────────────────────────────
// Single source of truth for *which* alerts exist and what key each one
// gets, shared between the full Notifications Centre (alerts_screen.dart,
// which decorates each source with icon/title/subtitle/etc. for display)
// and the dashboard's notification-bell badge (which only needs the keys
// to count how many are unread). Keeping eligibility logic in one place
// means the two screens can never disagree on what counts as "active."
class NextOfKinAlertSource {
  final String key;
  final String type; // 'emergency' | 'milestone' | 'consultation' | 'reminder'
  final DateTime timestamp;
  final Map<String, dynamic>? consultation;
  final Map<String, dynamic>? log;
  final Map<String, dynamic>? reminderSend;
  final int? milestoneWeek;

  NextOfKinAlertSource({
    required this.key,
    required this.type,
    required this.timestamp,
    this.consultation,
    this.log,
    this.reminderSend,
    this.milestoneWeek,
  });
}

List<NextOfKinAlertSource> buildNextOfKinAlertSources({
  required int linkedMumWeek,
  required List<Map<String, dynamic>> consultations,
  required List<Map<String, dynamic>> pregnancyLogs,
  required List<Map<String, dynamic>> dailyReminderSends,
}) {
  final sources = <NextOfKinAlertSource>[];

  // Emergency alerts always float to the top of the full centre, ahead of
  // routine updates — kept first here too so both screens see them first.
  for (final log in pregnancyLogs) {
    if (!pregnancyLogHasDangerSymptom(log)) continue;
    final timestamp = DateTime.tryParse(
            (log['log_date'] ?? log['created_at'] ?? '').toString()) ??
        DateTime.now();
    sources.add(NextOfKinAlertSource(
      key: 'pregnancy-log-emergency-${log['id']}',
      type: 'emergency',
      timestamp: timestamp,
      log: log,
    ));
  }

  if (linkedMumWeek > 0) {
    sources.add(NextOfKinAlertSource(
      key: 'milestone-$linkedMumWeek',
      type: 'milestone',
      timestamp: DateTime.now(),
      milestoneWeek: linkedMumWeek,
    ));
  }

  for (final c in consultations) {
    final status = (c['status'] as String? ?? '').toLowerCase();
    if (status != 'pending' && status != 'confirmed') continue;
    sources.add(NextOfKinAlertSource(
      key: 'consultation-${c['id']}',
      type: 'consultation',
      timestamp:
          DateTime.tryParse((c['scheduled_date'] ?? '').toString()) ??
              DateTime.now(),
      consultation: c,
    ));
  }

  for (final row in dailyReminderSends) {
    final timestamp =
        DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now();
    sources.add(NextOfKinAlertSource(
      key: 'daily-reminder-send-${row['id']}',
      type: 'reminder',
      timestamp: timestamp,
      reminderSend: row,
    ));
  }

  return sources;
}
