// Formats a database sequence number (volunteer_services.service_number,
// volunteer_requests.request_number) into the short reference code shown to
// volunteers and mums. Distinct prefixes per id type so a code is
// unambiguous even shown without its "Service ID"/"Request ID" label.
String _formatSequentialId(String prefix, dynamic number) {
  final n = number is num
      ? number.toInt()
      : int.tryParse(number?.toString() ?? '');
  if (n == null) return '';
  return '$prefix-${n.toString().padLeft(5, '0')}';
}

String formatServiceId(dynamic serviceNumber) =>
    _formatSequentialId('SVC', serviceNumber);

String formatRequestId(dynamic requestNumber) =>
    _formatSequentialId('REQ', requestNumber);
