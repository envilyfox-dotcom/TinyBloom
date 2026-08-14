import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/availability_format.dart';
import '../../../utils/service_id.dart';
import '../../../utils/singapore_time.dart';
import '../../../utils/specialist_availability.dart';
import '../../../widgets/common_widgets.dart';

// Once a slot is this close, there's no longer reasonable notice for the
// provider — used both to grey out picking a too-soon slot and to grey out
// the Reschedule button on an appointment that's about to start.
const Duration minBookingNotice = Duration(minutes: 30);

// Pops back if possible, otherwise goes to the consultations hub. Needed
// because a booking confirmation's context.go() redirect wipes navigation
// history, so some screens have nothing left to pop back to.
void backOrToHub(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/consultation');
  }
}

// Opens the provider's read-only public profile — same screen used from
// article authors, reviews, and chat threads.
void openProviderProfile(
    BuildContext context, Map<String, dynamic> provider, bool isSpecialist) {
  final id = provider['user_id']?.toString();
  if (id == null || id.isEmpty) return;
  context.push(
      isSpecialist ? '/specialist/profile-view' : '/volunteer/profile-view',
      extra: id);
}

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

// Same as statusEmoji, but "expired" gets a red question mark instead of
// an hourglass — it looked too similar to "pending" otherwise.
Widget statusIconWidget(String status, {double size = 20}) {
  if (status.toLowerCase() == 'expired') {
    return Icon(Icons.question_mark_rounded, color: Colors.red, size: size);
  }
  return Text(statusEmoji(status), style: TextStyle(fontSize: size));
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

// Turns a consultation row's db id into a stable 6-digit number, so both
// sides of the appointment see the same number without a server round trip.
int _appointmentIdNumber(dynamic id) {
  final text = id?.toString() ?? '';
  if (text.isEmpty) return 0;
  var hash = 0;
  for (final unit in text.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return 100000 + (hash % 900000);
}

// e.g. "VOL-482913" for a volunteer consultation, "SPC-482913" for a
// specialist one, so support can tell which at a glance.
String appointmentIdLabel(dynamic id, [String? consultationType]) {
  final prefix = (consultationType ?? 'specialist').toLowerCase() == 'volunteer'
      ? 'VOL'
      : 'SPC';
  return '$prefix-${_appointmentIdNumber(id)}';
}

// Tappable appointment id that copies itself to the clipboard.
Widget appointmentIdValue(BuildContext context, dynamic id,
    [String? consultationType]) {
  final label = appointmentIdLabel(id, consultationType);
  return InkWell(
    borderRadius: BorderRadius.circular(6),
    onTap: () async {
      await Clipboard.setData(ClipboardData(text: label));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment ID copied to clipboard')),
        );
      }
    },
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(width: 6),
        const Icon(Icons.copy_rounded, size: 15, color: AppColors.textMid),
      ],
    ),
  );
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
  '7:00 PM',
  '8:00 PM',
  '9:00 PM',
  '10:00 PM',
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

  final compact = RegExp(r'^(\d{1,2})(AM|PM)$', caseSensitive: false);
  final match = compact.firstMatch(text.replaceAll(' ', ''));
  if (match != null) {
    final hour = match.group(1);
    final period = match.group(2);
    return '$hour:00 ${period!.toUpperCase()}';
  }

  return value.trim();
}

// Combines a date with a time-of-day string ("9:00 AM", "9am", "09:00")
// into a concrete DateTime, or null if it can't be parsed. Both inputs are
// Singapore wall-clock values, so compare the result against sgtNow() —
// never a bare DateTime.now(), or you'll be off by the device's UTC offset.
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
      return sgtWallClock(
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

// Combines a consultation row's scheduled_date + scheduled_time into one
// DateTime, or null if either is missing/unparseable.
DateTime? consultationScheduledDateTime(Map<String, dynamic> c) {
  final scheduled = c['scheduled_date'];
  if (scheduled == null) return null;
  try {
    final date = DateTime.parse(scheduled.toString());
    final timeStr = c['scheduled_time'] as String?;
    if (timeStr == null || timeStr.isEmpty) {
      return sgtWallClock(date.year, date.month, date.day);
    }
    return slotDateTime(date, timeStr) ??
        sgtWallClock(date.year, date.month, date.day);
  } catch (_) {
    return null;
  }
}

// Nothing server-side ever flips a consultation's status to 'completed' once
// its slot passes, so we derive that here instead: a confirmed appointment
// whose one-hour appointment window has ended shows as completed rather than
// staying "Confirmed" with a dead join button forever. Likewise a 'pending'
// request whose slot has passed means the specialist never responded, so it
// reads as cancelled.
// ('expired' rows, from an older status some screens used, are folded into
// cancelled too.)
String effectiveConsultationStatus(Map<String, dynamic> c) {
  final status = (c['status'] as String? ?? 'pending').toLowerCase();
  if (status == 'expired') return 'cancelled';
  if (status != 'confirmed' && status != 'pending') return status;
  final scheduled = consultationScheduledDateTime(c);
  if (scheduled == null) return status;

  final cutoff = status == 'confirmed'
      ? scheduled.add(const Duration(hours: 1))
      : scheduled;
  if (!cutoff.isBefore(sgtNow())) return status;
  return status == 'confirmed' ? 'completed' : 'cancelled';
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

// Parses a day range/list like "Monday - Sunday" or "Mon, Wed, Fri" into
// the full set of weekday names it covers.
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

List<String> availableTimesOnly(dynamic value) {
  final parsed = <String>[];

  if (value is List) {
    parsed.addAll(value.map(timeOnly).where((t) => t.isNotEmpty));
  } else if (value is String && value.trim().isNotEmpty) {
    var text = value.trim();

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
  final now = sgtNow();

  if (!_isSameDay(date, now)) return times;

  return times.where((time) {
    final slot = slotDateTime(date, time);
    if (slot == null) return true;
    return slot.isAfter(now);
  }).toList();
}

// Which time slots are already booked (pending or confirmed) today, per provider.
Future<Map<String, Set<String>>> _bookedTimesForToday(
    Iterable<String> providerUserIds) async {
  final ids = providerUserIds.where((id) => id.isNotEmpty).toSet();
  if (ids.isEmpty) return {};

  final today = sgtToday();

  try {
    final rows = await SupabaseService.client
        .from('consultations')
        .select('specialist_id, scheduled_time, status, scheduled_date')
        .eq('scheduled_date', today)
        .inFilter('specialist_id', ids.toList());

    final booked = <String, Set<String>>{};

    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final status = (row['status'] as String? ?? '').toLowerCase();

      if (status != 'pending' && status != 'confirmed') continue;

      final providerId = row['specialist_id']?.toString();
      final time = timeOnly(row['scheduled_time']);

      if (providerId == null || providerId.isEmpty || time.isEmpty) continue;

      booked.putIfAbsent(providerId, () => <String>{}).add(time);
    }

    return booked;
  } catch (_) {
    return {};
  }
}

// Adds `available_today` to each provider: today's open slots from their
// schedule, minus whatever's already passed or already booked.
Future<List<Map<String, dynamic>>> attachAvailableTimingsForToday(
    List<Map<String, dynamic>> providers) async {
  final today = sgtNow();
  final providerIds = providers
      .map((p) => p['user_id']?.toString())
      .whereType<String>()
      .toSet();

  final bookedByProvider = await _bookedTimesForToday(providerIds);

  return providers.map((provider) {
    final providerId = provider['user_id']?.toString() ?? '';
    final schedule = weeklyScheduleFromJson(provider['available_schedule']);
    final providerTimes = slotsForDate(schedule, today);

    final futureTimes = futureTimesForDate(providerTimes, today);
    final bookedTimes = bookedByProvider[providerId] ?? <String>{};

    final available = futureTimes
        .where((time) => !bookedTimes.contains(timeOnly(time)))
        .toList();

    return {
      ...provider,
      'available_today': available,
    };
  }).toList();
}

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
  final photoUrl = profile['profile_picture_url'] as String?;
  final avgRating = (provider['avg_rating'] as num?)?.toDouble();
  final ratingCount = (provider['rating_count'] as num?)?.toInt() ?? 0;
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
              GestureDetector(
                onTap: () =>
                    openProviderProfile(context, provider, isSpecialist),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                    image: photoUrl != null && photoUrl.isNotEmpty
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(photoUrl,
                                maxWidth: 200),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? null
                      : Center(
                          child:
                              Text(emoji, style: const TextStyle(fontSize: 25)),
                        ),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMid,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (avgRating != null && ratingCount > 0) ...[
                          const SizedBox(width: 6),
                          _providerChip(avgRating.toStringAsFixed(1),
                              AppColors.gold, Icons.star_rounded),
                        ],
                      ],
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
                  ? helpsWith.map((h) => _helpsChip(h, accent)).toList()
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

void _showServiceDetailsSheet(
    BuildContext context, Map<String, dynamic> service, Color accent) {
  final serviceId = formatServiceId(service['service_number']);
  final title = service['title'] as String? ?? 'Service';
  final description = service['description'] as String? ?? '';
  final category = service['category'] as String? ?? '';
  final consultationMethod = service['consultation_method'] as String? ?? '';
  final availability = service['availability'] as String?;
  final availabilityLabel = availability != null && availability.isNotEmpty
      ? formatAvailabilityDisplay(availability).replaceFirst(' | ', ' · ')
      : '—';

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
            if (serviceId.isNotEmpty) ...[
              const SizedBox(height: 6),
              _providerInfoLine(Icons.tag, 'Service ID: $serviceId'),
            ],
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
              const SizedBox(height: 6),
              _providerInfoLine(
                  Icons.info_outline,
                  consultationMethod == 'Video'
                      ? 'You\'ll get the video call link once your booking is confirmed.'
                      : 'You\'ll get chat access once your booking is confirmed.'),
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
