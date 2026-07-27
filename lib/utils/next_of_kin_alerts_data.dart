import 'package:flutter/material.dart';
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
  // 'emergency' | 'milestone' | 'consultation' | 'reminder' | 'volunteer'
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic>? consultation;
  final Map<String, dynamic>? log;
  final Map<String, dynamic>? reminderSend;
  final Map<String, dynamic>? volunteerQuestion;
  final int? milestoneWeek;

  NextOfKinAlertSource({
    required this.key,
    required this.type,
    required this.timestamp,
    this.consultation,
    this.log,
    this.reminderSend,
    this.volunteerQuestion,
    this.milestoneWeek,
  });
}

List<NextOfKinAlertSource> buildNextOfKinAlertSources({
  required int linkedMumWeek,
  required List<Map<String, dynamic>> consultations,
  required List<Map<String, dynamic>> pregnancyLogs,
  required List<Map<String, dynamic>> dailyReminderSends,
  List<Map<String, dynamic>> volunteerQuestions = const [],
  // When the current milestone week was first seen (see
  // getOrRecordMilestoneTimestamp) — falls back to now if the caller
  // hasn't fetched it, so this parameter is optional rather than required.
  DateTime? milestoneTimestamp,
}) {
  final sources = <NextOfKinAlertSource>[];

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
      timestamp: milestoneTimestamp ?? DateTime.now(),
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

  // A volunteer claiming the thread (volunteer_id gets set) is their first
  // reply — see claimAndReplyToRequest in supabase_service.dart. The key
  // has no timestamp component, so this only notifies once per question
  // (matches "a volunteer started the chat with them"), not on every
  // follow-up message after that.
  for (final row in volunteerQuestions) {
    if (row['volunteer_id'] == null) continue;
    final timestamp = DateTime.tryParse(
            (row['last_activity_at'] ?? row['created_at'] ?? '').toString()) ??
        DateTime.now();
    sources.add(NextOfKinAlertSource(
      key: 'volunteer-reply-${row['id']}',
      type: 'volunteer',
      timestamp: timestamp,
      volunteerQuestion: row,
    ));
  }

  return sources;
}

// Shared between the full centre and the dashboard's compact preview so
// a reminder's icon always matches wherever it's shown.
IconData iconForReminderName(String? name) {
  switch (name) {
    case 'favorite_border':
      return Icons.favorite_border;
    case 'visibility_outlined':
      return Icons.visibility_outlined;
    case 'event_note_outlined':
      return Icons.event_note_outlined;
    case 'water_drop_outlined':
      return Icons.water_drop_outlined;
    default:
      return Icons.notifications_none_outlined;
  }
}
