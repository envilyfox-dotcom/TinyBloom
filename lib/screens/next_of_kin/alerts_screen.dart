import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/next_of_kin_alert_read_state.dart';
import '../../utils/next_of_kin_alerts_data.dart';
import '../../utils/pregnancy_log_danger_scan.dart';
import '../../utils/pregnancy_week_data.dart';
import '../../utils/singapore_time.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/quick_chat_volunteer.dart';

// Notifications feed for next-of-kin: emergencies, milestones, consultations,
// reminders and volunteer replies all get merged into one timeline here.
class NextOfKinAlertsScreen extends StatefulWidget {
  const NextOfKinAlertsScreen({super.key});
  @override
  State<NextOfKinAlertsScreen> createState() => _NextOfKinAlertsScreenState();
}

// A single row in the alerts list, already formatted for display.
class _AlertItem {
  final String key;
  final String type;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<String> detailLines;
  final String? badge;
  final DateTime timestamp;
  final VoidCallback onTap;
  _AlertItem({
    required this.key,
    required this.type,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.detailLines = const [],
    this.badge,
    required this.timestamp,
    required this.onTap,
  });
}

class _NextOfKinAlertsScreenState extends State<NextOfKinAlertsScreen> {
  Map<String, dynamic>? _linkedMum;
  List<Map<String, dynamic>> _consultations = [];
  List<Map<String, dynamic>> _pregnancyLogs = [];
  List<Map<String, dynamic>> _dailyReminderSends = [];
  List<Map<String, dynamic>> _myQuestions = [];
  DateTime? _milestoneTimestamp;
  Map<String, String> _providerNames = {};
  bool _loading = true;
  String _selectedFilter = 'All';
  Set<String> _readAlertKeys = {};

  static const _filters = [
    'All',
    'Emergency',
    'Milestone',
    'Consultation',
    'Reminder',
    'Volunteer',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Pulls together everything an alert could be made from (consultations,
  // logs, reminders, volunteer replies) and figures out which are unread.
  Future<void> _load() async {
    final previouslyReadKeys = await getReadAlertKeys();

    Map<String, dynamic>? linkedMum;
    try {
      linkedMum = await SupabaseService.getLinkedMum();
    } catch (_) {}

    List<Map<String, dynamic>> consultations = [];
    List<Map<String, dynamic>> pregnancyLogs = [];
    List<Map<String, dynamic>> dailyReminderSends = [];
    final providerNames = <String, String>{};
    if (linkedMum != null) {
      final mumId = linkedMum['id'] as String;
      consultations = await SupabaseService.getConsultationsForPatient(mumId);

      try {
        pregnancyLogs = await SupabaseService.getLogsForPatient(mumId);
      } catch (_) {}

      try {
        dailyReminderSends = await SupabaseService.getMyDailyReminders();
      } catch (_) {}

      final activeSpecialistIds = consultations
          .where((c) {
            final status = (c['status'] as String? ?? '').toLowerCase();
            return status == 'pending' || status == 'confirmed';
          })
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
    }

    List<Map<String, dynamic>> myQuestions = [];
    try {
      final rawQuestions = await SupabaseService.getMyVolunteerQuestions();
      myQuestions = await enrichQuickChatQuestions(
        List<Map<String, dynamic>>.from(rawQuestions),
      );
    } catch (_) {}

    final week = (linkedMum?['current_week'] as int?) ?? 0;
    final weekStartDate = DateTime.tryParse(
        (linkedMum?['current_week_start_date'] ?? '').toString());
    final milestoneTimestamp = week <= 0
        ? null
        : weekStartDate ?? await getOrRecordMilestoneTimestamp(week);

    if (mounted) {
      setState(() {
        _linkedMum = linkedMum;
        _consultations = consultations;
        _pregnancyLogs = pregnancyLogs;
        _dailyReminderSends = dailyReminderSends;
        _myQuestions = myQuestions;
        _milestoneTimestamp = milestoneTimestamp;
        _providerNames = providerNames;
        _readAlertKeys = previouslyReadKeys;
        _loading = false;
      });

      final currentKeys = _allAlerts.map((a) => a.key).toSet();
      await markAlertKeysRead(currentKeys);
    }
  }

  int get _linkedMumWeek => (_linkedMum?['current_week'] as int?) ?? 0;
  String get _linkedMumName => (_linkedMum?['full_name'] as String?) ?? 'her';

  String _titleCase(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return clean;
    return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
  }

  String _consultationScheduledLine(Map<String, dynamic> c) {
    final dateStr = c['scheduled_date'] as String?;
    final time = (c['scheduled_time'] as String?)?.trim();
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    if (date == null) return time ?? 'Not confirmed yet';
    final formatted = DateFormat('yyyy-MM-dd').format(date);
    return time == null || time.isEmpty ? formatted : '$formatted, $time';
  }

  List<String> _consultationDetailLines(Map<String, dynamic> c) {
    final purpose = (c['purpose'] as String? ?? '').trim();
    final platform = (c['platform'] as String? ?? 'Zoom Meeting').trim();
    final status = (c['status'] as String? ?? 'pending');
    return [
      'Time: ${_consultationScheduledLine(c)}',
      if (purpose.isNotEmpty) 'Purpose: $purpose',
      'Mode: $platform',
      'Status: ${_titleCase(status)}',
    ];
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature — coming soon')));
  }

  // Turns a raw alert source into something the UI can render (icon, colour,
  // title, subtitle, tap action) — one branch per alert type.
  _AlertItem _alertItemFromSource(NextOfKinAlertSource s) {
    switch (s.type) {
      case 'emergency':
        final log = s.log!;
        final symptoms = stringListFromArray(log['symptoms']);
        final notes = (log['notes'] ?? '').toString();
        // Re-scan the log against the danger keyword list so we can show
        // which symptom actually triggered this alert.
        final matches = dangerSymptomMatches(cleanHealthText(symptoms, notes));
        return _AlertItem(
          key: s.key,
          type: 'emergency',
          icon: Icons.warning_amber_rounded,
          color: Colors.redAccent,
          title: 'Symptom Alert',
          subtitle: "From $_linkedMumName's pregnancy log: ${matches.first}",
          detailLines: [
            "From: $_linkedMumName's pregnancy log",
            'Severity: Urgent',
            'Issue: Abnormal pregnancy log detected',
            if (symptoms.isNotEmpty) 'Symptoms: ${symptoms.join(', ')}',
            if (notes.trim().isNotEmpty) 'Notes: ${notes.trim()}',
          ],
          badge: 'Log alert',
          timestamp: s.timestamp,
          onTap: () => context.push('/logs/${log['id']}', extra: log),
        );

      case 'milestone':
        final week = s.milestoneWeek!;
        return _AlertItem(
          key: s.key,
          type: 'milestone',
          icon: Icons.auto_awesome,
          color: AppColors.rose,
          title: 'New Milestone',
          subtitle:
              'Baby now weighs ~${pregnancyWeekData[week]?['weight'] ?? '—'} — Size of ${pregnancyWeekData[week]?['size'] ?? 'growing strong'} ${pregnancyWeekData[week]?['emoji'] ?? ''}',
          timestamp: s.timestamp,
          onTap: () => _comingSoon('Milestone journey'),
        );

      case 'consultation':
        final c = s.consultation!;
        final providerName = _providerNames[c['specialist_id']] ?? 'Specialist';
        final purpose = (c['purpose'] as String? ?? '').trim();
        final platform = (c['platform'] as String? ?? 'Zoom Meeting').trim();
        final status = (c['status'] as String? ?? 'pending');
        final subtitle = [
          if (purpose.isNotEmpty) purpose,
          _consultationScheduledLine(c),
          platform,
          '${_titleCase(status)} Specialist',
        ].join(' • ');
        return _AlertItem(
          key: s.key,
          type: 'consultation',
          icon: Icons.calendar_month_outlined,
          color: AppColors.sage,
          title: providerName,
          subtitle: subtitle,
          detailLines: _consultationDetailLines(c),
          timestamp: s.timestamp,
          onTap: () => context.push('/consultation/detail', extra: c),
        );

      case 'volunteer':
        final row = s.volunteerQuestion!;
        final volunteerName = quickChatVolunteerName(row);
        final questionText = quickChatQuestionText(row);
        return _AlertItem(
          key: s.key,
          type: 'volunteer',
          icon: Icons.forum_outlined,
          color: AppColors.infoBlue,
          title: '$volunteerName replied',
          subtitle: 'Question: $questionText',
          timestamp: s.timestamp,
          onTap: () => context.push('/ask-volunteer/detail', extra: row),
        );

      case 'reminder':
      default:
        final row = s.reminderSend!;
        final template = row['template'] as Map<String, dynamic>?;
        final title = (template?['title'] as String?) ?? 'Reminder';
        final subtitleTemplate =
            (template?['subtitle_template'] as String?) ?? '';
        return _AlertItem(
          key: s.key,
          type: 'reminder',
          icon: iconForReminderName(template?['icon_name'] as String?),
          color: AppColors.roseDeep,
          title: title,
          subtitle: subtitleTemplate.replaceAll('{name}', _linkedMumName),
          timestamp: s.timestamp,
          onTap: () {},
        );
    }
  }

  List<_AlertItem> get _allAlerts {
    final sources = buildNextOfKinAlertSources(
      linkedMumWeek: _linkedMumWeek,
      consultations: _consultations,
      pregnancyLogs: _pregnancyLogs,
      dailyReminderSends: _dailyReminderSends,
      volunteerQuestions: _myQuestions,
      milestoneTimestamp: _milestoneTimestamp,
    );
    final items = [for (final s in sources) _alertItemFromSource(s)];
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  List<_AlertItem> get _filteredAlerts {
    final all = _allAlerts;
    if (_selectedFilter == 'All') return all;
    return all.where((a) => a.type == _selectedFilter.toLowerCase()).toList();
  }

  bool _isRead(_AlertItem item) => _readAlertKeys.contains(item.key);

  int get _unreadCount => _allAlerts.where((a) => !_isRead(a)).length;

  int get _urgentCount =>
      _allAlerts.where((a) => a.type == 'emergency' && !_isRead(a)).length;

  Future<void> _markAllAsRead() async {
    final keys = _allAlerts.map((a) => a.key).toSet();
    await markAlertKeysRead(keys);
    if (mounted) {
      setState(() => _readAlertKeys = _readAlertKeys.union(keys));
    }
  }

  // Alerts are stored in UTC-ish timestamps but we always show them in
  // Singapore time since that's where our users are.
  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    return DateFormat('d MMM, h:mm a').format(toSingaporeTime(date));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const TBLoading()
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.rose,
                child: _linkedMum == null
                    ? ListView(children: [
                        TBEmptyState(
                          emoji: '🔗',
                          title: 'Not linked yet',
                          subtitle:
                              "Link to a pregnant user's account to see her alerts.",
                          buttonLabel: 'Link to Pregnant User',
                          onButton: () => context.push('/next-of-kin/link'),
                        ),
                      ])
                    : _buildContent(),
              ),
      ),
    );
  }

  Widget _buildContent() {
    final all = _allAlerts;
    final filtered = _filteredAlerts;
    final unreadCount = _unreadCount;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/home');
                        }
                      },
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    if (_urgentCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_urgentCount Urgent',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Notifications Centre',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    all.isEmpty
                        ? 'You are all caught up 🌸'
                        : unreadCount == 0
                            ? 'You are all caught up 🌸'
                            : '$unreadCount unread alert${unreadCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppColors.textMid,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (unreadCount > 0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _markAllAsRead,
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('Mark all as read'),
                    ),
                  ),
                const SizedBox(height: 6),
                _buildFilters(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          sliver: filtered.isEmpty
              ? SliverToBoxAdapter(child: _emptyState())
              : SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _alertCard(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final selected = filter == _selectedFilter;

          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.rose : AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppColors.rose
                      : AppColors.textLight.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textMid,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 42,
            color: AppColors.textLight,
          ),
          SizedBox(height: 10),
          Text(
            'No active alerts',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Milestones, appointments, health alerts, reminders and volunteer replies will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _sectionTitle(String type) {
    switch (type) {
      case 'emergency':
        return 'Emergency Alert';
      case 'milestone':
        return 'Pregnancy Milestone';
      case 'consultation':
        return 'Consultation Update';
      case 'reminder':
        return 'Daily Reminder';
      case 'volunteer':
        return 'Volunteer Reply';
      default:
        return 'Notification';
    }
  }

  Widget _detailPanel(List<String> lines, Color color) {
    if (lines.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMid,
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (line != lines.last) const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }

  Widget _alertCard(_AlertItem item) {
    final isRead = _isRead(item);
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isRead
                ? AppColors.textLight.withValues(alpha: 0.12)
                : item.color.withValues(alpha: 0.38),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _sectionTitle(item.type),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: item.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (item.badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item.badge!,
                            style: TextStyle(
                              color: item.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMid,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  if (item.detailLines.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    _detailPanel(item.detailLines, item.color),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _timeAgo(item.timestamp),
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                if (!isRead)
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AppColors.rose,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(height: 18),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textLight,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
