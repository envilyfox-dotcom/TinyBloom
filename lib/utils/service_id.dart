// Formats a volunteer_services.service_number into the short reference code
// shown to volunteers and mums, e.g. "VOL-Service(00001)".
String formatServiceId(dynamic serviceNumber) {
  final n = serviceNumber is num
      ? serviceNumber.toInt()
      : int.tryParse(serviceNumber?.toString() ?? '');
  if (n == null) return '';
  return 'VOL-Service(${n.toString().padLeft(5, '0')})';
}
