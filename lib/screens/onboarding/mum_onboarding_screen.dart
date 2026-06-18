import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import 'package:intl/intl.dart';

class MumOnboardingScreen extends StatefulWidget {
  const MumOnboardingScreen({super.key});

  @override
  State<MumOnboardingScreen> createState() => _MumOnboardingScreenState();
}

class _MumOnboardingScreenState extends State<MumOnboardingScreen> {
  final PageController _page = PageController();
  int _step = 0;
  bool _saving = false;
  String? _error;

  // Step 1 – About You
  final _ageCtrl = TextEditingController();
  String _pregnancyStatus = '';

  // Step 2 – Your Pregnancy
  DateTime? _dueDate;

  // Step 3 – Health Details
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final Set<String> _conditions = {};
  final _allergiesCtrl = TextEditingController();
  final _otherConditionCtrl = TextEditingController();

  // Step 4 – Interests & Support
  final Set<String> _interests = {};
  final Set<String> _consultationNeeds = {};

  static const _statuses = [
    'First Pregnancy',
    'Second Pregnancy',
    'Third+ Pregnancy',
    'Expecting Twins / Multiples',
  ];

  static const _conditionOptions = [
    'None',
    'Gestational Diabetes',
    'Hypertension',
    'Anaemia',
    'Thyroid Disorder',
    'Asthma',
    'Depression / Anxiety',
    'Back Pain',
    'Other',
  ];

  static const _interestOptions = [
    'Nutrition & Diet',
    'Exercise & Fitness',
    'Mental Health',
    'Baby Development',
    'Birth Preparation',
    'Breastfeeding',
    'Postnatal Care',
    'Partner Support',
  ];

  static const _consultationOptions = [
    'Midwife',
    'Nutritionist',
    'Physiotherapist',
    'Mental Health Counsellor',
    'Lactation Consultant',
    'General Practitioner',
  ];

  @override
  void dispose() {
    _page.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _allergiesCtrl.dispose();
    _otherConditionCtrl.dispose();
    super.dispose();
  }

  int get _pregnancyWeek {
    if (_dueDate == null) return 0;
    final conception = _dueDate!.subtract(const Duration(days: 280));
    return DateTime.now().difference(conception).inDays ~/ 7;
  }

  void _next() {
    if (_step < 3) {
      _page.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      _page.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _step--);
    }
  }

  Future<void> _submit() async {
    setState(() { _saving = true; _error = null; });
    try {
      await SupabaseService.savePregnancyProfile({
        'age': int.tryParse(_ageCtrl.text),
        'pregnancy_status': _pregnancyStatus.isEmpty ? null : _pregnancyStatus,
        'due_date': _dueDate?.toIso8601String().split('T').first,
        'pregnancy_week': _dueDate != null ? _pregnancyWeek : null,
        'height_cm': double.tryParse(_heightCtrl.text),
        'weight_kg': double.tryParse(_weightCtrl.text),
        'medical_conditions': () {
          if (_conditions.isEmpty) return null;
          final list = _conditions.toList();
          final otherText = _otherConditionCtrl.text.trim();
          if (list.contains('Other') && otherText.isNotEmpty) {
            list[list.indexOf('Other')] = 'Other: $otherText';
          }
          return list.join(', ');
        }(),
        'allergies': _allergiesCtrl.text.trim().isEmpty
            ? null
            : _allergiesCtrl.text.trim(),
        'areas_of_interest':
            _interests.isEmpty ? null : _interests.join(', '),
        'consultation_needs':
            _consultationNeeds.isEmpty ? null : _consultationNeeds.join(', '),
      });
      if (mounted) {
        await context.read<AuthProvider>().refreshProfile();
        if (mounted) context.go('/home');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please check your connection and try again.');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepAboutYou(
                    ageCtrl: _ageCtrl,
                    pregnancyStatus: _pregnancyStatus,
                    statuses: _statuses,
                    onStatusChanged: (v) => setState(() => _pregnancyStatus = v),
                  ),
                  _StepYourPregnancy(
                    dueDate: _dueDate,
                    pregnancyWeek: _pregnancyWeek,
                    onDatePicked: (d) => setState(() => _dueDate = d),
                  ),
                  _StepHealthDetails(
                    heightCtrl: _heightCtrl,
                    weightCtrl: _weightCtrl,
                    conditions: _conditions,
                    conditionOptions: _conditionOptions,
                    allergiesCtrl: _allergiesCtrl,
                    otherConditionCtrl: _otherConditionCtrl,
                    onConditionToggled: (c) => setState(() {
                      if (c == 'None') {
                        if (_conditions.contains('None')) {
                          _conditions.remove('None');
                        } else {
                          _conditions.clear();
                          _conditions.add('None');
                        }
                      } else {
                        _conditions.remove('None');
                        _conditions.contains(c)
                            ? _conditions.remove(c)
                            : _conditions.add(c);
                      }
                    }),
                  ),
                  _StepInterests(
                    interests: _interests,
                    interestOptions: _interestOptions,
                    consultationNeeds: _consultationNeeds,
                    consultationOptions: _consultationOptions,
                    onInterestToggled: (i) => setState(() =>
                        _interests.contains(i)
                            ? _interests.remove(i)
                            : _interests.add(i)),
                    onConsultationToggled: (c) => setState(() =>
                        _consultationNeeds.contains(c)
                            ? _consultationNeeds.remove(c)
                            : _consultationNeeds.add(c)),
                  ),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final titles = [
      'About You',
      'Your Pregnancy',
      'Health Details',
      'Interests & Support',
    ];
    final subtitles = [
      'Tell us a little about yourself',
      'Help us personalise your experience',
      'So we can give you the best advice',
      "What matters most to you right now",
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      color: AppColors.blush,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌸', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              const Text('Getting Started',
                  style: TextStyle(
                      color: AppColors.roseDeep,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              const Spacer(),
              Text('${_step + 1} / 4',
                  style: const TextStyle(
                      color: AppColors.textMid, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: i <= _step ? AppColors.rose : AppColors.rose.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Text(titles[_step],
              style: const TextStyle(
                  color: AppColors.roseDeep,
                  fontWeight: FontWeight.w800,
                  fontSize: 22)),
          const SizedBox(height: 2),
          Text(subtitles[_step],
              style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _error = null),
                    child: const Icon(Icons.close, color: Colors.red, size: 16),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _back,
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Back'),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _saving ? null : _next,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          _step == 3 ? 'Complete Setup' : 'Next',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Step 1: About You ────────────────────────────────────────────────
class _StepAboutYou extends StatelessWidget {
  final TextEditingController ageCtrl;
  final String pregnancyStatus;
  final List<String> statuses;
  final ValueChanged<String> onStatusChanged;

  const _StepAboutYou({
    required this.ageCtrl,
    required this.pregnancyStatus,
    required this.statuses,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card('🎂 Your Age', [
            TextFormField(
              controller: ageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Age', suffixText: 'years'),
            ),
          ]),
          const SizedBox(height: 12),
          _card('🤰 Pregnancy Status', [
            ...statuses.map((s) {
              final sel = pregnancyStatus == s;
              return GestureDetector(
                onTap: () => onStatusChanged(s),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.blush : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: sel
                            ? AppColors.rose
                            : AppColors.textLight.withValues(alpha: 0.3),
                        width: sel ? 1.5 : 1),
                  ),
                  child: Text(s,
                      style: TextStyle(
                          fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                          color: sel
                              ? AppColors.roseDeep
                              : AppColors.textDark,
                          fontSize: 14)),
                ),
              );
            }),
          ]),
        ],
      ),
    );
  }
}

// ── Step 2: Your Pregnancy ───────────────────────────────────────────
class _StepYourPregnancy extends StatelessWidget {
  final DateTime? dueDate;
  final int pregnancyWeek;
  final ValueChanged<DateTime> onDatePicked;

  const _StepYourPregnancy({
    required this.dueDate,
    required this.pregnancyWeek,
    required this.onDatePicked,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card('📅 Due Date', [
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: dueDate ??
                      DateTime.now().add(const Duration(days: 140)),
                  firstDate: DateTime.now(),
                  lastDate:
                      DateTime.now().add(const Duration(days: 300)),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.light(
                            primary: AppColors.rose)),
                    child: child!,
                  ),
                );
                if (picked != null) onDatePicked(picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.textLight.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: AppColors.textLight, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    dueDate != null
                        ? DateFormat('d MMMM yyyy').format(dueDate!)
                        : 'Select your due date',
                    style: TextStyle(
                        fontWeight: dueDate != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 14,
                        color: dueDate != null
                            ? AppColors.textDark
                            : AppColors.textLight),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textLight, size: 18),
                ]),
              ),
            ),
          ]),
          if (dueDate != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.blush,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                const Text('🌸', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                Text('Week $pregnancyWeek',
                    style: const TextStyle(
                        color: AppColors.roseDeep,
                        fontWeight: FontWeight.w800,
                        fontSize: 32)),
                const SizedBox(height: 4),
                const Text(
                  'of your pregnancy',
                  style: TextStyle(
                      color: AppColors.textMid, fontSize: 14),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (pregnancyWeek / 40).clamp(0.0, 1.0),
                  backgroundColor:
                      AppColors.rose.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.rose),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                Text('$pregnancyWeek / 40 weeks',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textLight)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Step 3: Health Details ───────────────────────────────────────────
class _StepHealthDetails extends StatelessWidget {
  final TextEditingController heightCtrl;
  final TextEditingController weightCtrl;
  final Set<String> conditions;
  final List<String> conditionOptions;
  final TextEditingController allergiesCtrl;
  final TextEditingController otherConditionCtrl;
  final ValueChanged<String> onConditionToggled;

  const _StepHealthDetails({
    required this.heightCtrl,
    required this.weightCtrl,
    required this.conditions,
    required this.conditionOptions,
    required this.allergiesCtrl,
    required this.otherConditionCtrl,
    required this.onConditionToggled,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card('📏 Height & Weight', [
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: heightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Height', suffixText: 'cm'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: weightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Weight', suffixText: 'kg'),
                ),
              ),
            ]),
          ]),
          const SizedBox(height: 12),
          _card('🏥 Medical Conditions', [
            const Text('Select any that apply',
                style: TextStyle(color: AppColors.textLight, fontSize: 12)),
            const SizedBox(height: 10),
            // "None" chip — visually separated from the rest
            FilterChip(
              label: Text('None',
                  style: TextStyle(
                      fontSize: 12,
                      color: conditions.contains('None')
                          ? AppColors.teal
                          : AppColors.textMid,
                      fontWeight: conditions.contains('None')
                          ? FontWeight.w600
                          : FontWeight.normal)),
              selected: conditions.contains('None'),
              onSelected: (_) => onConditionToggled('None'),
              selectedColor: AppColors.tealLight,
              checkmarkColor: AppColors.teal,
              backgroundColor: AppColors.white,
              side: BorderSide(
                  color: conditions.contains('None')
                      ? AppColors.teal
                      : AppColors.textLight.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: conditionOptions
                  .where((c) => c != 'None')
                  .map((c) {
                final sel = conditions.contains(c);
                final noneSelected = conditions.contains('None');
                return FilterChip(
                  label: Text(c,
                      style: TextStyle(
                          fontSize: 12,
                          color: noneSelected
                              ? AppColors.textLight
                              : sel
                                  ? AppColors.roseDeep
                                  : AppColors.textMid,
                          fontWeight:
                              sel ? FontWeight.w600 : FontWeight.normal)),
                  selected: sel,
                  onSelected: noneSelected ? null : (_) => onConditionToggled(c),
                  selectedColor: AppColors.blush,
                  checkmarkColor: AppColors.roseDeep,
                  backgroundColor: AppColors.white,
                  disabledColor: AppColors.white,
                  side: BorderSide(
                      color: sel
                          ? AppColors.rose
                          : AppColors.textLight.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
            if (conditions.contains('Other')) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: otherConditionCtrl,
                decoration: InputDecoration(
                  hintText: 'Please describe your condition',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: AppColors.textLight.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: AppColors.textLight.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.rose, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          _card('⚠️ Allergies', [
            TextFormField(
              controller: allergiesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText:
                    'e.g. Penicillin, Nuts, Latex (leave blank if none)',
                border: InputBorder.none,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Step 4: Interests & Support ──────────────────────────────────────
class _StepInterests extends StatelessWidget {
  final Set<String> interests;
  final List<String> interestOptions;
  final Set<String> consultationNeeds;
  final List<String> consultationOptions;
  final ValueChanged<String> onInterestToggled;
  final ValueChanged<String> onConsultationToggled;

  const _StepInterests({
    required this.interests,
    required this.interestOptions,
    required this.consultationNeeds,
    required this.consultationOptions,
    required this.onInterestToggled,
    required this.onConsultationToggled,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card('💡 Areas of Interest', [
            const Text('What topics matter most to you?',
                style: TextStyle(
                    color: AppColors.textLight, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: interestOptions.map((i) {
                final sel = interests.contains(i);
                return FilterChip(
                  label: Text(i,
                      style: TextStyle(
                          fontSize: 12,
                          color: sel ? AppColors.teal : AppColors.textMid,
                          fontWeight: sel
                              ? FontWeight.w600
                              : FontWeight.normal)),
                  selected: sel,
                  onSelected: (_) => onInterestToggled(i),
                  selectedColor: AppColors.tealLight,
                  checkmarkColor: AppColors.teal,
                  backgroundColor: AppColors.white,
                  side: BorderSide(
                      color: sel
                          ? AppColors.teal
                          : AppColors.textLight.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
          ]),
          const SizedBox(height: 12),
          _card('👩‍⚕️ Consultation Needs', [
            const Text('Who would you like to speak with?',
                style: TextStyle(
                    color: AppColors.textLight, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: consultationOptions.map((c) {
                final sel = consultationNeeds.contains(c);
                return FilterChip(
                  label: Text(c,
                      style: TextStyle(
                          fontSize: 12,
                          color: sel
                              ? AppColors.roseDeep
                              : AppColors.textMid,
                          fontWeight: sel
                              ? FontWeight.w600
                              : FontWeight.normal)),
                  selected: sel,
                  onSelected: (_) => onConsultationToggled(c),
                  selectedColor: AppColors.blush,
                  checkmarkColor: AppColors.roseDeep,
                  backgroundColor: AppColors.white,
                  side: BorderSide(
                      color: sel
                          ? AppColors.rose
                          : AppColors.textLight.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.blush,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(children: [
              Text('🎉', style: TextStyle(fontSize: 24)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("You're almost done!",
                        style: TextStyle(
                            color: AppColors.roseDeep,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    SizedBox(height: 2),
                    Text(
                        'Your profile helps us personalise TinyBloom just for you.',
                        style: TextStyle(
                            color: AppColors.textMid, fontSize: 12)),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Shared card widget ───────────────────────────────────────────────
Widget _card(String title, List<Widget> children) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.textDark)),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}
