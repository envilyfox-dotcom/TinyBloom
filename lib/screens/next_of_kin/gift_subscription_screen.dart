import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../shared/subscription_screen.dart' show subscriptionPlans;

const _planFeatures = {
  'premium_monthly': [
    '1-1 specialist access',
    'Priority consultation',
    'AI recommendations'
  ],
  'premium_yearly': [
    'All monthly features',
    'Advanced stats',
    'Premium content'
  ],
};

// Lets a next-of-kin buy a Premium plan on behalf of their linked mum.
class GiftSubscriptionScreen extends StatefulWidget {
  const GiftSubscriptionScreen({super.key});
  @override
  State<GiftSubscriptionScreen> createState() => _GiftSubscriptionScreenState();
}

class _GiftSubscriptionScreenState extends State<GiftSubscriptionScreen> {
  bool _loading = true;
  bool _gifting = false;
  Map<String, dynamic>? _linkedMum;
  String? _selectedPlan;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mum = await SupabaseService.getLinkedMum();
    if (mounted)
      setState(() {
        _linkedMum = mum;
        _loading = false;
      });
  }

  bool get _mumIsPremium => _linkedMum?['role'] == 'premium_user';

  // Confirms with the next-of-kin, then applies the plan straight to the
  // linked mum's account (no actual payment flow here yet).
  Future<void> _proceedToPayment() async {
    final plan = _selectedPlan;
    final mum = _linkedMum;
    if (plan == null || mum == null) return;

    final label = subscriptionPlans[plan]!['label'];
    final price = subscriptionPlans[plan]!['price'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Gift'),
        content: Text(
            'Gift ${mum['full_name'] ?? 'her'} the $label plan for $price?'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(
                child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not Now'),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Gift It'),
            )),
          ]),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _gifting = true);
    try {
      await SupabaseService.giftSubscriptionPlan(mum['id'] as String, plan);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'You gifted ${mum['full_name'] ?? 'her'} the $label plan!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _gifting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gift Subscription')),
      body: _loading
          ? const TBLoading()
          : _linkedMum == null
              ? TBEmptyState(
                  emoji: '🔗',
                  title: 'Not linked yet',
                  subtitle:
                      "Link to a pregnant user's account before gifting them Premium.",
                  buttonLabel: 'Link to Pregnant User',
                  onButton: () => context.pushReplacement('/next-of-kin/link'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                            'Gifting to: ${_linkedMum!['full_name'] ?? 'her'}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontSize: 20)),
                      ),
                      const SizedBox(height: 20),
                      if (_mumIsPremium) ...[
                        _alreadyPremiumCard(),
                      ] else ...[
                        for (final entry in subscriptionPlans.entries) ...[
                          _planTile(entry.key, entry.value['label']!,
                              entry.value['price']!),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 8),
                        TBButton(
                          label: 'Proceed to Payment',
                          loading: _gifting,
                          onPressed:
                              _selectedPlan == null ? null : _proceedToPayment,
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _alreadyPremiumCard() {
    final plan = _linkedMum?['subscription_plan'] as String?;
    final planLabel = subscriptionPlans[plan]?['label'] ?? 'Premium';
    final name = _linkedMum?['full_name'] ?? 'She';
    return TBCard(
      color: AppColors.blush,
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('⭐', style: TextStyle(fontSize: 28)),
              SizedBox(width: 10),
              Expanded(
                child: Text('Already Premium',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              '$name is already on the $planLabel plan — no need to gift a subscription right now.',
              style: const TextStyle(
                  color: AppColors.textMid, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _planTile(String key, String name, String price) {
    final selected = _selectedPlan == key;
    final features = _planFeatures[key] ?? const [];
    return TBCard(
      color: AppColors.blush,
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 8),
                    for (final f in features)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('• $f',
                            style: const TextStyle(
                                color: AppColors.textMid, fontSize: 12)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(price,
                      style: const TextStyle(
                          color: AppColors.rose,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() => _selectedPlan = key),
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            selected ? AppColors.roseDeep : AppColors.rose,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10)),
                    child: Text(selected ? 'Selected' : 'Select',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
