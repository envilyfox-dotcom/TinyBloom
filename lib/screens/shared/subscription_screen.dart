import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── Subscription Screen ───────────────────────────────────────────
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

// Plan metadata shared by the upgrade tiles and the Change Plan sheet.
const subscriptionPlans = {
  'premium_monthly': {'label': 'Premium Monthly', 'price': '\$9.90/month'},
  'premium_yearly': {'label': 'Premium Annual', 'price': '\$90/year • Save 24%'},
};

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _busy = false;

  // There's no real payment gateway here — "subscribing" just records the
  // chosen plan and flips the role, same as everywhere else this app mocks
  // a feature it can't actually wire up to a third party.
  Future<void> _setPlan(String? plan) async {
    setState(() => _busy = true);
    try {
      await SupabaseService.setSubscriptionPlan(plan);
      if (mounted) await context.read<AuthProvider>().refreshProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(plan == null
                ? 'Subscription cancelled.'
                : 'You\'re on the ${subscriptionPlans[plan]!['label']} plan!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _confirmUpgrade(String plan) async {
    final label = subscriptionPlans[plan]!['label'];
    final price = subscriptionPlans[plan]!['price'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Subscription'),
        content: Text('Subscribe to $label for $price?'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not Now'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Subscribe'),
            )),
          ]),
        ],
      ),
    );
    if (confirm == true) await _setPlan(plan);
  }

  void _showChangePlan(String? currentPlan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Change Plan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
                currentPlan == null
                    ? 'No plan on file yet — choose one below.'
                    : 'Choose between monthly and yearly billing.',
                style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
            const SizedBox(height: 16),
            for (final entry in subscriptionPlans.entries) ...[
              _planTile(entry.key, entry.value['label']!, entry.value['price']!,
                  isCurrent: entry.key == currentPlan,
                  onSelect: () {
                    Navigator.pop(context);
                    if (entry.key != currentPlan) _setPlan(entry.key);
                  }),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Text(
            'Are you sure? You\'ll lose access to premium features immediately.'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Plan'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel Plan'),
            )),
          ]),
        ],
      ),
    );
    if (confirm == true) await _setPlan(null);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isPremium = auth.isPremium;
    final currentPlan = auth.subscriptionPlan;

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TBCard(
              color: isPremium ? AppColors.blush : AppColors.tealLight,
              child: Row(
                children: [
                  Text(isPremium ? '⭐' : '🌱',
                      style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isPremium ? 'Premium Member' : 'Free Member',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontSize: 16)),
                        Text(
                            isPremium
                                ? (currentPlan != null
                                    ? 'You\'re on the ${subscriptionPlans[currentPlan]?['label'] ?? 'Premium'} plan.'
                                    : 'You have access to all premium features.')
                                : 'Upgrade to unlock all features.',
                            style: const TextStyle(
                                color: AppColors.textMid, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (!isPremium) ...[
              Text('Upgrade to Premium',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              for (final entry in subscriptionPlans.entries) ...[
                _planTile(entry.key, entry.value['label']!, entry.value['price']!,
                    onSelect: _busy ? null : () => _confirmUpgrade(entry.key)),
                const SizedBox(height: 10),
              ],
            ],
            if (isPremium) ...[
              Text('Manage Subscription',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TBCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading:
                          const Icon(Icons.swap_horiz, color: AppColors.teal),
                      title: const Text('Change Plan'),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.textLight),
                      onTap: _busy ? null : () => _showChangePlan(currentPlan),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading:
                          const Icon(Icons.cancel_outlined, color: Colors.red),
                      title: const Text('Cancel Subscription',
                          style: TextStyle(color: Colors.red)),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.textLight),
                      onTap: _busy ? null : () => _confirmCancel(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _planTile(String key, String name, String price,
      {bool isCurrent = false, required VoidCallback? onSelect}) {
    return TBCard(
      color: AppColors.tealLight,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                Text(price,
                    style:
                        const TextStyle(color: AppColors.teal, fontSize: 13)),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('Current Plan',
                  style: TextStyle(
                      color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 12)),
            )
          else
            ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              child: const Text('Select', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
