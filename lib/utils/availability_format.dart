import 'package:intl/intl.dart';

// A volunteer_services.availability value is stored as
// "yyyy-MM-dd | <timing>" (e.g. "2026-07-22 | 1:40 PM - 2:00 PM"). This
// reformats the date portion to dd/MM/yyyy for display, leaving storage
// untouched so existing parsing (sorting, auto-expiry) keeps working.
String formatAvailabilityDisplay(String? availability) {
  if (availability == null || availability.isEmpty) return availability ?? '';
  if (!availability.contains(' | ')) return availability;

  final parts = availability.split(' | ');
  final date = DateTime.tryParse(parts[0]);
  if (date == null) return availability;

  final dateStr = DateFormat('dd/MM/yyyy').format(date);
  return parts.length > 1 ? '$dateStr | ${parts[1]}' : dateStr;
}
