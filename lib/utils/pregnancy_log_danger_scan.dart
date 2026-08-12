// Supabase can hand us a symptoms array either as a real Dart List (normal
// case) or as a raw Postgres array literal string like "{a,b,c}" (happens
// with some query paths), so this normalizes either shape into a clean list.
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

// Combines a log's symptoms + free-text notes into one lowercased string so
// dangerSymptomMatches can do simple substring checks against both at once.
String cleanHealthText(List<String> symptoms, String notes) {
  final parts = <String>[];
  if (symptoms.isNotEmpty) parts.add(symptoms.join(', '));
  if (notes.trim().isNotEmpty) parts.add(notes.trim());
  return parts.join(' ').toLowerCase();
}

// Keyword list of pregnancy warning signs (things like bleeding, severe
// headache, reduced baby movement) that trigger a next-of-kin emergency
// alert. This is a simple substring scan, not medical software - it's meant
// to catch obvious red flags in what the mum typed, not diagnose anything.
// Every matching keyword is reported (e.g. a log with "severe headache" logs
// both that and the plainer "bleeding" check if both phrases are present).
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

// Whether a single pregnancy_logs row mentions any danger symptom - used to
// decide if the next of kin should be alerted about this log.
bool pregnancyLogHasDangerSymptom(Map<String, dynamic> log) {
  final symptoms = stringListFromArray(log['symptoms']);
  final notes = (log['notes'] ?? '').toString();
  return dangerSymptomMatches(cleanHealthText(symptoms, notes)).isNotEmpty;
}
