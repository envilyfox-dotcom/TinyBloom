import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_theme.dart';

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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Not Now'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Subscribe'),
                ),
              ),
            ],
          ),
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
        title: const Text('Switch to Basic'),
        content: const Text(
          'Switching to Basic will remove your premium subscription.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep Premium'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textDark,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Switch'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true) await _setPlan(null);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentPlan = auth.subscriptionPlan;
    final isPremium = auth.isPremium;

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
                    const Text(
                      '✓',
                      style: TextStyle(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        features[index],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.teal.withValues(alpha: 0.55),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                buttonText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _currentPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Current',
        style: TextStyle(
          color: AppColors.teal,
          fontWeight: FontWeight.w700,
          fontSize: 9,
        ),
      ),
    );
  }

  Widget _comparisonTable() {
    final rows = [
      ('Pregnancy articles & FAQ', true, true, true),
      ('Symptom logging', true, true, true),
      ('Week-by-week tracking', true, true, true),
      ('Personalised tracking', false, true, true),
      ('Advanced symptom alerts', false, true, true),
      ('Detailed baby insights', false, true, true),
      ('Best value pricing', false, false, true),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 520),
            child: Column(
              children: [
                _comparisonHeader(),
                for (final row in rows)
                  _comparisonRow(row.$1, row.$2, row.$3, row.$4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _comparisonHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: AppColors.blush.withValues(alpha: 0.5)),
      child: const Row(
        children: [
          SizedBox(
            width: 230,
            child: Text(
              'Feature',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          SizedBox(width: 86, child: Center(child: _HeaderText('Basic'))),
          SizedBox(width: 86, child: Center(child: _HeaderText('Premium'))),
          SizedBox(width: 86, child: Center(child: _HeaderText('Annual'))),
        ],
      ),
    );
  }

  Widget _comparisonRow(String feature, bool basic, bool premium, bool annual) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.textLight.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 230,
            child: Text(
              feature,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textDark),
            ),
          ),
          SizedBox(width: 86, child: Center(child: _tickOrDash(basic))),
          SizedBox(width: 86, child: Center(child: _tickOrDash(premium))),
          SizedBox(width: 86, child: Center(child: _tickOrDash(annual))),
        ],
      ),
    );
  }

  Widget _tickOrDash(bool value) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: value
            ? AppColors.teal.withValues(alpha: 0.12)
            : AppColors.textLight.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Text(
        value ? '✓' : '—',
        style: TextStyle(
          color: value ? AppColors.teal : AppColors.textLight,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
    );
  }
}
