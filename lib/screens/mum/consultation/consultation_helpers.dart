import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';

Color statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return AppColors.sage;
    case 'completed':
      return AppColors.teal;
    case 'cancelled':
      return Colors.red;
    case 'expired':
      return Colors.red;
    default:
      return AppColors.gold;
  }
}

String statusEmoji(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return '✅';
    case 'completed':
      return '✔️';
    case 'cancelled':
      return '❌';
    case 'expired':
      return '⌛';
    default:
      return '⏳';
  }
}

String statusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return 'Confirmed';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    case 'expired':
      return 'Expired';
    default:
      return 'Pending Approval';
  }
}

String consultationTypeLabel(String? type) {
  if (type == null || type.isEmpty) return 'Consultation';
  return '${type[0].toUpperCase()}${type.substring(1)} Consultation';
}

String trimesterLabel(int week) {
  if (week >= 1 && week <= 12) return 'First Trimester';
  if (week >= 13 && week <= 27) return 'Second Trimester';
  if (week >= 28) return 'Third Trimester';
  return 'Unknown Trimester';
}

/// Shortens a consultation row's database id into a readable identifier
/// like "APT-3F9A2B" for display.
String appointmentIdLabel(dynamic id) {
  final text = id?.toString() ?? '';
  if (text.isEmpty) return 'APT-000000';
  final compact = text.replaceAll('-', '');
  final tail = compact.length > 6 ? compact.substring(compact.length - 6) : compact;
  return 'APT-${tail.toUpperCase()}';
}

const List<String> defaultConsultationTimes = [
  '9:00 AM',
  '10:00 AM',
  '11:00 AM',
  '12:00 PM',
  '1:00 PM',
  '2:00 PM',
  '3:00 PM',
  '4:00 PM',
  '5:00 PM',
  '6:00 PM',
];

String timeOnly(dynamic value) {
  if (value == null) return '';
  var text = value.toString().trim();

  if (text.isEmpty) return '';

  if (text.toLowerCase().startsWith('today')) {
    text = text.substring(5).trim();
  }

  if (text.contains('-')) {
    text = text.split('-').first.trim();
  }

  return _normaliseTime(text);
}

String _normaliseTime(String value) {
  var text = value.trim().replaceAll('.', '').toUpperCase();
  text = text.replaceAll(RegExp(r'\s+'), ' ');

  final formats = <DateFormat>[
    DateFormat('h:mm a'),
    DateFormat('h a'),
    DateFormat('HH:mm'),
    DateFormat('H:mm'),
  ];

  for (final format in formats) {
    try {
      final parsed = format.parseStrict(text);
      return DateFormat('h:mm a').format(parsed);
    } catch (_) {}
  }

  // Handle compact values such as 2PM / 9AM.
  final compact = RegExp(r'^(\d{1,2})(AM|PM)$', caseSensitive: false);
  final match = compact.firstMatch(text.replaceAll(' ', ''));
  if (match != null) {
    final hour = match.group(1);
    final period = match.group(2);
    return '$hour:00 ${period!.toUpperCase()}';
  }

  return value.trim();
}

/// Combines a [date] with a time-of-day string (e.g. "9:00 AM", "9am",
/// "09:00") into a concrete [DateTime], or null if [time] can't be parsed.
DateTime? slotDateTime(DateTime date, String time) {
  final clean = timeOnly(time).toUpperCase().replaceAll('.', '').trim();

  final formats = <DateFormat>[
    DateFormat('h:mm a'),
    DateFormat('h a'),
    DateFormat('HH:mm'),
    DateFormat('H:mm'),
  ];

  for (final format in formats) {
    try {
      final parsed = format.parseStrict(clean);
      return DateTime(
        date.year,
        date.month,
        date.day,
        parsed.hour,
        parsed.minute,
      );
    } catch (_) {}
  }
  return null;
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

const Map<String, String> _weekDayAliases = {
  'mon': 'Monday',
  'monday': 'Monday',
  'tue': 'Tuesday',
  'tues': 'Tuesday',
  'tuesday': 'Tuesday',
  'wed': 'Wednesday',
  'weds': 'Wednesday',
  'wednesday': 'Wednesday',
  'thu': 'Thursday',
  'thurs': 'Thursday',
  'thursday': 'Thursday',
  'fri': 'Friday',
  'friday': 'Friday',
  'sat': 'Saturday',
  'saturday': 'Saturday',
  'sun': 'Sunday',
  'sunday': 'Sunday',
};

const List<String> _weekDayOrder = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _parseWeekDay(String text) {
  final clean = text.trim().toLowerCase();
  return _weekDayAliases[clean] ?? '';
}

/// Parses the day-line of an `available_hours` value (e.g. "Monday - Sunday"
/// or "Mon, Wed, Fri") into the full set of weekday names it covers.
Set<String> availableDaysFromHours(dynamic value) {
  if (value is! String || value.trim().isEmpty) return {};

  final lines = value
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  if (lines.isEmpty) return {};

  final days = <String>{};

  for (final part in lines.first.split(',')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;

    if (trimmed.contains('-')) {
      final bounds = trimmed.split('-').map((e) => e.trim()).toList();
      final start = bounds.isNotEmpty ? _parseWeekDay(bounds.first) : '';
      final end = bounds.length > 1 ? _parseWeekDay(bounds.last) : '';
      final startIndex = _weekDayOrder.indexOf(start);
      final endIndex = _weekDayOrder.indexOf(end);

      if (startIndex != -1 && endIndex != -1) {
        // Expand the range (e.g. "Monday - Sunday") into every day it spans,
        // instead of just its two endpoints. Handles wrap-around ranges too.
        var i = startIndex;
        while (true) {
          days.add(_weekDayOrder[i]);
          if (i == endIndex) break;
          i = (i + 1) % _weekDayOrder.length;
        }
        continue;
      }

      for (final piece in bounds) {
        final day = _parseWeekDay(piece);
        if (day.isNotEmpty) days.add(day);
      }
    } else {
      final day = _parseWeekDay(trimmed);
      if (day.isNotEmpty) days.add(day);
    }
  }

  return days;
}

/// Whether the provider's `available_hours` value covers the weekday of
/// [date]. Correctly expands day ranges (e.g. "Monday - Sunday" means every
/// day from Monday through Sunday, not just those two days).
bool isDateAvailableForHours(dynamic value, DateTime date) {
  final availableDays = availableDaysFromHours(value);
  if (availableDays.isEmpty) return true;
  return availableDays.contains(DateFormat('EEEE').format(date));
}

List<String> availableTimesOnly(dynamic value) {
  final parsed = <String>[];

  if (value is List) {
    parsed.addAll(value.map(timeOnly).where((t) => t.isNotEmpty));
  } else if (value is String && value.trim().isNotEmpty) {
    var text = value.trim();

    // JSON/Postgres array string formats: ["9:00 AM"] or {9:00 AM,10:00 AM}
    if ((text.startsWith('[') && text.endsWith(']')) ||
        (text.startsWith('{') && text.endsWith('}'))) {
      text = text.substring(1, text.length - 1);
    }

    parsed.addAll(text
        .split(',')
        .map((e) => timeOnly(e.replaceAll('"', '').replaceAll("'", '')))
        .where((t) => t.isNotEmpty));
  }

  if (parsed.isEmpty) return [];

  final normalised = parsed.toSet();
  return defaultConsultationTimes
      .where((time) => normalised.contains(time))
      .toList();
}

List<String> futureTimesForDate(List<String> times, DateTime date) {
  final now = DateTime.now();

  // If selected date is not today, all standard unbooked slots can be shown.
  if (!_isSameDay(date, now)) return times;

  return times.where((time) {
    final slot = slotDateTime(date, time);
    if (slot == null) return true;
    return slot.isAfter(now);
  }).toList();
}

Future<Map<String, Set<String>>> _bookedTimesForToday(
    Iterable<String> providerUserIds) async {
  final ids = providerUserIds.where((id) => id.isNotEmpty).toSet();
  if (ids.isEmpty) return {};

  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  try {
    final rows = await SupabaseService.client
        .from('consultations')
        .select('specialist_id, scheduled_time, status, scheduled_date')
        .eq('scheduled_date', today)
        .inFilter('specialist_id', ids.toList());

    final booked = <String, Set<String>>{};

    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final status = (row['status'] as String? ?? '').toLowerCase();

      // Pending approval also blocks the slot because another user already requested it.
      if (status != 'pending' && status != 'confirmed') continue;

      final providerId = row['specialist_id']?.toString();
      final time = timeOnly(row['scheduled_time']);

      if (providerId == null || providerId.isEmpty || time.isEmpty) continue;

      booked.putIfAbsent(providerId, () => <String>{}).add(time);
    }

    return booked;
  } catch (_) {
    // If RLS blocks reading other bookings, at least keep the UI from crashing.
    return {};
  }
}

/// Adds `available_today` to each provider using the specialist's saved
/// availability days from `available_hours` and the actual time slots from
/// `available_today`, while excluding slots that have already passed or been booked.
Future<List<Map<String, dynamic>>> attachAvailableTimingsForToday(
    List<Map<String, dynamic>> providers) async {
  final today = DateTime.now();
  final providerIds = providers
      .map((p) => p['user_id']?.toString())
      .whereType<String>()
      .toSet();

  final bookedByProvider = await _bookedTimesForToday(providerIds);

  return providers.map((provider) {
    final providerId = provider['user_id']?.toString() ?? '';
    final providerTimes = availableTimesOnly(provider['available_today']);
    final shouldShowToday = isDateAvailableForHours(
      provider['available_hours'],
      today,
    );

    final baseTimes = shouldShowToday ? providerTimes : <String>[];
    final futureTimes =
        shouldShowToday ? futureTimesForDate(baseTimes, today) : <String>[];
    final bookedTimes = bookedByProvider[providerId] ?? <String>{};

    final available = futureTimes
        .where((time) => !bookedTimes.contains(timeOnly(time)))
        .toList();

    return {
      ...provider,
      'availability_slots': providerTimes,
      'available_today': available,
    };
  }).toList();
}

// ── Shared provider card (Select Specialist / Select Volunteer) ────
Widget providerCard(
    BuildContext context, Map<String, dynamic> provider, String type) {
  final profile = provider['profiles'] as Map<String, dynamic>? ?? {};
  final isSpecialist = type == 'specialist';
  final name = profile['full_name'] as String? ??
      (isSpecialist ? 'Doctor' : 'Volunteer');
  final role = isSpecialist
      ? (provider['specialization'] as String? ?? 'Specialist')
      : (provider['expertise'] as String? ?? 'Volunteer');
  final years = provider['years_experience'];
  final organisation = isSpecialist
      ? (provider['hospital_affiliation'] as String? ?? '')
      : (provider['affiliation'] as String? ?? '');
  final qualification = isSpecialist
      ? (provider['qualification'] as String? ?? '')
      : (provider['certification'] as String? ?? '');
  final helpsWith =
      (provider['helps_with'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[];
  final services = (provider['_services'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
  final availableToday = (provider['available_today'] as List?)
          ?.map((e) => timeOnly(e))
          .where((e) => e.isNotEmpty)
          .toList() ??
      const <String>[];
  final accent = isSpecialist ? AppColors.teal : AppColors.sage;
  final emoji = isSpecialist ? '👩‍⚕️' : '🤝';
  final label = isSpecialist ? 'Specialist Consultant' : 'Volunteer Consultant';

  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TBCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 25)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMid,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _providerChip(label, accent, Icons.verified_outlined),
                        if (years != null)
                          _providerChip('$years Years', AppColors.rose,
                              Icons.work_outline),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (organisation.isNotEmpty || qualification.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (organisation.isNotEmpty)
                    _providerInfoLine(
                        Icons.location_city_outlined, organisation),
                  if (organisation.isNotEmpty && qualification.isNotEmpty)
                    const SizedBox(height: 6),
                  if (qualification.isNotEmpty)
                    _providerInfoLine(Icons.school_outlined, qualification),
                ],
              ),
            ),
          ],
          if (helpsWith.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              isSpecialist ? 'Helps with' : 'Services Provided',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: isSpecialist
                  ? helpsWith
                      .map((h) => _helpsChip(h, accent))
                      .toList()
                  : services
                      .map((s) => GestureDetector(
                            onTap: () =>
                                _showServiceDetailsSheet(context, s, accent),
                            child: _helpsChip(
                                s['title']?.toString() ?? '', accent,
                                tappable: true),
                          ))
                      .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Remaining timings today',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                availableToday.isEmpty
                    ? 'Choose another date'
                    : '${availableToday.length} left',
                style: TextStyle(
                  color: availableToday.isEmpty
                      ? AppColors.textLight
                      : AppColors.roseDeep,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (availableToday.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.blush.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'No remaining timings today. You can still select this provider and choose tomorrow or another date.',
                style: TextStyle(
                  color: AppColors.textMid,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableToday
                  .take(5)
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.rose.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.rose.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                            color: AppColors.roseDeep,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push(
                '/consultation/book',
                extra: {'provider': provider, 'type': type},
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              child: Text(
                isSpecialist
                    ? 'Select Specialist Consultant'
                    : 'Select Volunteer Consultant',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _helpsChip(String label, Color accent, {bool tappable = false}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: accent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (tappable) ...[
          const SizedBox(width: 3),
          Icon(Icons.info_outline, size: 12, color: accent),
        ],
      ],
    ),
  );
}

// Shows a volunteer service's full details (description, category,
// availability, consultation method) when its "Services Provided" chip is
// tapped, since the chip itself only has room for the title.
void _showServiceDetailsSheet(
    BuildContext context, Map<String, dynamic> service, Color accent) {
  final title = service['title'] as String? ?? 'Service';
  final description = service['description'] as String? ?? '';
  final category = service['category'] as String? ?? '';
  final consultationMethod = service['consultation_method'] as String? ?? '';
  final availability = service['availability'] as String?;

  String availabilityLabel = '—';
  if (availability != null && availability.contains(' | ')) {
    final parts = availability.split(' | ');
    final date = DateTime.tryParse(parts[0]);
    final dateStr =
        date != null ? DateFormat('d MMM yyyy').format(date) : parts[0];
    availabilityLabel =
        parts.length > 1 ? '$dateStr · ${parts[1]}' : dateStr;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.textLight.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.textDark)),
            if (category.isNotEmpty) ...[
              const SizedBox(height: 6),
              _providerInfoLine(Icons.label_outline, category),
            ],
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(description,
                  style: const TextStyle(
                      color: AppColors.textMid, fontSize: 14, height: 1.4)),
            ],
            const SizedBox(height: 14),
            _providerInfoLine(Icons.schedule_outlined, availabilityLabel),
            if (consultationMethod.isNotEmpty) ...[
              const SizedBox(height: 6),
              _providerInfoLine(
                  consultationMethod == 'Video'
                      ? Icons.videocam_outlined
                      : Icons.chat_bubble_outline,
                  consultationMethod),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _providerChip(String text, Color color, IconData icon) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Widget _providerInfoLine(IconData icon, String text) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.textLight, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textMid,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ),
    ],
  );
}
