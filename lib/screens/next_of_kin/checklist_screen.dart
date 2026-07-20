import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── Support Checklist (Next of Kin) ───────────────────────────────────
// Backed by Supabase (checklist_templates + checklist_items — see
// supabase/migrations/add_checklist_tables.sql). On first load the user's
// checklist_items are materialised from checklist_templates. Ticking a box
// saves immediately; adding/editing/deleting items is staged locally while
// in edit mode and only pushed to Supabase when Save is tapped (Cancel
// discards the staged changes without touching the database).
class ChecklistItem {
  final String id; // real Supabase uuid, or 'temp-N' for an unsaved new item
  String text;
  bool isCompleted;
  ChecklistItem({required this.id, required this.text, this.isCompleted = false});
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
}

// Groups the flat checklist_items rows into phases/categories, preserving
// first-seen order (rows come pre-sorted by display_order, so this lines
// up with the intended phase/category sequence without needing it stored
// separately).
List<ChecklistPhase> _phasesFromRows(List<Map<String, dynamic>> rows) {
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

class NextOfKinChecklistScreen extends StatefulWidget {
  const NextOfKinChecklistScreen({super.key});
  @override
  State<NextOfKinChecklistScreen> createState() =>
      _NextOfKinChecklistScreenState();
}

class _NextOfKinChecklistScreenState extends State<NextOfKinChecklistScreen> {
  Map<String, dynamic>? _linkedMum;
  bool _loading = true;
  List<ChecklistPhase> _phases = [];

  bool _editing = false;
  bool _saving = false;
  List<ChecklistPhase>? _phasesSnapshot;
  int _tempIdCounter = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic>? mum;
    List<Map<String, dynamic>> rows = [];
    try {
      mum = await SupabaseService.getLinkedMum();
    } catch (_) {}
    if (mum != null) {
      try {
        rows = await SupabaseService.getOrCreateChecklistItems();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _linkedMum = mum;
        _phases = _phasesFromRows(rows);
        _loading = false;
      });
    }
  }

  // 0-2 for trimesters 1-3; postpartum (index 3) has no real-data signal
  // to auto-detect yet (no "has given birth" flag), so it's just browsable.
  int get _currentPhaseIndex {
    final week = (_linkedMum?['current_week'] as int?) ?? 0;
    if (week <= 12) return 0;
    if (week <= 27) return 1;
    return 2;
  }

  int _phaseTotal(ChecklistPhase phase) =>
      phase.categories.fold(0, (sum, c) => sum + c.items.length);

  int _phaseDone(ChecklistPhase phase) => phase.categories
      .fold(0, (sum, c) => sum + c.items.where((i) => i.isCompleted).length);

  Future<void> _toggleCompleted(ChecklistItem item) async {
    final newValue = !item.isCompleted;
    setState(() => item.isCompleted = newValue);
    try {
      await SupabaseService.setChecklistItemCompleted(item.id, newValue);
    } catch (e) {
      if (mounted) {
        setState(() => item.isCompleted = !newValue);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not update: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  void _startEditing() {
    setState(() {
      _phasesSnapshot = _phases.map((p) => p.copy()).toList();
      _editing = true;
    });
  }

  void _cancelEditing() {
    setState(() {
      _phases = _phasesSnapshot!;
      _phasesSnapshot = null;
      _editing = false;
    });
  }

  Future<void> _saveEditing() async {
    final snapshotById = <String, ChecklistItem>{};
    for (final p in _phasesSnapshot!) {
      for (final c in p.categories) {
        for (final i in c.items) snapshotById[i.id] = i;
      }
    }

    final currentIds = <String>{};
    final futures = <Future>[];
    var nextOrder = 1000;

    for (final phase in _phases) {
      for (final category in phase.categories) {
        for (final item in category.items) {
          if (item.id.startsWith('temp-')) {
            futures.add(SupabaseService.addChecklistItem(
              phase: phase.label,
              phaseEmoji: phase.emoji,
              category: category.title,
              itemText: item.text,
              displayOrder: nextOrder++,
            ));
          } else {
            currentIds.add(item.id);
            final original = snapshotById[item.id];
            if (original != null && original.text != item.text) {
              futures.add(
                  SupabaseService.updateChecklistItemText(item.id, item.text));
            }
          }
        }
      }
    }
    for (final id in snapshotById.keys) {
      if (!currentIds.contains(id)) {
        futures.add(SupabaseService.deleteChecklistItem(id));
      }
    }

    setState(() {
      _saving = true;
      _editing = false;
      _phasesSnapshot = null;
    });

    try {
      await Future.wait(futures);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Some changes failed to save: $e'),
            backgroundColor: Colors.red));
      }
    }
    await _load();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _editItemDialog(ChecklistItem item) async {
    final ctrl = TextEditingController(text: item.text);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Task'),
        content: TextField(controller: ctrl, autofocus: true, maxLines: 3),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => item.text = result);
    }
  }

  Future<void> _addItemDialog(ChecklistCategory category) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Task'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration:
              const InputDecoration(hintText: 'e.g. Pack the hospital bag'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => category.items
          .add(ChecklistItem(id: 'temp-${_tempIdCounter++}', text: result)));
    }
  }

  void _deleteItem(ChecklistCategory category, ChecklistItem item) {
    setState(() => category.items.remove(item));
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = !_loading && _linkedMum != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Checklist'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (canEdit)
            if (_editing) ...[
              TextButton(
                  onPressed: _cancelEditing, child: const Text('Cancel')),
              TextButton(
                  onPressed: _saveEditing,
                  child: const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.w700))),
            ] else
              IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _startEditing),
        ],
      ),
      body: _loading
          ? const TBLoading()
          : _linkedMum == null
              ? TBEmptyState(
                  emoji: '📋',
                  title: 'Not linked yet',
                  subtitle:
                      "Link to a pregnant user's account to see her support checklist.",
                  buttonLabel: 'Link to Pregnant User',
                  onButton: () => context.push('/next-of-kin/link'),
                )
              : _buildChecklist(),
    );
  }

  Widget _buildChecklist() {
    final totalItems = _phases.fold(0, (sum, p) => sum + _phaseTotal(p));
    final totalDone = _phases.fold(0, (sum, p) => sum + _phaseDone(p));
    final overallProgress = totalItems == 0 ? 0.0 : totalDone / totalItems;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.rose,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Pregnancy Support Plan',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 20)),
            const SizedBox(height: 4),
            Text('$totalDone of $totalItems tasks completed',
                style:
                    const TextStyle(color: AppColors.textMid, fontSize: 13)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: overallProgress,
              backgroundColor: AppColors.rose.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.rose),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 20),
            for (int i = 0; i < _phases.length; i++)
              _phaseSection(_phases[i],
                  initiallyExpanded: i == _currentPhaseIndex),
          ],
        ),
      ),
    );
  }

  Widget _phaseSection(ChecklistPhase phase, {required bool initiallyExpanded}) {
    final done = _phaseDone(phase);
    final total = _phaseTotal(phase);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TBCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            iconColor: AppColors.rose,
            collapsedIconColor: AppColors.textLight,
            title: Row(
              children: [
                Text(phase.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(phase.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: done == total
                        ? AppColors.sage.withValues(alpha: 0.15)
                        : AppColors.rose.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text('$done/$total',
                      style: TextStyle(
                          color: done == total ? AppColors.sage : AppColors.roseDeep,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            children: [
              for (final category in phase.categories) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Text(category.title.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.roseDeep,
                            letterSpacing: 0.5)),
                  ),
                ),
                for (final item in category.items) _checklistTile(category, item),
                if (_editing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, top: 2),
                    child: GestureDetector(
                      onTap: () => _addItemDialog(category),
                      child: const Row(
                        children: [
                          Icon(Icons.add_circle_outline,
                              color: AppColors.rose, size: 18),
                          SizedBox(width: 8),
                          Text('Add item',
                              style: TextStyle(
                                  color: AppColors.rose,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _checklistTile(ChecklistCategory category, ChecklistItem item) {
    final done = item.isCompleted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _toggleCompleted(item),
            child: Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? AppColors.sage : AppColors.textLight,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _editing ? () => _editItemDialog(item) : null,
              child: Text(item.text,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: done ? AppColors.textLight : AppColors.textDark,
                      decoration:
                          done ? TextDecoration.lineThrough : TextDecoration.none)),
            ),
          ),
          if (_editing)
            GestureDetector(
              onTap: () => _deleteItem(category, item),
              child: const Padding(
                padding: EdgeInsets.only(left: 8, top: 1),
                child: Icon(Icons.close, color: Colors.red, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}
