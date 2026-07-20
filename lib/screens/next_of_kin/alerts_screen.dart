import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/pregnancy_week_data.dart';
import '../../widgets/common_widgets.dart';

// ── Notifications Centre (Next of Kin) ────────────────────────────────
// A small, dedicated alerts list for next-of-kin — deliberately not the
// mum's NotificationsScreen (notifications_screen.dart), which is a large
// system entirely scoped to the *logged-in user's own* consultations/
// health logs/pregnancy logs. Reusing it as-is would show a next-of-kin's
// own (empty) data, not their linked mum's. This shows the full,
// un-truncated version of the same derived alerts the dashboard preview
// shows. Dismissal is local only, same placeholder as the dashboard.
class NextOfKinAlertsScreen extends StatefulWidget {
  const NextOfKinAlertsScreen({super.key});
  @override
  State<NextOfKinAlertsScreen> createState() => _NextOfKinAlertsScreenState();
}

class _NextOfKinAlertsScreenState extends State<NextOfKinAlertsScreen> {
  Map<String, dynamic>? _linkedMum;
  List<Map<String, dynamic>> _consultations = [];
  Map<String, String> _providerNames = {};
  bool _loading = true;
  final Set<String> _dismissedAlertKeys = {};

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications Centre')),
      body: _loading
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
                  : _buildAlertsList(),
            ),
    );
  }

  Widget _buildAlertsList() {
    final week = _linkedMumWeek;

    final activeConsultations = _consultations.where((c) {
      final status = (c['status'] as String? ?? '').toLowerCase();
      return status == 'pending' || status == 'confirmed';
    }).toList();

    final specs = <(
      String key,
      IconData icon,
      Color iconBg,
      Color iconColor,
      String title,
      String subtitle,
      VoidCallback onTap
    )>[
      if (week > 0)
        (
          'milestone-$week',
          Icons.auto_awesome,
          AppColors.rose.withValues(alpha: 0.15),
          AppColors.roseDeep,
          'New Milestone',
          'Baby now weighs ~${pregnancyWeekData[week]?['weight'] ?? '—'} — Size of ${pregnancyWeekData[week]?['size'] ?? 'growing strong'} ${pregnancyWeekData[week]?['emoji'] ?? ''}',
          () => _comingSoon('Milestone journey'),
        ),
      for (final c in activeConsultations)
        (
          'consultation-${c['id']}',
          Icons.calendar_today_outlined,
          AppColors.sage.withValues(alpha: 0.15),
          AppColors.sage,
          _appointmentDateLabel(c['scheduled_date'] as String?),
          _appointmentSubtitle(c),
          () => context.push('/consultation'),
        ),
    ];

    final visible =
        specs.where((s) => !_dismissedAlertKeys.contains(s.$1)).toList();

    if (visible.isEmpty) {
      return ListView(children: const [
        TBEmptyState(
            emoji: '🔔',
            title: 'No active alerts',
            subtitle: 'Milestones and upcoming appointments will show up here.'),
      ]);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final s in visible)
          _alertCard(
            icon: s.$2,
            iconBg: s.$3,
            iconColor: s.$4,
            title: s.$5,
            subtitle: s.$6,
            onTap: () {
              setState(() => _dismissedAlertKeys.add(s.$1));
              s.$7();
            },
          ),
      ],
    );
  }

  Widget _alertCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TBCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textLight, size: 18),
          ],
        ),
      ),
    );
  }
}
