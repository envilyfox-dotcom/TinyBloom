import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/checklist_data.dart';
import '../../utils/next_of_kin_alert_read_state.dart';
import '../../utils/next_of_kin_alerts_data.dart';
import '../../utils/pregnancy_log_danger_scan.dart';
import '../../utils/pregnancy_week_data.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/quick_chat_volunteer.dart';

class NextOfKinDashboardScreen extends StatefulWidget {
  const NextOfKinDashboardScreen({super.key});

  @override
  State<NextOfKinDashboardScreen> createState() =>
      _NextOfKinDashboardScreenState();
}

class _NextOfKinDashboardScreenState extends State<NextOfKinDashboardScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _linkedMum;
  List<Map<String, dynamic>> _consultations = [];
  List<Map<String, dynamic>> _pregnancyLogs = [];
  List<Map<String, dynamic>> _dailyReminderSends = [];
  List<Map<String, dynamic>> _myQuestions = [];
  DateTime? _milestoneTimestamp;
  Set<String> _readAlertKeys = {};
  Map<String, String> _providerNames = {};
  List<ChecklistPhase> _checklistPhases = [];
  int _checklistPhaseIndex = 0;
  bool _loading = true;
  DateTime? _lastNavTime;

  bool _canNav() {
    final now = DateTime.now();
    if (_lastNavTime != null &&
        now.difference(_lastNavTime!) < const Duration(milliseconds: 600)) {
      return false;
    }
    _lastNavTime = now;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic>? profile;
    try {
      profile = await SupabaseService.getProfile();
    } catch (_) {}
    if (profile == null) {
      final meta = SupabaseService.currentUser?.userMetadata;
      if (meta != null) {
        profile = {'full_name': meta['full_name'], 'role': meta['role']};
      }
    }

    Map<String, dynamic>? linkedMum;
    try {
      linkedMum = await SupabaseService.getLinkedMum();
    } catch (_) {}

    List<Map<String, dynamic>> consultations = [];
    List<Map<String, dynamic>> pregnancyLogs = [];
    List<Map<String, dynamic>> dailyReminderSends = [];
    final providerNames = <String, String>{};
    List<ChecklistPhase> checklistPhases = [];
    if (linkedMum != null) {
      consultations = await SupabaseService.getConsultationsForPatient(
          linkedMum['id'] as String);

      try {
        pregnancyLogs =
            await SupabaseService.getLogsForPatient(linkedMum['id'] as String);
      } catch (_) {}

      try {
        dailyReminderSends = await SupabaseService.getMyDailyReminders();
      } catch (_) {}

      final activeSpecialistIds = consultations
          .where((c) {
            final status = (c['status'] as String? ?? '').toLowerCase();
            return status == 'pending' || status == 'confirmed';
          })
          .take(2)
          .map((c) => c['specialist_id'] as String?)
          .whereType<String>()
          .toSet();
      for (final id in activeSpecialistIds) {
        try {
          final p = await SupabaseService.getProviderProfile(id);
          final name = (p?['profiles'] as Map<String, dynamic>?)?['full_name']
              as String?;
          if (name != null) providerNames[id] = name;
        } catch (_) {}
      }

      try {
        final rows = await SupabaseService.getOrCreateChecklistItems();
        checklistPhases = phasesFromRows(rows);
      } catch (_) {}
    }
    final checklistPhaseIndex = await getCurrentChecklistPhaseIndex();
    final readAlertKeys = await getReadAlertKeys();

    List<Map<String, dynamic>> myQuestions = [];
    try {
      final rawQuestions = await SupabaseService.getMyVolunteerQuestions();
      myQuestions = await enrichQuickChatQuestions(
        List<Map<String, dynamic>>.from(rawQuestions),
      );
    } catch (_) {}

    final week = (linkedMum?['current_week'] as int?) ?? 0;
    // Prefer the real, server-derived week-start date over the local
    // "first seen on this device" fallback — see alerts_screen.dart's
    // _load() for the full rationale.
    final weekStartDate = DateTime.tryParse(
        (linkedMum?['current_week_start_date'] ?? '').toString());
    final milestoneTimestamp = week <= 0
        ? null
        : weekStartDate ?? await getOrRecordMilestoneTimestamp(week);

    if (mounted) {
      setState(() {
        _profile = profile;
        _linkedMum = linkedMum;
        _consultations = consultations;
        _pregnancyLogs = pregnancyLogs;
        _readAlertKeys = readAlertKeys;
        _dailyReminderSends = dailyReminderSends;
        _myQuestions = myQuestions;
        _milestoneTimestamp = milestoneTimestamp;
        _providerNames = providerNames;
        _checklistPhases = checklistPhases;
        _checklistPhaseIndex = checklistPhaseIndex.clamp(
            0, checklistPhases.isEmpty ? 0 : checklistPhases.length - 1);
        _loading = false;
      });
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName =>
      (_profile?['full_name'] as String? ?? 'there').split(' ').first;

  String? get _photoUrl => _profile?['profile_picture_url'] as String?;

  // Notification-bell badge count. Uses the same alert-source builder and
  // persisted read-state store as the full Notifications Centre
  // (alerts_screen.dart), so the two screens always agree on what's
  // unread — an alert only stops counting here once it's actually been
  // seen there.
  int get _notificationBellCount {
    if (_linkedMum == null) return 0;
    final sources = buildNextOfKinAlertSources(
      linkedMumWeek: _linkedMumWeek,
      consultations: _consultations,
      pregnancyLogs: _pregnancyLogs,
      dailyReminderSends: _dailyReminderSends,
      volunteerQuestions: _myQuestions,
      milestoneTimestamp: _milestoneTimestamp,
    );
    return sources.where((s) => !_readAlertKeys.contains(s.key)).length;
  }

  int get _linkedMumWeek => (_linkedMum?['current_week'] as int?) ?? 0;
  String get _linkedMumName => (_linkedMum?['full_name'] as String?) ?? 'them';
  String get _linkedMumFirstName => _linkedMumName.split(' ').first;

  String get _trimesterLabel {
    final week = _linkedMumWeek;
    if (week <= 12) return '1st Trimester';
    if (week <= 27) return '2nd Trimester';
    return '3rd Trimester';
  }

  // Named milestones for a handful of well-known weeks, falling back to the
  // existing per-week development highlight for everything else — mirrors
  // the mum's own dashboard so the two never disagree on a given week.
  String _milestoneLabel(int week) {
    const named = {
      4: 'Pregnancy confirmed',
      8: 'Heartbeat detectable',
      12: 'End of first trimester',
      13: 'Second trimester begins',
      20: 'Halfway there!',
      23: 'Viability milestone reached',
      24: 'Viability milestone reached',
      28: 'Third trimester begins',
      37: 'Full term soon',
      40: 'Full term!',
    };
    return named[week] ??
        (pregnancyWeekData[week]?['highlight'] ?? 'Growing strong');
  }

  // Progress through the *current* trimester, not the whole pregnancy.
  double get _trimesterProgress {
    final week = _linkedMumWeek;
    if (week <= 12) return week / 12;
    if (week <= 27) return (week - 12) / 15;
    return (week - 27) / 13;
  }

  // "Week X of Y" within the current trimester, for the caption under the bar.
  (int, int) get _trimesterWeekOverview {
    final week = _linkedMumWeek;
    if (week <= 12) return (week, 12);
    if (week <= 27) return (week - 12, 15);
    return (week - 27, 13);
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: TBLoading());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.rose,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 150,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.blush,
              elevation: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 44, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$_greeting, $_firstName',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontSize: 20)),
                            const SizedBox(height: 4),
                            if (_linkedMum != null)
                              Text.rich(
                                TextSpan(
                                  style: const TextStyle(
                                      color: AppColors.textMid, fontSize: 13),
                                  children: [
                                    TextSpan(text: '$_linkedMumName is on '),
                                    TextSpan(
                                      text: 'Week $_linkedMumWeek',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    const TextSpan(text: ' of Pregnancy'),
                                  ],
                                ),
                              )
                            else
                              const Text('Not linked to a pregnant user yet',
                                  style: TextStyle(
                                      color: AppColors.textMid, fontSize: 13)),
                          ],
                        ),
                      ),
                      TBNotificationBell(
                        count: _notificationBellCount,
                        onTap: () async {
                          if (!_canNav()) return;
                          // Reload on return so the badge reflects the
                          // read-state changes the visit just made.
                          await context.push('/next-of-kin/alerts');
                          if (mounted) _load();
                        },
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              AppColors.rose.withValues(alpha: 0.15),
                          backgroundImage: _photoUrl != null
                              ? CachedNetworkImageProvider(_photoUrl!,
                                  maxWidth: 200)
                              : null,
                          child: _photoUrl != null
                              ? null
                              : Text(
                                  _firstName.isNotEmpty
                                      ? _firstName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                      color: AppColors.roseDeep,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _linkedMum == null
                    ? _buildNotLinkedPrompt(context)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTrimesterCard(context),
                          const SizedBox(height: 20),
                          _buildChecklistSection(context),
                          const SizedBox(height: 20),
                          _buildActiveAlerts(),
                          if (_myQuestions.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            QuickChatVolunteerSection(
                              questions: _myQuestions,
                              onReload: _load,
                            ),
                          ],
                          const SizedBox(height: 20),
                          _buildExploreSection(context),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotLinkedPrompt(BuildContext context) {
    return TBEmptyState(
      emoji: '🔗',
      title: 'Not linked yet',
      subtitle:
          "Link to a pregnant user's account to see her pregnancy journey here.",
      buttonLabel: 'Link to Pregnant User',
      onButton: () => context.push('/next-of-kin/link'),
    );
  }

  Widget _buildTrimesterCard(BuildContext context) {
    final week = _linkedMumWeek;
    if (week == 0) {
      return const TBCard(
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.textLight, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text('No pregnancy details available yet.',
                  style: TextStyle(color: AppColors.textMid, fontSize: 13)),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        if (!_canNav() || _linkedMum == null) return;
        context.push('/baby-development', extra: {
          'userId': _linkedMum!['id'],
          'name': _linkedMumFirstName,
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🌸  $_linkedMumFirstName\'s Pregnancy',
                    style: const TextStyle(
                        color: AppColors.roseDeep,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const Icon(Icons.chevron_right,
                    color: AppColors.roseDeep, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Current week',
                style: TextStyle(color: AppColors.textLight, fontSize: 12)),
            Text('Week $week',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 28, color: AppColors.rose)),
            const SizedBox(height: 2),
            Text('${_milestoneLabel(week)} ✦',
                style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
            const SizedBox(height: 16),
            const Text('Trimester progress',
                style: TextStyle(color: AppColors.textLight, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_trimesterLabel,
                    style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text('${(_trimesterProgress.clamp(0.0, 1.0) * 100).round()}%',
                    style: const TextStyle(
                        color: AppColors.rose,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: _trimesterProgress.clamp(0.0, 1.0),
              backgroundColor: AppColors.rose.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.rose),
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Text(
                'Week ${_trimesterWeekOverview.$1} of ${_trimesterWeekOverview.$2} this trimester',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }

  // "Current trimester" here is whatever the user last picked on the full
  // Checklist screen (getCurrentChecklistPhaseIndex), not derived from the
  // mum's real week — same source of truth both screens read from.
  Widget _buildChecklistSection(BuildContext context) {
    if (_checklistPhases.isEmpty) return const SizedBox.shrink();

    final totalItems =
        _checklistPhases.fold(0, (sum, p) => sum + phaseTotal(p));
    final totalDone =
        _checklistPhases.fold(0, (sum, p) => sum + phaseDone(p));
    final progress = totalItems == 0 ? 0.0 : totalDone / totalItems;
    final currentPhase = _checklistPhases[_checklistPhaseIndex];
    final previewItems = currentPhase.allItems.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TBSectionTitle(
          title: 'Support Checklist',
          action: 'View More',
          onAction: () {
            if (_canNav()) context.go('/next-of-kin/checklist');
          },
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            if (_canNav()) context.go('/next-of-kin/checklist');
          },
          child: TBCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$totalDone of $totalItems tasks completed',
                    style: const TextStyle(
                        color: AppColors.textMid, fontSize: 13)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.rose),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 16),
                Text('${currentPhase.emoji} ${currentPhase.label}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                for (final item in previewItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.isCompleted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: item.isCompleted
                              ? AppColors.sage
                              : AppColors.textLight,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(item.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: item.isCompleted
                                      ? AppColors.textLight
                                      : AppColors.textMid,
                                  decoration: item.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Mirrors the mum dashboard's Explore section (same TBSectionTitle +
  // card style) so AI Assistant lives in a consistent spot across roles,
  // now that it's off the bottom nav. Also absorbs the old Quick Actions
  // row (Health logs / Gift premium / Chat volunteer) — "Join consult" was
  // dropped since it duplicated the Consultations card below.
  Widget _buildExploreSection(BuildContext context) {
    final items = <({String emoji, String title, String desc, VoidCallback onTap})>[
      (
        emoji: '📋',
        title: 'Health Logs',
        desc: "View her health logs",
        onTap: () {
          // go(), not push() — /logs is a bottom-nav tab inside the same
          // ShellRoute; pushing it leaves the dashboard underneath instead
          // of replacing it, so the tab highlight never updates and the
          // dashboard never reloads when you come back to it.
          if (_canNav()) context.go('/logs');
        },
      ),
      (
        emoji: '🤖',
        title: 'AI Assistant',
        desc: 'Get personalised pregnancy guidance',
        onTap: () {
          if (_canNav()) context.push('/chatbot');
        },
      ),
      (
        emoji: '👩‍⚕️',
        title: 'Consultations',
        desc: 'Book volunteer or specialist support',
        onTap: () {
          if (_canNav()) context.push('/consultation');
        },
      ),
      (
        emoji: '🎁',
        title: 'Gift Premium',
        desc: 'Gift her a premium subscription',
        onTap: () {
          if (_canNav()) context.push('/next-of-kin/gift-subscription');
        },
      ),
      (
        emoji: '💬',
        title: 'Ask a Volunteer',
        desc: 'Post a question and any volunteer can reply',
        onTap: () async {
          if (!_canNav()) return;
          // Reload on return so a newly-posted question shows up in the
          // Quick Chat preview immediately instead of only after
          // switching tabs.
          await context.push('/ask-volunteer');
          if (mounted) _load();
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TBSectionTitle(title: 'Explore', action: ''),
        const SizedBox(height: 12),
        for (int i = 0; i < items.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _exploreCard(items[i])),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < items.length
                    ? _exploreCard(items[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _exploreCard(
      ({String emoji, String title, String desc, VoidCallback onTap}) item) {
    return GestureDetector(
      onTap: item.onTap,
      child: TBCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(item.title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text(item.desc,
                style:
                    const TextStyle(color: AppColors.textLight, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // Same alert-source builder that drives the bell badge and the full
  // Notifications Centre, so "any new notification" (milestone, active
  // consultation, health-log emergency, daily reminder, volunteer reply)
  // shows up here too — not just milestone/consultation like before.
  // Sorted latest-first, same as the full centre.
  Widget _buildActiveAlerts() {
    final sources = buildNextOfKinAlertSources(
      linkedMumWeek: _linkedMumWeek,
      consultations: _consultations,
      pregnancyLogs: _pregnancyLogs,
      dailyReminderSends: _dailyReminderSends,
      volunteerQuestions: _myQuestions,
      milestoneTimestamp: _milestoneTimestamp,
    )..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final visible = sources.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TBSectionTitle(
          title: 'Active Alerts & Notifications',
          action: 'View All',
          onAction: () async {
            if (!_canNav()) return;
            await context.push('/next-of-kin/alerts');
            if (mounted) _load();
          },
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          TBCard(
            onTap: () async {
              if (!_canNav()) return;
              await context.push('/next-of-kin/alerts');
              if (mounted) _load();
            },
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.rose.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.notifications_none_outlined,
                      color: AppColors.roseDeep, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                      'No new alerts today. Tap View All to open the Notifications Centre.',
                      style: TextStyle(color: AppColors.textMid, fontSize: 13)),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textLight, size: 18),
              ],
            ),
          )
        else
          for (final s in visible) _activeAlertCard(s),
      ],
    );
  }

  String _appointmentDateLabel(String? scheduledDate) {
    final date =
        scheduledDate != null ? DateTime.tryParse(scheduledDate) : null;
    if (date == null) return 'Upcoming Appointment';
    final today = DateTime.now();
    final diff = DateTime(date.year, date.month, date.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (diff == 0) return 'Appointment Today';
    if (diff == 1) return 'Appointment Tomorrow';
    if (diff < 0) return 'Past Appointment';
    return 'Appointment on ${DateFormat('d MMM').format(date)}';
  }

  String _appointmentSubtitle(Map<String, dynamic> c) {
    final type = (c['consultation_type'] as String? ?? 'specialist');
    final typeLabel =
        '${type[0].toUpperCase()}${type.substring(1)} Consultation 1-1';
    final time = c['scheduled_time'] as String?;
    final providerName = _providerNames[c['specialist_id']];
    if (time == null && providerName == null) return typeLabel;
    final timeProvider = [time, providerName].whereType<String>().join(' - ');
    return '$typeLabel\n$timeProvider';
  }

  ({
    IconData icon,
    Color iconBg,
    Color iconColor,
    String title,
    String subtitle,
    VoidCallback onTap,
  }) _previewFieldsForSource(NextOfKinAlertSource s) {
    switch (s.type) {
      case 'emergency':
        final log = s.log!;
        final symptoms = stringListFromArray(log['symptoms']);
        final notes = (log['notes'] ?? '').toString();
        final matches = dangerSymptomMatches(cleanHealthText(symptoms, notes));
        return (
          icon: Icons.warning_amber_rounded,
          iconBg: Colors.redAccent.withValues(alpha: 0.15),
          iconColor: Colors.redAccent,
          title: 'Symptom Alert',
          subtitle: matches.isEmpty
              ? "From $_linkedMumName's pregnancy log"
              : "From $_linkedMumName's pregnancy log: ${matches.first}",
          onTap: () {
            if (_canNav()) context.push('/logs/${log['id']}', extra: log);
          },
        );

      case 'milestone':
        final week = s.milestoneWeek!;
        return (
          icon: Icons.auto_awesome,
          iconBg: AppColors.rose.withValues(alpha: 0.15),
          iconColor: AppColors.roseDeep,
          title: 'New Milestone',
          subtitle:
              'Baby now weighs ~${pregnancyWeekData[week]?['weight'] ?? '—'} — Size of ${pregnancyWeekData[week]?['size'] ?? 'growing strong'} ${pregnancyWeekData[week]?['emoji'] ?? ''}',
          onTap: () => _comingSoon('Milestone journey'),
        );

      case 'consultation':
        final c = s.consultation!;
        return (
          icon: Icons.calendar_today_outlined,
          iconBg: AppColors.sage.withValues(alpha: 0.15),
          iconColor: AppColors.sage,
          title: _appointmentDateLabel(c['scheduled_date'] as String?),
          subtitle: _appointmentSubtitle(c),
          onTap: () {
            if (_canNav()) context.push('/consultation');
          },
        );

      case 'volunteer':
        final row = s.volunteerQuestion!;
        return (
          icon: Icons.forum_outlined,
          iconBg: AppColors.infoBlue.withValues(alpha: 0.15),
          iconColor: AppColors.infoBlue,
          title: '${quickChatVolunteerName(row)} replied',
          subtitle: 'Question: ${quickChatQuestionText(row)}',
          onTap: () async {
            if (!_canNav()) return;
            await context.push('/ask-volunteer/detail', extra: row);
            if (mounted) _load();
          },
        );

      case 'reminder':
      default:
        final row = s.reminderSend!;
        final template = row['template'] as Map<String, dynamic>?;
        final title = (template?['title'] as String?) ?? 'Reminder';
        final subtitleTemplate =
            (template?['subtitle_template'] as String?) ?? '';
        return (
          icon: iconForReminderName(template?['icon_name'] as String?),
          iconBg: AppColors.roseDeep.withValues(alpha: 0.15),
          iconColor: AppColors.roseDeep,
          title: title,
          subtitle: subtitleTemplate.replaceAll('{name}', _linkedMumName),
          onTap: () {},
        );
    }
  }

  Widget _activeAlertCard(NextOfKinAlertSource s) {
    final fields = _previewFieldsForSource(s);
    final isRead = _readAlertKeys.contains(s.key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TBCard(
        onTap: fields.onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: fields.iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(fields.icon, color: fields.iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fields.title,
                      style: TextStyle(
                          fontWeight:
                              isRead ? FontWeight.w600 : FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(fields.subtitle,
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (!isRead) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.rose, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right,
                color: AppColors.textLight, size: 18),
          ],
        ),
      ),
    );
  }
}
