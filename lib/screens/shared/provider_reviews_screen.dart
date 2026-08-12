import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/review_widgets.dart';

// Shows all ratings/reviews left for a specialist or volunteer.
class ProviderReviewsScreen extends StatefulWidget {
  final String providerId;
  final String providerName;
  final String providerType;

  const ProviderReviewsScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.providerType,
  });

  @override
  State<ProviderReviewsScreen> createState() => _ProviderReviewsScreenState();
}

class _ProviderReviewsScreenState extends State<ProviderReviewsScreen> {
  List<Map<String, dynamic>> _ratings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<Map<String, dynamic>> ratings = [];
    try {
      ratings = await SupabaseService.getProviderRatings(widget.providerId);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _ratings = ratings;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSpecialist = widget.providerType == 'specialist';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(isSpecialist
            ? 'Reviews for Dr. ${widget.providerName}'
            : 'Reviews for ${widget.providerName}'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _ratings.isEmpty
                ? const TBEmptyState(
                    emoji: '⭐',
                    title: 'No reviews yet',
                    subtitle:
                        'Reviews from the mums you\'ve helped will show here.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    itemCount: _ratings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        providerReviewCard(context, _ratings[index]),
                  ),
      ),
    );
  }
}
