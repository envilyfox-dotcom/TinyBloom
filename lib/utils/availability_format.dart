import 'package:intl/intl.dart';

String formatAvailabilityDisplay(String? availability) {
  if (availability == null || availability.isEmpty) return availability ?? '';
  if (!availability.contains(' | ')) return availability;

  final parts = availability.split(' | ');
  final date = DateTime.tryParse(parts[0]);
  if (date == null) return availability;

  final dateStr = DateFormat('dd/MM/yyyy').format(date);
  return parts.length > 1 ? '$dateStr | ${parts[1]}' : dateStr;
}
