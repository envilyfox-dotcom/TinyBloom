import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── Milestone Journey ─────────────────────────────────────────────
// Curated "big moments" timeline (as opposed to BabyDevelopmentScreen's
// week-by-week data), grouped by trimester.
const _milestoneJourney = [
  {
    'week': 4,
    'title': 'Week 4',
    'trimester': 1,
    'items': ['Fertilized egg successfully implanted', 'Pregnancy confirmed']
  },
  {
    'week': 6,
    'title': 'Week 6 — Heartbeat Detected',
    'trimester': 1,
    'items': ['Baby\'s heartbeat detected', 'First ultrasound completed']
  },
  {
    'week': 8,
    'title': 'Week 8 — Early Development',
    'trimester': 1,
    'items': [
      'Facial features starting to form',
      'Tiny arm and leg movements begin'
    ]
  },
  {
    'week': 10,
    'title': 'Week 10 — Organ Development',
    'trimester': 1,
    'items': ['Major organs developing', 'Baby begins small body movements']
  },
  {
    'week': 12,
    'title': 'Week 12 — End of 1st Trimester',
    'trimester': 1,
    'items': [
      'Nuchal scan completed',
      'Lower miscarriage risk',
      'Baby fully formed'
    ]
  },
  {
    'week': 16,
    'title': 'Week 16 — Growth Milestone',
    'trimester': 2,
    'items': ['Baby can hear sounds', 'Facial expressions developing']
  },
  {
    'week': 20,
    'title': 'Week 20 — Anatomy Scan',
    'trimester': 2,
    'items': [
      'Full anatomy scan completed',
      'Baby movements stronger',
      'Gender may be visible'
    ]
  },
  {
    'week': 24,
    'title': 'Week 24 — Viability Milestone',
    'trimester': 2,
    'items': [
      'Baby may survive outside womb with medical support',
      'Heartbeat developing well',
      'Baby responding to sounds'
    ]
  },
  {
    'week': 28,
    'title': 'Week 28 — Brain & Lung Development',
    'trimester': 2,
    'items': [
      'Brain developing rapidly',
      'Eyes can open and close',
      'Glucose test scheduled'
    ]
  },
  {
    'week': 32,
    'title': 'Week 32 — Rapid Growth',
    'trimester': 3,
    'items': ['Baby gaining weight quickly', 'Stronger kicks and movements']
  },
  {
    'week': 36,
    'title': 'Week 36 — Full Term Preparation',
    'trimester': 3,
    'items': [
      'Baby moving into birth position',
      'Hospital preparation checklist'
    ]
  },
  {
    'week': 38,
    'title': 'Week 38 — Final Development',
    'trimester': 3,
    'items': ['Baby lungs nearly mature', 'Frequent contractions may occur']
  },
  {
    'week': 40,
    'title': 'Week 40 — Estimated Delivery Week',
    'trimester': 3,
    'items': [
      '🎉 Full Term Reached',
      'Baby ready for delivery',
      'Labour may begin anytime'
    ]
  },
];

class MilestoneJourneyScreen extends StatefulWidget {
  const MilestoneJourneyScreen({super.key});
  @override
  State<MilestoneJourneyScreen> createState() => _MilestoneJourneyScreenState();
}

class _MilestoneJourneyScreenState extends State<MilestoneJourneyScreen> {
  int _currentWeek = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final week = await SupabaseService.getCurrentPregnancyWeek();
    if (mounted) {
      setState(() {
        _currentWeek = week;
        _loading = false;
      });
    }
  }

  Color _trimesterColor(int t) {
    switch (t) {
      case 1:
        return AppColors.sage;
      case 2:
        return AppColors.teal;
      default:
        return AppColors.gold;
    }
  }

  String _trimesterLabel(int t) {
    switch (t) {
      case 1:
        return '1st Trimester';
      case 2:
        return '2nd Trimester';
      default:
        return '3rd Trimester';
    }
  }

  @override
  Widget build(BuildContext context) {
    // The most recently reached milestone week, so far.
    int? currentMilestoneWeek;
    for (final m in _milestoneJourney) {
      if ((m['week'] as int) <= _currentWeek)
        currentMilestoneWeek = m['week'] as int;
    }
    final progress =
        _currentWeek > 0 ? (_currentWeek / 40).clamp(0.0, 1.0) : 0.0;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Milestone Journey',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const TBLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.blush,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.rose.withValues(alpha: 0.18)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your pregnancy milestones',
                          style: TextStyle(
                            color: AppColors.roseDeep,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Track key baby development moments from early pregnancy to delivery week.',
                          style: TextStyle(
                            color: AppColors.textMid,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Progress',
                          style: TextStyle(
                              color: AppColors.roseDeep,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      Text('${(progress * 100).round()}%',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation(AppColors.rose),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.rose.withValues(alpha: 0.3))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildTimeline(currentMilestoneWeek),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildTimeline(int? currentMilestoneWeek) {
    final widgets = <Widget>[];
    int? lastTrimester;
    for (int i = 0; i < _milestoneJourney.length; i++) {
      final m = _milestoneJourney[i];
      final trimester = m['trimester'] as int;
      final week = m['week'] as int;
      final isCurrent = week == currentMilestoneWeek;
      final isLast = i == _milestoneJourney.length - 1;

      if (trimester != lastTrimester) {
        widgets.add(Padding(
          padding:
              EdgeInsets.only(top: lastTrimester == null ? 0 : 8, bottom: 12),
          child: Text(_trimesterLabel(trimester),
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textDark)),
        ));
        lastTrimester = trimester;
      }

      widgets.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _trimesterColor(trimester)),
                ),
                if (!isLast)
                  Expanded(
                      child: Container(
                          width: 2,
                          color: AppColors.textLight.withValues(alpha: 0.25))),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(m['title'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: AppColors.sage.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20)),
                            child: const Text('Current',
                                style: TextStyle(
                                    color: AppColors.sage,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...(m['items'] as List<String>).map((it) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('✓ $it',
                              style: const TextStyle(
                                  color: AppColors.textMid, fontSize: 13)),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ));
    }
    return widgets;
  }
}
