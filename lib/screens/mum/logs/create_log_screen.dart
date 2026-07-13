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

  final _notesCtrl = TextEditingController();

  final List<String> _allSymptoms = const [
    'Morning sickness',
    'Nausea',
    'Vomiting',
    'Fatigue',
    'Headache',
    'Back pain',
    'Pelvic pain',
    'Round ligament pain',
    'Leg cramps',
    'Swollen feet',
    'Swollen hands',
    'Heartburn',
    'Indigestion',
    'Constipation',
    'Diarrhoea',
    'Bloating',
    'Frequent urination',
    'Breast tenderness',
    'Braxton Hicks contractions',
    'Baby kicking',
    'Reduced baby movement',
    'Dizziness',
    'Shortness of breath',
    'Nasal congestion',
    'Insomnia',
    'Mood swings',
    'Food cravings',
    'Food aversions',
    'Acne',
    'Stretch marks',
    'Itchy skin',
    'Bleeding gums',
    'Varicose veins',
    'Haemorrhoids',
    'Vaginal discharge',
    'Water retention',
    'Hot flashes',
    'Chills',
    'Fever',
    'No symptoms',
  ];

  final Set<String> _selectedSymptoms = {};

  String _selectedMood = '';

  final List<String> _allMilestones = const [
    'Positive pregnancy test',
    'Heartbeat detected',
    'First ultrasound',
    'Dating scan',
    'NT scan',
    'NIPT completed',
    'Baby heartbeat heard',
    'Baby started moving',
    'First kick felt',
    'Partner felt baby kick',
    '20-week anatomy scan',
    'Baby responds to sound',
    'Gender revealed',
    'Baby hiccups',
    'Third trimester begins',
    'Hospital tour completed',
    'Birth plan completed',
    'Hospital bag packed',
    'Car seat installed',
    'Baby shower',
    'Nursery completed',
    'Maternity leave begins',
    'Breastfeeding class completed',
    'Parenting class completed',
    'Baby dropped',
    'Cervix dilating',
    'Labour contractions started',
    'Water broke',
    'Delivery day',
    'Baby born',
    'Skin-to-skin completed',
    'First breastfeed',
    'Discharged home',
    'First paediatric visit',
    'Postpartum check-up',
  ];

  final Set<String> _selectedMilestones = {};

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final log = widget.existing!;
      _notesCtrl.text = log['notes'] ?? '';
      _selectedMood = log['mood'] ?? '';
      _selectedSymptoms.addAll(asStringList(log['symptoms']));
      _selectedMilestones.addAll(asStringList(log['milestones']));
      if (log['log_date'] != null) _date = DateTime.parse(log['log_date']);
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.rose),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_selectedMood.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a mood.')));
      return;
    }

    setState(() => _loading = true);

    final data = <String, dynamic>{
      'notes': _notesCtrl.text.trim(),
      'mood': _selectedMood,
      'symptoms': _selectedSymptoms.isEmpty ? null : _selectedSymptoms.toList(),
      'milestones':
          _selectedMilestones.isEmpty ? null : _selectedMilestones.toList(),
      'log_date': DateFormat('yyyy-MM-dd').format(_date),
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
        title: Text(isEdit ? 'Edit Log' : 'Symptoms & Milestones'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard('😊 Mood', [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: moodOptions.map((m) {
                  final label = m['label'] as String;
                  final sel = _selectedMood == label;
                  return _moodChip(
                    emoji: m['emoji'] as String,
                    label: label,
                    selected: sel,
                    onTap: () =>
                        setState(() => _selectedMood = sel ? '' : label),
                  );
                }).toList(),
              ),
            ]),
            _sectionCard('🤒 Symptoms', [
              _chipWrap(
                items: _allSymptoms,
                selectedItems: _selectedSymptoms,
                selectedColor: AppColors.blush,
                selectedTextColor: AppColors.roseDeep,
                selectedBorderColor: AppColors.rose,
              ),
            ]),
            _sectionCard('🌟 Baby Milestones', [
              _chipWrap(
                items: _allMilestones,
                selectedItems: _selectedMilestones,
                selectedColor: AppColors.tealLight,
                selectedTextColor: AppColors.teal,
                selectedBorderColor: AppColors.teal,
              ),
            ]),
            _sectionCard('📅 Date', [
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.textLight.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: AppColors.textLight, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          DateFormat('d MMMM yyyy').format(_date),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textLight, size: 18),
                    ],
                  ),
                ),
              ),
            ]),
            _sectionCard('📝 Notes (Optional)', [
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Add any additional notes...',
                  border: InputBorder.none,
                ),
              ),
            ]),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Log',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _chipWrap({
    required List<String> items,
    required Set<String> selectedItems,
    required Color selectedColor,
    required Color selectedTextColor,
    required Color selectedBorderColor,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final sel = selectedItems.contains(item);
        return FilterChip(
          label: Text(
            item,
            style: TextStyle(
              fontSize: 12,
              color: sel ? selectedTextColor : AppColors.textMid,
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          selected: sel,
          onSelected: (_) => setState(
            () => sel ? selectedItems.remove(item) : selectedItems.add(item),
          ),
          selectedColor: selectedColor,
          checkmarkColor: selectedTextColor,
          backgroundColor: AppColors.white,
          side: BorderSide(
            color: sel
                ? selectedBorderColor
                : AppColors.textLight.withValues(alpha: 0.3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }

  Widget _moodChip({
    required String emoji,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 82,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.blush : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.rose
                : AppColors.textLight.withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: selected ? AppColors.roseDeep : AppColors.textLight,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
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
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
