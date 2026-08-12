import 'package:shared_preferences/shared_preferences.dart';

class ChecklistItem {
  final String id; // real Supabase uuid, or 'temp-N' for an unsaved new item
  String text;
  bool isCompleted;
  ChecklistItem(
      {required this.id, required this.text, this.isCompleted = false});
  ChecklistItem copy() =>
      ChecklistItem(id: id, text: text, isCompleted: isCompleted);
}

class ChecklistCategory {
  final String title;
  final List<ChecklistItem> items;
  ChecklistCategory({required this.title, required this.items});
  ChecklistCategory copy() => ChecklistCategory(
      title: title, items: items.map((i) => i.copy()).toList());
}

class ChecklistPhase {
  final String label;
  final String emoji;
  final List<ChecklistCategory> categories;
  ChecklistPhase(
      {required this.label, required this.emoji, required this.categories});
  ChecklistPhase copy() => ChecklistPhase(
      label: label,
      emoji: emoji,
      categories: categories.map((c) => c.copy()).toList());

  List<ChecklistItem> get allItems => [for (final c in categories) ...c.items];
}

// Supabase gives us a flat list of checklist item rows; this groups them
// back into phases -> categories -> items, keeping the order things first
// appear in (not alphabetical) so it matches how they were set up in the db.
List<ChecklistPhase> phasesFromRows(List<Map<String, dynamic>> rows) {
  final phaseOrder = <String>[];
  final phaseEmojis = <String, String>{};
  final categoryOrderByPhase = <String, List<String>>{};
  final itemsByPhaseCategory = <String, Map<String, List<ChecklistItem>>>{};

  for (final row in rows) {
    final phase = row['phase'] as String;
    final category = row['category'] as String;
    if (!phaseOrder.contains(phase)) {
      phaseOrder.add(phase);
      phaseEmojis[phase] = row['phase_emoji'] as String? ?? '';
      categoryOrderByPhase[phase] = [];
      itemsByPhaseCategory[phase] = {};
    }
    if (!categoryOrderByPhase[phase]!.contains(category)) {
      categoryOrderByPhase[phase]!.add(category);
      itemsByPhaseCategory[phase]![category] = [];
    }
    itemsByPhaseCategory[phase]![category]!.add(ChecklistItem(
      id: row['id'] as String,
      text: row['item_text'] as String,
      isCompleted: row['is_completed'] as bool? ?? false,
    ));
  }

  return [
    for (final phase in phaseOrder)
      ChecklistPhase(
        label: phase,
        emoji: phaseEmojis[phase] ?? '',
        categories: [
          for (final category in categoryOrderByPhase[phase]!)
            ChecklistCategory(
                title: category,
                items: itemsByPhaseCategory[phase]![category]!),
        ],
      ),
  ];
}

int phaseTotal(ChecklistPhase phase) =>
    phase.categories.fold(0, (sum, c) => sum + c.items.length);

int phaseDone(ChecklistPhase phase) => phase.categories
    .fold(0, (sum, c) => sum + c.items.where((i) => i.isCompleted).length);

// Remembers which checklist phase tab the user last had open.
const _kCurrentPhaseIndexKey = 'next_of_kin_current_checklist_phase_index';

Future<int> getCurrentChecklistPhaseIndex() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_kCurrentPhaseIndexKey) ?? 0;
}

Future<void> setCurrentChecklistPhaseIndex(int index) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kCurrentPhaseIndexKey, index);
}
