import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── FAQ Screen ────────────────────────────────────────────────────
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});
  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  List<Map<String, dynamic>> _faqs = [];
  bool _loading = true;
  String _selectedCat = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final faqs = await SupabaseService.getFaqs();
    if (mounted) {
      setState(() {
        _faqs = faqs;
        _loading = false;
      });
    }
  }

  List<String> get _categories {
    final cats = {
      'All',
      ..._faqs.map((f) => f['category'] as String? ?? 'General')
    };
    return cats.toList();
  }

  List<Map<String, dynamic>> get _filtered => _selectedCat == 'All'
      ? _faqs
      : _faqs.where((f) => f['category'] == _selectedCat).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: _loading
          ? const TBLoading()
          : Column(
              children: [
                // Category chips
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    children: _categories
                        .map((cat) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(cat),
                                selected: _selectedCat == cat,
                                onSelected: (_) =>
                                    setState(() => _selectedCat = cat),
                                selectedColor: AppColors.tealLight,
                                checkmarkColor: AppColors.teal,
                                labelStyle: TextStyle(
                                    color: _selectedCat == cat
                                        ? AppColors.teal
                                        : AppColors.textMid,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                                backgroundColor: AppColors.white,
                                side: BorderSide(
                                    color: _selectedCat == cat
                                        ? AppColors.teal
                                        : AppColors.textLight.withValues(alpha: 0.3)),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final faq = _filtered[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TBCard(
                          padding: EdgeInsets.zero,
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            iconColor: AppColors.teal,
                            collapsedIconColor: AppColors.textLight,
                            title: Text(faq['question'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            children: [
                              Text(faq['answer'] ?? '',
                                  style: const TextStyle(
                                      color: AppColors.textMid,
                                      fontSize: 14,
                                      height: 1.6)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
