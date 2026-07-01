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

const _subscriptionPlans = {
  'premium_monthly': {'label': 'Premium', 'price': '\$9.90/month'},
  'premium_yearly': {'label': 'Premium Annual', 'price': '\$90/year'},
};

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _busy = false;

  Future<void> _setPlan(String? plan) async {
    setState(() => _busy = true);
    try {
      await SupabaseService.setSubscriptionPlan(plan);
      if (mounted) await context.read<AuthProvider>().refreshProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              plan == null
                  ? 'You are now on the Basic plan.'
                  : 'You are now on the ${_subscriptionPlans[plan]!['label']} plan!',
            ),
          ),
        );
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
    final label = _subscriptionPlans[plan]!['label'];
    final price = _subscriptionPlans[plan]!['price'];

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

  Future<void> _confirmBasic() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already on the Basic plan.')),
      );
      return;
    }

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Subscription',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Compare Plans',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose the plan that best supports your pregnancy journey.',
                style: TextStyle(color: AppColors.textMid, fontSize: 13),
              ),
              const SizedBox(height: 18),
              _currentPlanBanner(isPremium, currentPlan),
              const SizedBox(height: 20),
              _planCards(currentPlan, isPremium),
              const SizedBox(height: 24),
              Text(
                'Feature Comparison',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _comparisonTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _currentPlanBanner(bool isPremium, String? currentPlan) {
    final label = currentPlan == 'premium_monthly'
        ? 'Premium Monthly'
        : currentPlan == 'premium_yearly'
            ? 'Premium Annual'
            : 'Basic';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPremium ? AppColors.blush : AppColors.tealLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPremium
              ? AppColors.rose.withValues(alpha: 0.25)
              : AppColors.teal.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Text(isPremium ? '⭐' : '🌱', style: const TextStyle(fontSize: 34)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Plan: $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isPremium
                      ? 'You currently have premium access.'
                      : 'You are using the free Basic plan.',
                  style:
                      const TextStyle(color: AppColors.textMid, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCards(String? currentPlan, bool isPremium) {
    return SizedBox(
      height: 415,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _planCard(
            title: 'Basic',
            price: '\$0',
            period: '/ month',
            tagline: 'Basic information and simple tracking.',
            features: const [
              'Pregnancy articles & FAQ',
              'Simple symptom logging',
              'Basic week-by-week tracking',
            ],
            isCurrent: !isPremium,
            isFeatured: false,
            buttonText: isPremium ? 'Switch to Basic' : 'Current Plan',
            onPressed: _busy ? null : _confirmBasic,
          ),
          const SizedBox(width: 14),
          _planCard(
            title: 'Premium',
            price: '\$9.90',
            period: '/ month',
            tagline: 'Personalised insights and full support.',
            features: const [
              'Personalised pregnancy tracking',
              'Advanced symptom tracking',
              'Detailed baby development insights',
              'Full access to all resources',
            ],
            isCurrent: currentPlan == 'premium_monthly',
            isFeatured: true,
            buttonText: currentPlan == 'premium_monthly'
                ? 'Current Plan'
                : 'Get Started',
            onPressed: _busy || currentPlan == 'premium_monthly'
                ? null
                : () => _confirmUpgrade('premium_monthly'),
          ),
          const SizedBox(width: 14),
          _planCard(
            title: 'Premium Annual',
            price: '\$90',
            period: '/ year',
            tagline: 'Best value — save compared to monthly.',
            features: const [
              'Personalised pregnancy tracking',
              'Advanced symptom tracking',
              'Detailed baby development insights',
              'Full access to all resources',
            ],
            isCurrent: currentPlan == 'premium_yearly',
            isFeatured: false,
            buttonText: currentPlan == 'premium_yearly'
                ? 'Current Plan'
                : 'Get Started',
            onPressed: _busy || currentPlan == 'premium_yearly'
                ? null
                : () => _confirmUpgrade('premium_yearly'),
          ),
        ],
      ),
    );
  }

  Widget _planCard({
    required String title,
    required String price,
    required String period,
    required String tagline,
    required List<String> features,
    required bool isCurrent,
    required bool isFeatured,
    required String buttonText,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: 245,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isFeatured ? AppColors.tealLight : AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFeatured ? AppColors.teal : Colors.transparent,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (isCurrent) _currentPill(),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 34,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  period,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tagline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMid,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: features.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
