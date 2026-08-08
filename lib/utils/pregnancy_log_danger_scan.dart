List<String> stringListFromArray(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) {
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  final text = raw.toString().trim();
  if (text.isEmpty) return [];
  return text
      .replaceAll('{', '')
      .replaceAll('}', '')
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String cleanHealthText(List<String> symptoms, String notes) {
  final parts = <String>[];
  if (symptoms.isNotEmpty) parts.add(symptoms.join(', '));
  if (notes.trim().isNotEmpty) parts.add(notes.trim());
  return parts.join(' ').toLowerCase();
}

List<String> dangerSymptomMatches(String combinedText) {
  final checks = <String, String>{
    'heavy bleeding': 'Heavy bleeding reported',
    'bleeding': 'Bleeding reported',
    'severe headache': 'Severe headache reported',
    'blurred vision': 'Blurred vision reported',
    'vision changes': 'Vision changes reported',
    'chest pain': 'Chest pain reported',
    'shortness of breath': 'Shortness of breath reported',
    'breathless': 'Breathlessness reported',
    'severe abdominal pain': 'Severe abdominal pain reported',
    'fainting': 'Fainting reported',
    'seizure': 'Seizure reported',
    'fever': 'Fever reported',
    'reduced movement': 'Reduced baby movement reported',
    'less movement': 'Reduced baby movement reported',
    'no movement': 'No baby movement reported',
    'swelling': 'Sudden swelling reported',
    'contractions': 'Contractions reported',
    'water broke': 'Possible water breaking reported',
    'fluid leakage': 'Fluid leakage reported',
  };

  final matches = <String>[];
  for (final entry in checks.entries) {
    if (combinedText.contains(entry.key) && !matches.contains(entry.value)) {
      matches.add(entry.value);
    }
  }
  return matches;
}

/// Whether a single pregnancy_logs row contains a danger-symptom match.
bool pregnancyLogHasDangerSymptom(Map<String, dynamic> log) {
  final symptoms = stringListFromArray(log['symptoms']);
  final notes = (log['notes'] ?? '').toString();
  return dangerSymptomMatches(cleanHealthText(symptoms, notes)).isNotEmpty;
}
