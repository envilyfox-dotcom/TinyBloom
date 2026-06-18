import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── Shared mood lookup ────────────────────────────────────────────
const _moodOptions = [
  {'emoji': '😊', 'label': 'Happy', 'color': AppColors.sage},
  {'emoji': '😐', 'label': 'Neutral', 'color': AppColors.textLight},
  {'emoji': '😢', 'label': 'Sad', 'color': AppColors.teal},
  {'emoji': '😴', 'label': 'Tired', 'color': AppColors.rose},
  {'emoji': '😰', 'label': 'Anxious', 'color': AppColors.gold},
  {'emoji': '🥰', 'label': 'Loved', 'color': AppColors.roseDeep},
];

String _moodEmoji(String? mood) {
  if (mood == null || mood.isEmpty) return '📋';
  for (final m in _moodOptions) {
    if (m['label'] == mood) return m['emoji'] as String;
  }
  return '📋';
}

Color _moodColor(String? mood) {
  for (final m in _moodOptions) {
    if (m['label'] == mood) return m['color'] as Color;
  }
  return AppColors.textLight;
}

// Accepts either a Postgres array (returned as a List) or a legacy
// comma-separated string from older rows, and normalizes to a string list.
List<String> _asStringList(Object? value) {
  if (value == null) return const [];
  if (value is List) return value.map((e) => e.toString()).toList();
  return value.toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

// Small "back + logout" app bar shared by the logs screens.
PreferredSizeWidget _logsAppBar(BuildContext context) {
  return AppBar(
    backgroundColor: AppColors.background,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.chevron_left, color: AppColors.textDark),
      onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
    ),
  );
}

// Solid filled pill (light pink "View", dark fills for Edit/Delete).
Widget _pillButton(String label,
    {required Color bg, required Color fg, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
    ),
  );
}

const _viewColor = AppColors.rose;
const _editColor = Color(0xFF6B5B56);
const _deleteColor = Color(0xFF7A1F1F);

// ── Logs List Screen ──────────────────────────────────────────────
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});
  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final logs = await SupabaseService.getLogs();
      if (mounted) setState(() { _logs = logs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Log'),
        content: const Text('Are you sure you want to delete this log?'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Log'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            )),
          ]),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseService.deleteLog(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Logs')),
      body: _loading
          ? const TBLoading()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.rose,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  const Text('Track your daily symptoms, mood and baby milestones',
                    style: TextStyle(color: AppColors.textMid, fontSize: 14)),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: () async { await context.push('/logs/create'); _load(); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.rose, borderRadius: BorderRadius.circular(30)),
                      child: const Text('+ New Log',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_logs.isEmpty)
                    TBEmptyState(
                      emoji: '📋', title: 'No logs yet',
                      subtitle: 'Start tracking your health today.',
                      buttonLabel: 'Add First Log',
                      onButton: () async { await context.push('/logs/create'); _load(); })
                  else
                    ..._logs.map((log) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LogCard(
                        log: log,
                        onView: () async {
                          await context.push('/logs/${log['id']}', extra: log);
                          _load();
                        },
                        onEdit: () async {
                          await context.push('/logs/${log['id']}/edit', extra: log);
                          _load();
                        },
                        onDelete: () => _delete(log['id']),
                      ),
                    )),
                ],
              ),
            ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LogCard({
    required this.log, required this.onView, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final mood = log['mood'] as String?;
    final symptoms = _asStringList(log['symptoms']);
    final date = log['logged_at'] != null ? DateTime.parse(log['logged_at']) : null;

    return TBCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_moodEmoji(mood), style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(date != null ? DateFormat('d MMM yyyy').format(date) : 'Health Log',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            if (date != null)
              Text(DateFormat('EEEE').format(date),
                style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
          ])),
          if (mood != null && mood.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _moodColor(mood).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20)),
              child: Text('Mood: $mood',
                style: TextStyle(color: _moodColor(mood), fontSize: 11, fontWeight: FontWeight.w700)),
            ),
        ]),
        if (symptoms.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text.rich(TextSpan(children: [
            const TextSpan(text: 'Symptoms: ', style: TextStyle(color: AppColors.textMid, fontSize: 13)),
            TextSpan(text: symptoms.join(', '),
              style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 13)),
          ])),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _pillButton('View',
            bg: _viewColor.withValues(alpha: 0.18), fg: AppColors.roseDeep, onTap: onView)),
          const SizedBox(width: 8),
          Expanded(child: _pillButton('Edit', bg: _editColor, fg: Colors.white, onTap: onEdit)),
          const SizedBox(width: 8),
          Expanded(child: _pillButton('Delete', bg: _deleteColor, fg: Colors.white, onTap: onDelete)),
        ]),
      ]),
    );
  }
}

// ── View Log Screen ───────────────────────────────────────────────
class ViewLogScreen extends StatelessWidget {
  final Map<String, dynamic>? log;
  const ViewLogScreen({super.key, this.log});

  Future<void> _delete(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Log'),
        content: const Text('Are you sure you want to delete this log?'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Log'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            )),
          ]),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseService.deleteLog(id);
      if (context.mounted) context.pop();
    }
  }

  Widget _bulletList(List<String> items) {
    if (items.isEmpty) {
      return const Text('—', style: TextStyle(color: AppColors.textLight, fontSize: 13));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((s) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('•  $s', style: const TextStyle(color: AppColors.textMid, fontSize: 14)),
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = log;
    if (entry == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _logsAppBar(context),
        body: const Center(child: Text('Log not found.')),
      );
    }

    final id = entry['id'] as String;
    final mood = entry['mood'] as String?;
    final symptoms = _asStringList(entry['symptoms']);
    final milestones = _asStringList(entry['milestones']);
    final notes = (entry['notes'] as String?) ?? '';
    final date = entry['logged_at'] != null ? DateTime.parse(entry['logged_at']) : null;
    final weight = entry['weight_kg'];
    final kicks = entry['kick_count'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _logsAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(date != null ? DateFormat('d MMMM yyyy').format(date) : 'Health Log',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26)),
          const SizedBox(height: 20),
          TBCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Symptoms', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  _bulletList(symptoms),
                ])),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Mood', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text(_moodEmoji(mood), style: const TextStyle(fontSize: 28)),
                ]),
              ]),
              const SizedBox(height: 20),
              const Text('Baby Milestones', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              _bulletList(milestones),
              const SizedBox(height: 20),
              const Text('Notes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              Text(notes.isEmpty ? 'No notes added.' : notes,
                style: const TextStyle(color: AppColors.textMid, fontSize: 14)),
              if (weight != null) ...[
                const SizedBox(height: 20),
                const Text('Weight', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 8),
                Text('$weight kg', style: const TextStyle(color: AppColors.textMid, fontSize: 14)),
              ],
              if (kicks != null) ...[
                const SizedBox(height: 20),
                const Text('Baby Movement', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 8),
                Text('$kicks kicks', style: const TextStyle(color: AppColors.textMid, fontSize: 14)),
              ],
            ]),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _pillButton('Edit',
              bg: _editColor, fg: Colors.white,
              onTap: () async {
                await context.push('/logs/$id/edit', extra: entry);
                if (context.mounted) context.pop();
              })),
            const SizedBox(width: 12),
            Expanded(child: _pillButton('Delete',
              bg: _deleteColor, fg: Colors.white,
              onTap: () => _delete(context, id))),
          ]),
        ]),
      ),
    );
  }
}

// ── Create / Edit Log ─────────────────────────────────────────────
class CreateLogScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const CreateLogScreen({super.key, this.existing});
  @override
  State<CreateLogScreen> createState() => _CreateLogScreenState();
}

class _CreateLogScreenState extends State<CreateLogScreen> {
  DateTime _date = DateTime.now();
  bool _loading = false;

  final _weightCtrl = TextEditingController();
  final _kickCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final List<String> _allSymptoms = ['Nausea', 'Backache', 'Headache', 'Fatigue', 'Swollen Feet', 'Mood Swings', 'Heartburn', 'Dizziness', 'Insomnia'];
  final Set<String> _selectedSymptoms = {};

  String _selectedMood = '';

  final List<String> _allMilestones = ['First Kick', 'Increased Movement', 'Doctor Visit', 'Ultrasound Scan', 'Baby Shower', 'Nursery Ready'];
  final Set<String> _selectedMilestones = {};

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final log = widget.existing!;
      _weightCtrl.text = log['weight_kg']?.toString() ?? '';
      _kickCtrl.text = log['kick_count']?.toString() ?? '';
      _notesCtrl.text = log['notes'] ?? '';
      _selectedMood = log['mood'] ?? '';
      _selectedSymptoms.addAll(_asStringList(log['symptoms']));
      _selectedMilestones.addAll(_asStringList(log['milestones']));
      if (log['logged_at'] != null) _date = DateTime.parse(log['logged_at']);
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose(); _kickCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.rose)),
        child: child!),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final data = <String, dynamic>{
      'log_type': 'symptoms',
      'notes': _notesCtrl.text.trim(),
      'mood': _selectedMood.isEmpty ? null : _selectedMood,
      'symptoms': _selectedSymptoms.isEmpty ? null : _selectedSymptoms.toList(),
      'milestones': _selectedMilestones.isEmpty ? null : _selectedMilestones.toList(),
      'logged_at': _date.toIso8601String(),
      'weight_kg': double.tryParse(_weightCtrl.text),
      'kick_count': int.tryParse(_kickCtrl.text),
    };

    try {
      if (widget.existing != null) {
        await SupabaseService.updateLog(widget.existing!['id'], data);
      } else {
        await SupabaseService.createLog(data);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Log' : 'Symptoms & Milestones')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Symptoms
          _sectionCard('🤒 Symptoms', [
            Wrap(spacing: 8, runSpacing: 4,
              children: _allSymptoms.map((s) {
                final sel = _selectedSymptoms.contains(s);
                return FilterChip(
                  label: Text(s, style: TextStyle(fontSize: 12,
                    color: sel ? AppColors.roseDeep : AppColors.textMid,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                  selected: sel,
                  onSelected: (_) => setState(() => sel ? _selectedSymptoms.remove(s) : _selectedSymptoms.add(s)),
                  selectedColor: AppColors.blush,
                  checkmarkColor: AppColors.roseDeep,
                  backgroundColor: AppColors.white,
                  side: BorderSide(color: sel ? AppColors.rose : AppColors.textLight.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList()),
          ]),

          // Weight
          _sectionCard('⚖️ Weight', [
            TextFormField(controller: _weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Weight (kg)', suffixText: 'kg')),
          ]),

          // Baby Movement
          _sectionCard('👶 Baby Movement', [
            TextFormField(controller: _kickCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Number of kicks / movements')),
          ]),

          // Baby Milestones
          _sectionCard('🌟 Baby Milestones', [
            Wrap(spacing: 8, runSpacing: 4,
              children: _allMilestones.map((m) {
                final sel = _selectedMilestones.contains(m);
                return FilterChip(
                  label: Text(m, style: TextStyle(fontSize: 12,
                    color: sel ? AppColors.teal : AppColors.textMid,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                  selected: sel,
                  onSelected: (_) => setState(() => sel ? _selectedMilestones.remove(m) : _selectedMilestones.add(m)),
                  selectedColor: AppColors.tealLight,
                  checkmarkColor: AppColors.teal,
                  backgroundColor: AppColors.white,
                  side: BorderSide(color: sel ? AppColors.teal : AppColors.textLight.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList()),
          ]),

          // Mood
          _sectionCard('😊 Mood', [
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _moodOptions.map((m) {
                final label = m['label'] as String;
                final sel = _selectedMood == label;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMood = sel ? '' : label),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.blush : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? AppColors.rose : Colors.transparent, width: 1.5)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(m['emoji'] as String, style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 2),
                      Text(label,
                        style: TextStyle(fontSize: 9, color: sel ? AppColors.roseDeep : AppColors.textLight,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
                    ]),
                  ),
                );
              }).toList()),
          ]),

          // Date
          _sectionCard('📅 Date', [
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.textLight.withValues(alpha: 0.3))),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, color: AppColors.textLight, size: 18),
                  const SizedBox(width: 10),
                  Text(DateFormat('d MMMM yyyy').format(_date),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppColors.textLight, size: 18),
                ]),
              ),
            ),
          ]),

          // Notes
          _sectionCard('📝 Notes (Optional)', [
            TextFormField(
              controller: _notesCtrl, maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Add any additional notes...',
                border: InputBorder.none)),
          ]),

          const SizedBox(height: 20),

          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Log', style: TextStyle(fontWeight: FontWeight.w700)))),
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: AppColors.textDark.withValues(alpha: 0.05),
          blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(
          fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark)),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }
}
