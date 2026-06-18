import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../services/supabase_service.dart';
import '../../../services/auth_provider.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import 'consultation_helpers.dart';

// ── Consultation List Screen ──────────────────────────────────────
class ConsultationListScreen extends StatefulWidget {
  const ConsultationListScreen({super.key});
  @override
  State<ConsultationListScreen> createState() => _ConsultationListScreenState();
}

class _ConsultationListScreenState extends State<ConsultationListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _consultations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  String? _error;

  Future<void> _load() async {
    try {
      final c = await SupabaseService.getConsultations();
      if (mounted) {
        setState(() {
          _consultations = c;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<AuthProvider>().isPremium;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultations'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.teal,
          labelColor: AppColors.teal,
          unselectedLabelColor: AppColors.textLight,
          tabs: const [Tab(text: 'My Consultations'), Tab(text: 'Book New')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // Tab 1: My consultations
          _loading
              ? const TBLoading()
              : _error != null
                  ? TBEmptyState(
                      emoji: '⚠️',
                      title: 'Couldn\'t load consultations',
                      subtitle: _error!,
                      buttonLabel: 'Retry',
                      onButton: () { setState(() => _loading = true); _load(); })
                  : _consultations.isEmpty
                  ? TBEmptyState(
                      emoji: '👩‍⚕️',
                      title: 'No consultations yet',
                      subtitle: isPremium
                          ? 'Book a consultation with a specialist or volunteer.'
                          : 'Book a consultation with a volunteer.',
                      buttonLabel: 'Book Now',
                      onButton: () => _tabs.animateTo(1))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _consultations.length,
                      itemBuilder: (ctx, i) {
                        final c = _consultations[i];
                        final status = c['status'] ?? 'pending';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TBCard(
                            onTap: () async {
                              await context.push('/consultation/detail', extra: c);
                              _load();
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                      color: statusColor(status)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Center(
                                      child: Text(statusEmoji(status),
                                          style:
                                              const TextStyle(fontSize: 20))),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          consultationTypeLabel(
                                              c['consultation_type'] as String?),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14)),
                                      Text(status.toUpperCase(),
                                          style: TextStyle(
                                              color: statusColor(status),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    color: AppColors.textLight, size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

          // Tab 2: Book new — everyone can reach volunteers; specialists are premium-only.
          _buildBookTab(isPremium),
        ],
      ),
    );
  }

  Widget _buildBookTab(bool isPremium) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TBSectionTitle(title: 'Choose Provider Type'),
          const SizedBox(height: 12),
          if (!isPremium) ...[
            const Text(
                'Free accounts can connect with community volunteers. Upgrade to Premium for verified specialists.',
                style: TextStyle(color: AppColors.textMid, fontSize: 12)),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TBCard(
                  color: AppColors.blush,
                  onTap: () => context.push('/consultation/specialists'),
                  child: Column(
                    children: [
                      if (!isPremium)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.star, color: AppColors.gold, size: 12),
                          ),
                        ),
                      const Text('👩‍⚕️', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      const Text('Specialist',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Verified doctors',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textLight)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TBCard(
                  color: AppColors.tealLight,
                  onTap: () => context.push('/consultation/volunteers'),
                  child: const Column(
                    children: [
                      Text('🤝', style: TextStyle(fontSize: 36)),
                      SizedBox(height: 8),
                      Text('Volunteer',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('Community support',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textLight)),
                    ],
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
