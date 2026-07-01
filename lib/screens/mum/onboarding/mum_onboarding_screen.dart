import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
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

  final _ageCtrl = TextEditingController();
  String _pregnancyStatus = '';

  DateTime? _dueDate;

  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final Set<String> _conditions = {};
  final _allergiesCtrl = TextEditingController();
  final _otherConditionCtrl = TextEditingController();

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

  bool _validateStep() {
    setState(() => _error = null);

    if (_step == 0) {
      final age = int.tryParse(_ageCtrl.text.trim());
      if (age == null || age < 12 || age > 60) {
        setState(() => _error = 'Please enter a valid age.');
        return false;
      }
      if (_pregnancyStatus.isEmpty) {
        setState(() => _error = 'Please select your pregnancy status.');
        return false;
      }
    }

    if (_step == 1 && _dueDate == null) {
      setState(() => _error = 'Please select your estimated due date.');
      return false;
    }

    if (_step == 2) {
      final height = double.tryParse(_heightCtrl.text.trim());
      final weight = double.tryParse(_weightCtrl.text.trim());

      if (height == null || height < 100 || height > 220) {
        setState(() => _error = 'Please enter a valid height in cm.');
        return false;
      }

      if (weight == null || weight < 30 || weight > 200) {
        setState(() => _error = 'Please enter a valid weight in kg.');
        return false;
      }

      if (_conditions.isEmpty) {
        setState(() => _error =
            'Please select at least one medical condition, or choose None.');
        return false;
      }

      if (_conditions.contains('Other') &&
          _otherConditionCtrl.text.trim().isEmpty) {
        setState(
            () => _error = 'Please describe your other medical condition.');
        return false;
      }
    }

    return true;
  }

  void _next() {
    if (!_validateStep()) return;

    if (_step < 3) {
      _page.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _error = null);
      _page.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _step--);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });

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
        'areas_of_interest': _interests.isEmpty ? null : _interests.join(', '),
        'consultation_needs':
            _consultationNeeds.isEmpty ? null : _consultationNeeds.join(', '),
      });

      if (mounted) {
        await context.read<AuthProvider>().refreshProfile();
        if (mounted) context.go('/home');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Something went wrong. Please check your connection and try again.');
      }
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
            _buildHeader(context),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepAboutYou(
                    ageCtrl: _ageCtrl,
                    pregnancyStatus: _pregnancyStatus,
                    statuses: _statuses,
                    onStatusChanged: (v) =>
                        setState(() => _pregnancyStatus = v),
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

  Widget _buildHeader(BuildContext context) {
    final titles = [
      'About You',
      'Your Pregnancy',
      'Health Details',
      'Interests & Support',
    ];
    final subtitles = [
      'Tell us a little about yourself',
      'Help us personalise your journey',
      'Share key health details safely',
      'Choose what support matters most',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.blush,
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_step > 0)
                IconButton(
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back_ios_new,
                      size: 18, color: AppColors.roseDeep),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              if (_step > 0) const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('🌸', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'TinyBloom Setup',
                  style: TextStyle(
                    color: AppColors.roseDeep,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_step + 1} of 4',
                  style: const TextStyle(
                    color: AppColors.textMid,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 6,
                  margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i <= _step
                        ? AppColors.rose
                        : AppColors.rose.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Text(
            titles[_step],
            style: const TextStyle(
              color: AppColors.roseDeep,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitles[_step],
            style: const TextStyle(color: AppColors.textMid, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(14),
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
                    onPressed: _saving ? null : _back,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.rose),
                      foregroundColor: AppColors.roseDeep,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Back'),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _saving ? null : _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rose,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _step == 3 ? 'Complete Setup' : 'Next',
                          style: const TextStyle(fontWeight: FontWeight.w800),
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
    return _StepScaffold(
      children: [
        _InfoCard(
          icon: '🎂',
          title: 'Your Age',
          subtitle: 'This helps us personalise pregnancy guidance.',
          children: [
            TextFormField(
              controller: ageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age',
                suffixText: 'years',
                prefixIcon:
                    Icon(Icons.cake_outlined, color: AppColors.textLight),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _InfoCard(
          icon: '🤰',
          title: 'Pregnancy Status',
          subtitle: 'Choose the option that best describes you.',
          children: [
            ...statuses.map((s) {
              final sel = pregnancyStatus == s;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ChoiceTile(
                  label: s,
                  selected: sel,
                  onTap: () => onStatusChanged(s),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }
}

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
    return _StepScaffold(
      children: [
        _InfoCard(
          icon: '📅',
          title: 'Estimated Due Date',
          subtitle: 'We use this to calculate your pregnancy week.',
          children: [
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      dueDate ?? DateTime.now().add(const Duration(days: 140)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 300)),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppColors.rose,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) onDatePicked(picked);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.textLight.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: AppColors.roseDeep, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        dueDate != null
                            ? DateFormat('d MMMM yyyy').format(dueDate!)
                            : 'Select your due date',
                        style: TextStyle(
                          fontWeight: dueDate != null
                              ? FontWeight.w700
                              : FontWeight.normal,
                          fontSize: 14,
                          color: dueDate != null
                              ? AppColors.textDark
                              : AppColors.textLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textLight, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (dueDate != null) ...[
          const SizedBox(height: 16),
          _WeekSummaryCard(pregnancyWeek: pregnancyWeek),
        ],
      ],
    );
  }
}

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
    return _StepScaffold(
      children: [
        _InfoCard(
          icon: '📏',
          title: 'Height & Weight',
          subtitle: 'These are optional for tracking but useful for care.',
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: heightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Height',
                      suffixText: 'cm',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: weightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Weight',
                      suffixText: 'kg',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        _InfoCard(
          icon: '🏥',
          title: 'Medical Conditions',
          subtitle: 'Select all that apply, or choose None.',
          children: [
            _ConditionChips(
              conditions: conditions,
              conditionOptions: conditionOptions,
              onConditionToggled: onConditionToggled,
            ),
            if (conditions.contains('Other')) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: otherConditionCtrl,
                decoration: const InputDecoration(
                  hintText: 'Please describe your condition',
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _InfoCard(
          icon: '⚠️',
          title: 'Allergies',
          subtitle: 'Leave this blank if you do not have any.',
          children: [
            TextFormField(
              controller: allergiesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. Penicillin, nuts, latex',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

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
    return _StepScaffold(
      children: [
        _InfoCard(
          icon: '💡',
          title: 'Areas of Interest',
          subtitle: 'Pick topics you want TinyBloom to highlight.',
          children: [
            _ChipWrap(
              options: interestOptions,
              selected: interests,
              selectedColor: AppColors.tealLight,
              selectedTextColor: AppColors.teal,
              selectedBorderColor: AppColors.teal,
              onToggle: onInterestToggled,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _InfoCard(
          icon: '👩‍⚕️',
          title: 'Consultation Needs',
          subtitle: 'Choose the types of support you may need.',
          children: [
            _ChipWrap(
              options: consultationOptions,
              selected: consultationNeeds,
              selectedColor: AppColors.blush,
              selectedTextColor: AppColors.roseDeep,
              selectedBorderColor: AppColors.rose,
              onToggle: onConsultationToggled,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.blush,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.rose.withValues(alpha: 0.25)),
          ),
          child: const Row(
            children: [
              Text('🎉', style: TextStyle(fontSize: 28)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You're almost done!",
                      style: TextStyle(
                        color: AppColors.roseDeep,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your answers help TinyBloom personalise your pregnancy journey.',
                      style: TextStyle(
                        color: AppColors.textMid,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepScaffold extends StatelessWidget {
  final List<Widget> children;

  const _StepScaffold({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _InfoCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.textLight.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.blush : AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.rose
                  : AppColors.textLight.withValues(alpha: 0.25),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? AppColors.roseDeep : AppColors.textDark,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? AppColors.roseDeep : AppColors.textLight,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekSummaryCard extends StatelessWidget {
  final int pregnancyWeek;

  const _WeekSummaryCard({required this.pregnancyWeek});

  @override
  Widget build(BuildContext context) {
    final week = pregnancyWeek.clamp(1, 42);
    final progress = (week / 40).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.blush,
            AppColors.rose.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Text('🌸', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text(
            'Week $week',
            style: const TextStyle(
              color: AppColors.roseDeep,
              fontWeight: FontWeight.w900,
              fontSize: 34,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'of your pregnancy',
            style: TextStyle(color: AppColors.textMid, fontSize: 14),
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.rose.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.rose),
            minHeight: 7,
            borderRadius: BorderRadius.circular(7),
          ),
          const SizedBox(height: 7),
          Text(
            '$week / 40 weeks',
            style: const TextStyle(fontSize: 11, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}

class _ConditionChips extends StatelessWidget {
  final Set<String> conditions;
  final List<String> conditionOptions;
  final ValueChanged<String> onConditionToggled;

  const _ConditionChips({
    required this.conditions,
    required this.conditionOptions,
    required this.onConditionToggled,
  });

  @override
  Widget build(BuildContext context) {
    final noneSelected = conditions.contains('None');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PrettyChip(
          label: 'None',
          selected: noneSelected,
          selectedColor: AppColors.tealLight,
          selectedTextColor: AppColors.teal,
          selectedBorderColor: AppColors.teal,
          onTap: () => onConditionToggled('None'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: conditionOptions.where((c) => c != 'None').map((c) {
            final selected = conditions.contains(c);
            return _PrettyChip(
              label: c,
              selected: selected,
              disabled: noneSelected,
              selectedColor: AppColors.blush,
              selectedTextColor: AppColors.roseDeep,
              selectedBorderColor: AppColors.rose,
              onTap: noneSelected ? null : () => onConditionToggled(c),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ChipWrap extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final Color selectedColor;
  final Color selectedTextColor;
  final Color selectedBorderColor;
  final ValueChanged<String> onToggle;

  const _ChipWrap({
    required this.options,
    required this.selected,
    required this.selectedColor,
    required this.selectedTextColor,
    required this.selectedBorderColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        return _PrettyChip(
          label: option,
          selected: selected.contains(option),
          selectedColor: selectedColor,
          selectedTextColor: selectedTextColor,
          selectedBorderColor: selectedBorderColor,
          onTap: () => onToggle(option),
        );
      }).toList(),
    );
  }
}

class _PrettyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final Color selectedColor;
  final Color selectedTextColor;
  final Color selectedBorderColor;
  final VoidCallback? onTap;

  const _PrettyChip({
    required this.label,
    required this.selected,
    this.disabled = false,
    required this.selectedColor,
    required this.selectedTextColor,
    required this.selectedBorderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = disabled
        ? AppColors.textLight
        : selected
            ? selectedTextColor
            : AppColors.textMid;

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.white
              : selected
                  ? selectedColor
                  : AppColors.background,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: disabled
                ? AppColors.textLight.withValues(alpha: 0.18)
                : selected
                    ? selectedBorderColor
                    : AppColors.textLight.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 14, color: selectedTextColor),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
