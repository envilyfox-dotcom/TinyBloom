import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/pregnancy_week_data.dart';
import '../../widgets/common_widgets.dart';

// ── Notifications Centre (Next of Kin) ────────────────────────────────
// Restyled to match the mum's NotificationsScreen (header with urgent
// badge, title, unread-style count, "Clear all", horizontal filter chips,
// notification-card look) — but deliberately keeps the smaller data
// source used before (the linked mum's milestones + consultations),
// not the mum's full multi-table system (health logs, articles, AI
// recommendations, etc.), which is scoped to the *logged-in user's own*
// data and isn't applicable to a next-of-kin viewer. Dismissal is local/
// session-only, same as before.
class NextOfKinAlertsScreen extends StatefulWidget {
  const NextOfKinAlertsScreen({super.key});
  @override
  State<NextOfKinAlertsScreen> createState() => _NextOfKinAlertsScreenState();
}

class _AlertItem {
  final String key;
  final String type; // 'milestone' | 'consultation'
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  _AlertItem({
    required this.key,
    required this.type,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _NextOfKinAlertsScreenState extends State<NextOfKinAlertsScreen> {
  Map<String, dynamic>? _linkedMum;
  List<Map<String, dynamic>> _consultations = [];
  Map<String, String> _providerNames = {};
  bool _loading = true;
  String _selectedFilter = 'All';
  final Set<String> _dismissedAlertKeys = {};

  static const _filters = ['All', 'Milestone', 'Consultation'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic>? linkedMum;
    try {
      linkedMum = await SupabaseService.getLinkedMum();
    } catch (_) {}

    List<Map<String, dynamic>> consultations = [];
    final providerNames = <String, String>{};
    if (linkedMum != null) {
      consultations = await SupabaseService.getConsultationsForPatient(
          linkedMum['id'] as String);

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

    if (mounted) {
      setState(() {
        _linkedMum = linkedMum;
        _consultations = consultations;
        _providerNames = providerNames;
        _loading = false;
      });
    }
  }

  int get _linkedMumWeek => (_linkedMum?['current_week'] as int?) ?? 0;

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

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature — coming soon')));
  }

  List<_AlertItem> get _allAlerts {
    final week = _linkedMumWeek;
    final activeConsultations = _consultations.where((c) {
      final status = (c['status'] as String? ?? '').toLowerCase();
      return status == 'pending' || status == 'confirmed';
    }).toList();

    return [
      if (week > 0)
        _AlertItem(
          key: 'milestone-$week',
          type: 'milestone',
          icon: Icons.auto_awesome,
          color: AppColors.rose,
          title: 'New Milestone',
          subtitle:
              'Baby now weighs ~${pregnancyWeekData[week]?['weight'] ?? '—'} — Size of ${pregnancyWeekData[week]?['size'] ?? 'growing strong'} ${pregnancyWeekData[week]?['emoji'] ?? ''}',
          onTap: () => _comingSoon('Milestone journey'),
        ),
      for (final c in activeConsultations)
        _AlertItem(
          key: 'consultation-${c['id']}',
          type: 'consultation',
          icon: Icons.calendar_month_outlined,
          color: AppColors.sage,
          title: _appointmentDateLabel(c['scheduled_date'] as String?),
          subtitle: _appointmentSubtitle(c),
          onTap: () => context.push('/consultation'),
        ),
    ];
  }

  List<_AlertItem> get _visibleAlerts =>
      _allAlerts.where((a) => !_dismissedAlertKeys.contains(a.key)).toList();

  List<_AlertItem> get _filteredAlerts {
    final visible = _visibleAlerts;
    if (_selectedFilter == 'All') return visible;
    return visible
        .where((a) => a.type == _selectedFilter.toLowerCase())
        .toList();
  }

  int get _urgentCount => _visibleAlerts
      .where((a) => a.type == 'consultation' && a.title.contains('Today'))
      .length;

  void _dismiss(_AlertItem item) {
    setState(() => _dismissedAlertKeys.add(item.key));
  }

  void _clearAll() {
    setState(() {
      _dismissedAlertKeys.addAll(_visibleAlerts.map((a) => a.key));
    });
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
    final visible = _visibleAlerts;
    final filtered = _filteredAlerts;

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
                          '$_urgentCount Today',
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
                    visible.isEmpty
                        ? 'You are all caught up 🌸'
                        : '${visible.length} active alert${visible.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppColors.textMid,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (visible.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _clearAll,
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('Clear all'),
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
            'Milestones and upcoming appointments will show up here.',
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

  String _sectionTitle(String type) =>
      type == 'milestone' ? 'Pregnancy Milestone' : 'Consultation Update';

  Widget _alertCard(_AlertItem item) {
    return GestureDetector(
      onTap: () {
        _dismiss(item);
        item.onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: item.color.withValues(alpha: 0.38)),
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
                  Text(
                    _sectionTitle(item.type),
                    style: TextStyle(
                      color: item.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
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
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
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
