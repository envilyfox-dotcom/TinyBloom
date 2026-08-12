// Turns a raw sequence number into a display id like "SVC-00042".
String _formatSequentialId(String prefix, dynamic number) {
  final n =
      number is num ? number.toInt() : int.tryParse(number?.toString() ?? '');
  if (n == null) return '';
  return '$prefix-${n.toString().padLeft(5, '0')}';
}

String formatServiceId(dynamic serviceNumber) =>
    _formatSequentialId('SVC', serviceNumber);

String formatRequestId(dynamic requestNumber) =>
    _formatSequentialId('REQ', requestNumber);
