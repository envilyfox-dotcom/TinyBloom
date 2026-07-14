import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'specialist_notifications_helpers.dart';

// ── Specialist Notifications Centre ─────────────────────────────────
// Same tagging system as the premium user's Notifications Centre
// (lib/screens/shared/notifications_screen.dart), scoped to what a
// specialist needs to act on: Consultation confirmations/reminders and
// Review queue items. Emergency is intentionally left empty for now.
class SpecialistNotificationsScreen extends StatefulWidget {
  const SpecialistNotificationsScreen({super.key});

  @override
  State<SpecialistNotificationsScreen> createState() =>
      _SpecialistNotificationsScreenState();
}

class _SpecialistNotificationsScreenState
    extends State<SpecialistNotificationsScreen> {
  static const _tabs = ['All', 'Emergency', 'Consultation', 'Review'];

  bool _loading = true;
  List<Map<String, dynamic>> _notifications = [];
  String _selectedTab = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    List<Map<String, dynamic>> consultations = [];
    try {
      consultations = await SupabaseService.getConsultations();
    } catch (_) {}

    List<Map<String, dynamic>> reviewQueue = [];
    try {
      reviewQueue = await SupabaseService.getReviewQueue();
    } catch (_) {}

    final userId = SupabaseService.currentUser?.id ?? '';
    final notifications = buildSpecialistNotifications(
      consultations: consultations,
      reviewQueue: reviewQueue,
      userId: userId,
    );

    if (mounted) {
      setState(() {
        _notifications = notifications;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedTab == 'All') return _notifications;
    final category = _selectedTab.toLowerCase();
    return _notifications.where((n) => n['category'] == category).toList();
  }

  Color _color(String category) {
    switch (category) {
      case 'consultation':
        return AppColors.sage;
      case 'review':
        return AppColors.teal;
      case 'emergency':
        return Colors.redAccent;
      default:
        return AppColors.textMid;
    }
  }

  IconData _icon(String category) {
    switch (category) {
      case 'consultation':
        return Icons.calendar_today_outlined;
      case 'review':
        return Icons.rate_review_outlined;
      case 'emergency':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Future<void> _open(Map<String, dynamic> n) async {
    final category = n['category'] as String? ?? 'general';
    if (category == 'consultation') {
      final consultation = n['consultation'] as Map<String, dynamic>?;
      if (consultation != null) {
        await context.push('/consultation/detail', extra: consultation);
        if (mounted) _load();
      }
    } else if (category == 'review') {
      final article = n['article'] as Map<String, dynamic>?;
      final id = article?['id']?.toString();
      if (id != null) {
        await context.push('/specialist/review/thread', extra: id);
        if (mounted) _load();
      }
    }
  }

  Widget _card(Map<String, dynamic> n) {
    final category = n['category'] as String? ?? 'general';
    final color = _color(category);
    final createdAt = DateTime.tryParse(n['created_at']?.toString() ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TBCard(
        onTap: () => _open(n),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon(category), color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n['title'] as String? ?? 'Notification',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.textDark)),
                    const SizedBox(height: 4),
                    Text(n['message'] as String? ?? '',
                        style: const TextStyle(
                            color: AppColors.textMid,
                            fontSize: 13,
                            height: 1.3)),
                    if (createdAt != null) ...[
                      const SizedBox(height: 6),
                      Text(timeAgoLabel(createdAt),
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Notifications Centre',
            style: TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tab = _tabs[index];
                  final selected = _selectedTab == tab;

                  return ChoiceChip(
                    label: Text(tab),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedTab = tab),
                    selectedColor: AppColors.blush,
                    backgroundColor: AppColors.white,
                    side: BorderSide(
                      color: selected
                          ? AppColors.rose
                          : AppColors.textLight.withValues(alpha: 0.25),
                    ),
                    labelStyle: TextStyle(
                      color:
                          selected ? AppColors.roseDeep : AppColors.textMid,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    checkmarkColor: AppColors.roseDeep,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const TBLoading()
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.rose,
                    child: filtered.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 100),
                              TBEmptyState(
                                emoji:
                                    _selectedTab == 'Emergency' ? '🚨' : '🔔',
                                title: 'Nothing here',
                                subtitle: _selectedTab == 'Emergency'
                                    ? 'Emergency alerts will show here.'
                                    : "You're all caught up.",
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) =>
                                _card(filtered[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
