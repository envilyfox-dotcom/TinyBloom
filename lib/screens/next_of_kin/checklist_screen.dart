import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── Support Checklist (Next of Kin) ───────────────────────────────────
// A full-pregnancy plan for a next-of-kin: every phase (including
// postpartum) is browsable, grouped into categories, with the mum's
// current phase auto-expanded based on her real week. Checked state is
// local only for now (not persisted) — this is the base UI to design
// against; a checklist_items/checklist_progress table (or similar) can
// replace the static data + in-memory Set once that's built.
typedef _Category = ({String title, List<String> items});
typedef _Phase = ({String label, String emoji, List<_Category> categories});

const _checklistPhases = <_Phase>[
  (
    label: 'First Trimester',
    emoji: '🌱',
    categories: [
      (
        title: 'Medical & Health',
        items: [
          'Attend the first prenatal appointment together',
          'Learn about common first-trimester symptoms (nausea, fatigue, mood changes)',
          'Help manage morning sickness (bland snacks, ginger tea, rest)',
          'Discuss choice of OB/GP or midwife',
          'Understand the prenatal vitamins/supplements she needs',
        ],
      ),
      (
        title: 'Practical Support',
        items: [
          'Take over extra household chores as fatigue sets in',
          'Reduce exposure to strong smells/triggers at home',
          'Start a shared pregnancy calendar',
        ],
      ),
      (
        title: 'Emotional & Relational',
        items: [
          'Check in regularly on how she\'s feeling, physically and emotionally',
          'Discuss how and when to share the pregnancy news',
          'Be patient and understanding around mood swings',
        ],
      ),
      (
        title: 'Financial & Planning',
        items: [
          'Talk about parental leave options and timing',
          'Research healthcare/insurance coverage for pregnancy and birth',
          'Start a rough budget for baby-related costs',
        ],
      ),
    ],
  ),
  (
    label: 'Second Trimester',
    emoji: '🌼',
    categories: [
      (
        title: 'Medical & Health',
        items: [
          'Attend prenatal appointments and scans together (e.g. anatomy scan)',
          'Learn what to expect at the anatomy scan',
          'Go over any screening test results together',
          'Help her stay active with safe, gentle exercise',
        ],
      ),
      (
        title: 'Practical Support',
        items: [
          'Start setting up and shopping for the nursery',
          'Research and compare paediatricians',
          'Attend a birth preparation / antenatal class together',
          'Start researching baby gear (car seat, stroller, crib)',
        ],
      ),
      (
        title: 'Emotional & Relational',
        items: [
          'Track baby movements/kicks together',
          'Talk about parenting values and expectations',
          'Plan quality time together before the baby arrives',
        ],
      ),
      (
        title: 'Financial & Planning',
        items: [
          'Finalise parental leave arrangements with employers',
          'Set up or review a baby savings fund',
          'Look into childcare options and costs for after birth',
        ],
      ),
    ],
  ),
  (
    label: 'Third Trimester',
    emoji: '🌸',
    categories: [
      (
        title: 'Medical & Health',
        items: [
          'Attend more frequent prenatal appointments together',
          'Learn the signs of labour and when to head to the hospital',
          'Go over the birth plan together',
          'Learn basic newborn care (feeding, diapering, soothing, safe sleep)',
        ],
      ),
      (
        title: 'Practical Support',
        items: [
          'Pack the hospital bag together',
          'Install and double-check the car seat',
          'Finalise the nursery and baby essentials',
          'Prepare and freeze meals for after the birth',
        ],
      ),
      (
        title: 'Emotional & Relational',
        items: [
          'Reassure her as anxiety about labour may increase',
          'Plan who will be present during labour/delivery',
          'Discuss visitor policies and boundaries for after birth',
        ],
      ),
      (
        title: 'Financial & Planning',
        items: [
          'Confirm parental leave start date and paperwork',
          'Review health insurance/hospital billing details',
          'Finalise birth announcement plans',
        ],
      ),
    ],
  ),
  (
    label: 'Postpartum (0–3 Months)',
    emoji: '🍼',
    categories: [
      (
        title: 'Medical & Health',
        items: [
          'Attend the postpartum check-up together',
          'Watch for signs of postpartum depression/anxiety in her',
          'Help track baby\'s feeding and diaper schedule',
          'Learn safe sleep practices for the baby',
        ],
      ),
      (
        title: 'Practical Support',
        items: [
          'Take on nighttime duties to help her rest',
          'Manage visitors and household tasks',
          'Help with meal prep and errands',
        ],
      ),
      (
        title: 'Emotional & Relational',
        items: [
          'Check in on her emotional wellbeing regularly',
          'Share nighttime/feeding duties to prevent burnout',
          'Celebrate small wins together as new parents',
        ],
      ),
      (
        title: 'Financial & Planning',
        items: [
          'Register the birth and apply for relevant benefits',
          'Update insurance to include the baby',
          'Review and adjust the household budget for baby expenses',
        ],
      ),
    ],
  ),
];

class NextOfKinChecklistScreen extends StatefulWidget {
  const NextOfKinChecklistScreen({super.key});
  @override
  State<NextOfKinChecklistScreen> createState() =>
      _NextOfKinChecklistScreenState();
}

class _NextOfKinChecklistScreenState extends State<NextOfKinChecklistScreen> {
  Map<String, dynamic>? _linkedMum;
  bool _loading = true;
  final Set<String> _checked = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mum = await SupabaseService.getLinkedMum();
    if (mounted) setState(() { _linkedMum = mum; _loading = false; });
  }

  // 0-2 for trimesters 1-3; postpartum (index 3) has no real-data signal
  // to auto-detect yet (no "has given birth" flag), so it's just browsable.
  int get _currentPhaseIndex {
    final week = (_linkedMum?['current_week'] as int?) ?? 0;
    if (week <= 12) return 0;
    if (week <= 27) return 1;
    return 2;
  }

  int _phaseTotal(_Phase phase) =>
      phase.categories.fold(0, (sum, c) => sum + c.items.length);

  int _phaseDone(_Phase phase) => phase.categories
      .fold(0, (sum, c) => sum + c.items.where(_checked.contains).length);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support Checklist')),
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
    final totalItems = _checklistPhases.fold(0, (sum, p) => sum + _phaseTotal(p));
    final totalDone = _checklistPhases.fold(0, (sum, p) => sum + _phaseDone(p));
    final overallProgress = totalItems == 0 ? 0.0 : totalDone / totalItems;

    return SingleChildScrollView(
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
              style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: overallProgress,
            backgroundColor: AppColors.rose.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.rose),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < _checklistPhases.length; i++)
            _phaseSection(_checklistPhases[i], initiallyExpanded: i == _currentPhaseIndex),
        ],
      ),
    );
  }

  Widget _phaseSection(_Phase phase, {required bool initiallyExpanded}) {
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
                for (final item in category.items) _checklistTile(item),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _checklistTile(String item) {
    final done = _checked.contains(item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() {
          if (done) {
            _checked.remove(item);
          } else {
            _checked.add(item);
          }
        }),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? AppColors.sage : AppColors.textLight,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(item,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: done ? AppColors.textLight : AppColors.textDark,
                      decoration:
                          done ? TextDecoration.lineThrough : TextDecoration.none)),
            ),
          ],
        ),
      ),
    );
  }
}
