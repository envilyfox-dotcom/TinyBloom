import 'package:intl/intl.dart';
import '../mum/consultation/consultation_helpers.dart';

// ── Specialist Alerts & Notifications ───────────────────────────────
// Builds the specialist's notification feed live from consultations +
// the review queue (already loaded by the calling screen) rather than a
// stored notifications table — there's no notification-delivery service
// in this app yet, so "needs action" here just means the underlying
// consultation/article still needs it; it naturally clears once the
// specialist confirms the consultation or the review moves on.
List<Map<String, dynamic>> buildSpecialistNotifications({
  required List<Map<String, dynamic>> consultations,
  required List<Map<String, dynamic>> reviewQueue,
  required String userId,
}) {
  final now = DateTime.now();
  final items = <Map<String, dynamic>>[];

  DateTime? scheduledDateTime(Map<String, dynamic> c) {
    final scheduled = c['scheduled_date'];
    if (scheduled == null) return null;
    try {
      final date = DateTime.parse(scheduled.toString());
      final timeStr = c['scheduled_time'] as String?;
      if (timeStr == null || timeStr.isEmpty) {
        return DateTime(date.year, date.month, date.day);
      }
      return slotDateTime(date, timeStr) ??
          DateTime(date.year, date.month, date.day);
    } catch (_) {
      return null;
    }
  }

  for (final c in consultations) {
    if (c['specialist_id']?.toString() != userId) continue;
    final status = (c['status'] as String? ?? '').toLowerCase();
    final scheduled = scheduledDateTime(c);
    final apptId =
        appointmentIdLabel(c['id'], c['consultation_type'] as String?);

    if (status == 'pending' && (scheduled == null || scheduled.isAfter(now))) {
      items.add({
        'id': 'consult-confirm-${c['id']}',
        'category': 'consultation',
        'title': 'Consultation needs your confirmation',
        'message':
            'A patient booked $apptId and is waiting for you to confirm it.',
        'created_at': c['created_at'],
        'consultation': c,
      });
    } else if (status == 'confirmed' && scheduled != null) {
      final minutesUntil = scheduled.difference(now).inMinutes;
      // "About 15 mins before" the appointment starts, once it's confirmed.
      if (minutesUntil >= 0 && minutesUntil <= 15) {
        final timeLabel = c['scheduled_time'] as String? ?? '';
        items.add({
          'id': 'consult-start-${c['id']}',
          'category': 'consultation',
          'title': 'Consultation about to start',
          'message': 'Consultation $apptId at $timeLabel is about to start',
          'created_at': now.toIso8601String(),
          'consultation': c,
        });
      }
    }
  }

  for (final item in reviewQueue) {
    if (item['needs_action'] != true) continue;
    final status = item['status'] as String? ?? '';
    final isAuthor = item['created_by']?.toString() == userId;

    String title;
    if (isAuthor && status == 'changes_requested') {
      title = 'Your Article require an edit';
    } else if (!isAuthor && status == 'pending_approval_1') {
      title = 'Article Pending 1st Approval';
    } else if (!isAuthor && status == 'pending_approval_2') {
      title = 'Article Pending 2nd Approval';
    } else {
      continue;
    }

    items.add({
      'id': 'review-${item['id']}',
      'category': 'review',
      'title': title,
      'message': item['title'] as String? ?? 'Untitled article',
      'created_at': item['created_at'],
      'article': item,
    });
  }

  items.sort((a, b) {
    final aDate =
        DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
    final bDate =
        DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
    return bDate.compareTo(aDate);
  });

  return items;
}

String timeAgoLabel(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(date);
}
