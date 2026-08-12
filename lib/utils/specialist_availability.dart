import 'package:intl/intl.dart';

// Monday-first weekday order, used everywhere a specialist's weekly
// schedule is iterated, displayed, or compressed into ranges.
const List<String> weekDayOrder = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

// Formats an hour-of-day (0-23, or 24 for end-of-day/midnight) as a 12-hour
// clock label, e.g. 9 -> "9:00 AM", 24 -> "12:00 AM".
String hourLabel(int hour) {
  final dt = DateTime(2000, 1, 1, hour % 24);
  return DateFormat('h:mm a').format(dt);
}

// A specialist's availability window for one day of the week. `start` is
// the hour (0-23) consultations may begin; `end` is the hour (1-24) after
// which no more may begin (24 = up to midnight). Slots are generated in
// 1-hour steps across [start, end).
class DayAvailability {
  final int start;
  final int end;
  final bool allDay;

  const DayAvailability({
    required this.start,
    required this.end,
    this.allDay = false,
  });

  factory DayAvailability.allDayAvailability() =>
      const DayAvailability(start: 0, end: 24, allDay: true);

  // Builds a DayAvailability, but treats a manually picked 12:00 AM -> 12:00
  // AM range the same as "Available all day" - otherwise it'd show up as a
  // confusing "12:00 AM - 12:00 AM" label instead of what the specialist
  // actually meant.
  factory DayAvailability.of({
    required int start,
    required int end,
    bool allDay = false,
  }) {
    if (allDay || (start == 0 && end == 24)) {
      return DayAvailability.allDayAvailability();
    }
    return DayAvailability(start: start, end: end);
  }

  factory DayAvailability.fromJson(Map<String, dynamic> json) {
    final allDay = json['allDay'] == true;
    if (allDay) return DayAvailability.allDayAvailability();

    final start = ((json['start'] as num?)?.toInt() ?? 9).clamp(0, 23);
    final rawEnd = (json['end'] as num?)?.toInt() ?? (start + 1);
    final end = rawEnd > start ? rawEnd.clamp(start + 1, 24) : start + 1;

    return DayAvailability.of(start: start, end: end);
  }

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'allDay': allDay,
      };

  String get startLabel => hourLabel(start);
  String get endLabel => hourLabel(end);

  // Hourly slot labels within this window, e.g. start: 9, end: 12 ->
  // ["9:00 AM", "10:00 AM", "11:00 AM"].
  List<String> slotLabels() {
    if (end <= start) return const [];
    return [for (var h = start; h < end; h++) hourLabel(h)];
  }
}

typedef WeeklySchedule = Map<String, DayAvailability>;

Map<String, dynamic> weeklyScheduleToJson(WeeklySchedule schedule) => {
      for (final entry in schedule.entries) entry.key: entry.value.toJson(),
    };

WeeklySchedule weeklyScheduleFromJson(dynamic value) {
  if (value is! Map) return {};

  final schedule = <String, DayAvailability>{};
  for (final entry in value.entries) {
    final day = entry.key.toString();
    final raw = entry.value;
    if (!weekDayOrder.contains(day) || raw is! Map) continue;
    schedule[day] = DayAvailability.fromJson(Map<String, dynamic>.from(raw));
  }
  return schedule;
}

// Whether `schedule` covers the weekday of `date`. An empty schedule counts
// as unrestricted (available any day) - matches the old behaviour for
// providers who haven't set up a schedule yet.
bool isDateAvailableForSchedule(WeeklySchedule schedule, DateTime date) {
  if (schedule.isEmpty) return true;
  return schedule.containsKey(DateFormat('EEEE').format(date));
}

// Bookable hour-slot labels for `date` under `schedule`, or an empty list
// if that weekday has no configured availability.
List<String> slotsForDate(WeeklySchedule schedule, DateTime date) {
  final availability = schedule[DateFormat('EEEE').format(date)];
  return availability?.slotLabels() ?? const [];
}

// Human-readable summary, grouping consecutive weekdays that share the same
// time range into one line, e.g.
// "Monday - Friday: 9:00 AM - 5:00 PM\nSaturday: Available all day".
String formatWeeklySchedule(WeeklySchedule schedule) {
  final orderedDays = weekDayOrder.where(schedule.containsKey).toList();
  if (orderedDays.isEmpty) return '';

  String rangeLabel(DayAvailability a) =>
      a.allDay ? 'Available all day' : '${a.startLabel} - ${a.endLabel}';

  final lines = <String>[];
  var i = 0;
  while (i < orderedDays.length) {
    final label = rangeLabel(schedule[orderedDays[i]]!);
    var j = i;
    while (j + 1 < orderedDays.length &&
        weekDayOrder.indexOf(orderedDays[j + 1]) ==
            weekDayOrder.indexOf(orderedDays[j]) + 1 &&
        rangeLabel(schedule[orderedDays[j + 1]]!) == label) {
      j++;
    }
    final dayLabel =
        i == j ? orderedDays[i] : '${orderedDays[i]} - ${orderedDays[j]}';
    lines.add('$dayLabel: $label');
    i = j + 1;
  }

  return lines.join('\n');
}

int? _parseLegacyHour(String label) {
  try {
    final parsed = DateFormat('h:mm a').parseStrict(label.trim().toUpperCase());
    return parsed.hour;
  } catch (_) {
    return null;
  }
}

// Best-effort conversion from the old flat "selected days" + "selected
// times" model into a WeeklySchedule: works out one start/end range from
// the earliest/latest selected time and applies it to every selected day.
WeeklySchedule legacyToWeeklySchedule({
  required Set<String> days,
  required Set<String> times,
}) {
  if (days.isEmpty) return {};

  int? minHour;
  int? maxHour;
  for (final time in times) {
    final hour = _parseLegacyHour(time);
    if (hour == null) continue;
    minHour = minHour == null || hour < minHour ? hour : minHour;
    maxHour = maxHour == null || hour > maxHour ? hour : maxHour;
  }

  final start = minHour ?? 9;
  final endCandidate = (maxHour ?? 16) + 1;
  final end = endCandidate > start ? endCandidate : start + 1;

  final availability = DayAvailability.of(start: start, end: end);
  return {for (final day in days) day: availability};
}
