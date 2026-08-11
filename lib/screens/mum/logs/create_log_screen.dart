import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/singapore_time.dart';
import 'logs_shared.dart';

class CreateLogScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const CreateLogScreen({super.key, this.existing});

  @override
  State<CreateLogScreen> createState() => _CreateLogScreenState();
}

class _CreateLogScreenState extends State<CreateLogScreen> {
  DateTime _date = sgtNow();
  bool _loading = false;
  bool _optionsLoading = true;

  final _notesCtrl = TextEditingController();
  final _otherSymptomCtrl = TextEditingController();
  final _otherMilestoneCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  List<String> _allSymptoms = [];
  final Set<String> _selectedSymptoms = {};

  List<String> _allMoods = [];
  String _selectedMood = '';

  List<String> _allMilestones = [];
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
      final existingDate = sgtDateFrom(log['log_date']);
      if (existingDate != null) _date = existingDate;
      if (log['weight_kg'] != null) _weightCtrl.text = '${log['weight_kg']}';
    } else {
      _prefillWeightFromProfile();
    }
    _loadOptions();
  }

  Future<void> _prefillWeightFromProfile() async {
    try {
      final profile = await SupabaseService.getPregnancyProfile();
      final weight = profile?['weight_kg'];
      if (mounted && weight != null && _weightCtrl.text.isEmpty) {
        setState(() => _weightCtrl.text = '$weight');
      }
    } catch (_) {}
  }

  Future<void> _loadOptions() async {
    try {
      final options = await SupabaseService.getPregnancyLogOptions();
      if (mounted) {
        setState(() {
          _allMoods = options['mood'] ?? [];
          _allSymptoms = options['symptom'] ?? [];
          _allMilestones = options['milestone'] ?? [];
          _optionsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _optionsLoading = false);
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _otherSymptomCtrl.dispose();
    _otherMilestoneCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _addOther(TextEditingController ctrl, Set<String> selectedItems) {
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    final exists =
        selectedItems.any((s) => s.toLowerCase() == text.toLowerCase());
    setState(() {
      if (!exists) selectedItems.add(text);
      ctrl.clear();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: sgtNow().subtract(const Duration(days: 365)),
      lastDate: sgtNow(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.rose),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = asSgtWallClock(picked));
  }

  Future<void> _save() async {
    if (_selectedMood.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a mood.')));
      return;
    }

    double? weight;
    if (_weightCtrl.text.trim().isNotEmpty) {
      weight = double.tryParse(_weightCtrl.text.trim());
      if (weight == null || weight < 30 || weight > 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please enter a valid weight in kg.')));
        return;
      }
    }

    setState(() => _loading = true);

    final data = <String, dynamic>{
      'notes': _notesCtrl.text.trim(),
      'mood': _selectedMood,
      'symptoms': _selectedSymptoms.isEmpty ? null : _selectedSymptoms.toList(),
      'milestones':
          _selectedMilestones.isEmpty ? null : _selectedMilestones.toList(),
      'log_date': dateOnly(_date),
      'weight_kg': weight,
    };

    try {
      if (widget.existing != null) {
        await SupabaseService.updateLog(widget.existing!['id'], data);
      } else {
        await SupabaseService.createLog(data);
      }
      if (weight != null) {
        await SupabaseService.savePregnancyProfile({'weight_kg': weight});
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
              if (_optionsLoading)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._allMoods,
                    if (_selectedMood.isNotEmpty &&
                        !_allMoods.contains(_selectedMood))
                      _selectedMood,
                  ].map((label) {
                    final sel = _selectedMood == label;
                    return _moodChip(
                      emoji: moodEmoji(label),
                      label: label,
                      selected: sel,
                      onTap: () =>
                          setState(() => _selectedMood = sel ? '' : label),
                    );
                  }).toList(),
                ),
            ]),
            _sectionCard('⚖️ Weight (Optional)', [
              TextFormField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: 'Enter your weight',
                  suffixText: 'kg',
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'This updates the weight shown on your profile.',
                style: TextStyle(color: AppColors.textLight, fontSize: 11),
              ),
            ]),
            _sectionCard('🤒 Symptoms', [
              if (_optionsLoading)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ))
              else
                _chipWrap(
                  items: [
                    ..._allSymptoms,
                    ..._selectedSymptoms
                        .where((s) => !_allSymptoms.contains(s)),
                  ],
                  selectedItems: _selectedSymptoms,
                  selectedColor: AppColors.blush,
                  selectedTextColor: AppColors.roseDeep,
                  selectedBorderColor: AppColors.rose,
                ),
              const SizedBox(height: 10),
              _otherInput(
                controller: _otherSymptomCtrl,
                selectedItems: _selectedSymptoms,
              ),
            ]),
            _sectionCard('🌟 Baby Milestones', [
              if (_optionsLoading)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ))
              else
                _chipWrap(
                  items: [
                    ..._allMilestones,
                    ..._selectedMilestones
                        .where((s) => !_allMilestones.contains(s)),
                  ],
                  selectedItems: _selectedMilestones,
                  selectedColor: AppColors.tealLight,
                  selectedTextColor: AppColors.teal,
                  selectedBorderColor: AppColors.teal,
                ),
              const SizedBox(height: 10),
              _otherInput(
                controller: _otherMilestoneCtrl,
                selectedItems: _selectedMilestones,
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

  Widget _otherInput({
    required TextEditingController controller,
    required Set<String> selectedItems,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Other (please specify)',
              hintStyle: const TextStyle(fontSize: 13),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: AppColors.textLight.withValues(alpha: 0.3)),
              ),
            ),
            onSubmitted: (_) => _addOther(controller, selectedItems),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _addOther(controller, selectedItems),
          icon: const Icon(Icons.add_circle, color: AppColors.rose),
        ),
      ],
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
