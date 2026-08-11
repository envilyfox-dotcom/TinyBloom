import 'package:intl/intl.dart';
import 'singapore_time.dart';

String formatAvailabilityDisplay(String? availability) {
  if (availability == null || availability.isEmpty) return availability ?? '';
  if (!availability.contains(' | ')) return availability;

  final parts = availability.split(' | ');
  final date = DateTime.tryParse(parts[0]);
  if (date == null) return availability;

  final dateStr = DateFormat('dd/MM/yyyy').format(date);
  return parts.length > 1 ? '$dateStr | ${parts[1]}' : dateStr;
}

const _availabilityTimingEndHour = {
  'Morning (9AM - 12PM)': 12,
  'Afternoon (12PM - 3PM)': 15,
  'Evening (3PM - 6PM)': 18,
  'Night (6PM - 9PM)': 21,
};

/// Parses a `yyyy-MM-dd | <timing>` availability string into the Singapore
/// wall-clock instant it ends, or null if it can't be parsed. `<timing>`
/// is either a free-form range like `9:00 AM - 10:00 AM` or one of the
/// named blocks in [_availabilityTimingEndHour].
DateTime? parseAvailabilityEndTime(String? availability) {
  if (availability == null || !availability.contains(' | ')) return null;
  final parts = availability.split(' | ');
  final date = DateTime.tryParse(parts[0]);
  if (date == null) return null;
  final timing = parts.length > 1 ? parts[1] : '';

  final match =
      RegExp(r'-\s*(\d{1,2}:\d{2}\s?[AaPp][Mm])\s*$').firstMatch(timing);
  if (match != null) {
    try {
      final parsed = DateFormat('h:mm a').parse(match.group(1)!.toUpperCase());
      return sgtWallClock(
          date.year, date.month, date.day, parsed.hour, parsed.minute);
    } catch (_) {
      return null;
    }
  }

  final namedEndHour = _availabilityTimingEndHour[timing];
  if (namedEndHour != null) {
    return sgtWallClock(date.year, date.month, date.day, namedEndHour);
  }

  return null;
}

/// True once the slot described by [availability] has ended, relative to
/// [now] (defaults to the current Singapore time). Used to hide/exclude
/// listings that a volunteer hasn't manually marked as done yet.
bool isAvailabilityExpired(String? availability, {DateTime? now}) {
  final endsAt = parseAvailabilityEndTime(availability);
  if (endsAt == null) return false;
  return (now ?? sgtNow()).isAfter(endsAt);
}

/// True when a `type: 'services'` notification row should no longer be
/// shown: either its snapshotted slot has expired, or it predates the
/// `service_availability` column and carries no snapshot to check at all
/// (a legacy row that can never be verified as still relevant).
bool isStaleServiceNotification(Map<String, dynamic> item) {
  if (item['type'] != 'services') return false;
  final availability = item['service_availability'] as String?;
  if (availability == null || availability.trim().isEmpty) return true;
  return isAvailabilityExpired(availability);
}
