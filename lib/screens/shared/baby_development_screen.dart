import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/pregnancy_week_data.dart';
import '../../utils/singapore_time.dart';
import '../../widgets/common_widgets.dart';
import 'article_open_helper.dart';

class BabyDevelopmentScreen extends StatefulWidget {
  final String? patientUserId;
  final String? patientName;

  const BabyDevelopmentScreen(
      {super.key, this.patientUserId, this.patientName});

  @override
  State<BabyDevelopmentScreen> createState() => _BabyDevelopmentScreenState();
}

class _BabyDevelopmentScreenState extends State<BabyDevelopmentScreen> {
  int _currentWeek = 24;
  bool _loading = true;
  DateTime? _dueDate;
  List<Map<String, dynamic>> _articles = [];

  static const _trimesterInfo = {
    1: {'label': 'First Trimester', 'weeks': 'Weeks 1–12', 'color': 0xFFE8B4BC},
    2: {
      'label': 'Second Trimester',
      'weeks': 'Weeks 13–27',
      'color': 0xFFB4D4CC
    },
    3: {
      'label': 'Third Trimester',
      'weeks': 'Weeks 28–40',
      'color': 0xFFD4C4B4
    },
  };

  int get _trimester {
    if (_currentWeek <= 12) return 1;
    if (_currentWeek <= 27) return 2;
    return 3;
  }

  String get _possessive => widget.patientName != null
      ? "${widget.patientName!.split(' ').first}'s"
      : 'Your';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadWeek();
    await _loadArticles();
  }

  Future<void> _loadWeek() async {
    try {
      final data = widget.patientUserId != null
          ? await SupabaseService.getPregnancyProfileByUserId(
              widget.patientUserId!)
          : await SupabaseService.getPregnancyProfile();
      if (data != null && mounted) {
        if (data['due_date'] != null) {
          final due = sgtDateFrom(data['due_date'])!;
          final now = sgtNow();
          final daysUntilDue = due.difference(now).inDays;
          final week = ((280 - daysUntilDue) / 7).floor().clamp(1, 40);
          setState(() {
            _currentWeek = week;
            _dueDate = due;
            _loading = false;
          });
          return;
        }
        if (data['weeks_pregnant'] != null) {
          setState(() {
            _currentWeek = (data['weeks_pregnant'] as int).clamp(1, 40);
            _loading = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadArticles() async {
    try {
      final all = await SupabaseService.getArticles();

      final byTrimester =
          all.where((a) => a['trimester'] == _trimester).toList();
      if (byTrimester.isNotEmpty) {
        if (mounted) setState(() => _articles = byTrimester.take(3).toList());
        return;
      }

      final relevant = all.where((a) {
        final cat = (a['category'] as String? ?? '').toLowerCase();
        return cat.contains('pregnant') ||
            cat.contains('baby') ||
            cat.contains('develop');
      }).toList();

      if (mounted) {
        setState(() => _articles =
            (relevant.isNotEmpty ? relevant : all).take(3).toList());
      }
    } catch (_) {}
  }

  List<String> _milestones(String highlight) {
    return highlight
        .split('. ')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => s.endsWith('.') ? s.substring(0, s.length - 1) : s)
        .toList();
  }

  Widget _statCard(String label, String value, Color color) {
    return TBCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: color),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final week = pregnancyWeekData[_currentWeek] ?? pregnancyWeekData[24]!;
    final trimester = _trimesterInfo[_trimester]!;
    final trimesterColor = Color(trimester['color'] as int);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.patientName != null
              ? "$_possessive Baby Development"
              : 'Baby Development',
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const TBLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: trimesterColor.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${trimester['label']}  •  ${trimester['weeks']}',
                      style: TextStyle(
                          color: trimesterColor.withValues(alpha: 1.0),
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ),
                  if (_dueDate != null) ...[
                    const SizedBox(height: 6),
                    Text(
                        'Based on due date: ${DateFormat('d MMM yyyy').format(_dueDate!)}',
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 12)),
                  ],
                  const SizedBox(height: 20),
                  TBCard(
                    color: AppColors.blush,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(week['emoji'] as String,
                                style: const TextStyle(fontSize: 64)),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Week $_currentWeek',
                                      style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.roseDeep)),
                                  Text(
                                      '$_possessive baby is approximately the size of\n${week['size']}',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textMid,
                                          height: 1.4)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: _currentWeek / 40,
                          backgroundColor:
                              AppColors.rose.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.rose),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 6),
                        Text('$_currentWeek / 40 weeks',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textLight)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: _statCard('Approx. Length',
                              week['length'] as String, AppColors.roseDeep)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _statCard('Approx. Weight',
                              week['weight'] as String, AppColors.roseDeep)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _statCard('Weeks Remaining',
                              '${40 - _currentWeek} weeks', AppColors.teal)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _statCard('Trimester', 'Trimester $_trimester',
                              AppColors.teal)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TBCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.timeline_outlined,
                              color: AppColors.teal, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Development Progress',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.teal)),
                              const SizedBox(height: 6),
                              ..._milestones(week['highlight'] as String)
                                  .map((m) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Text('•  $m',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: AppColors.textMid,
                                                height: 1.4)),
                                      )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_articles.isNotEmpty) ...[
                    TBCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.menu_book_outlined,
                                    color: AppColors.gold, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text('Recommended Articles',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._articles.map((a) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GestureDetector(
                                  onTap: () => openArticle(context, a),
                                  child: Row(
                                    children: [
                                      const Text('•  ',
                                          style: TextStyle(
                                              color: AppColors.textMid)),
                                      Expanded(
                                        child: Text(a['title'] ?? '',
                                            style: const TextStyle(
                                                color: AppColors.textMid,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      const Icon(Icons.chevron_right,
                                          color: AppColors.textLight, size: 16),
                                    ],
                                  ),
                                ),
                              )),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => context.go('/education'),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: AppColors.blush,
                                  borderRadius: BorderRadius.circular(20)),
                              child: const Text('Read More',
                                  style: TextStyle(
                                      color: AppColors.roseDeep,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }
}
