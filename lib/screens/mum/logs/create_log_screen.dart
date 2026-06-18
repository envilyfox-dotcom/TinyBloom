import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import 'logs_shared.dart';

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
      _selectedSymptoms.addAll(asStringList(log['symptoms']));
      _selectedMilestones.addAll(asStringList(log['milestones']));
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
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
              children: moodOptions.map((m) {
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
