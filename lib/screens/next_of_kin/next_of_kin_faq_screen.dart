import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── FAQ (Next of Kin) ─────────────────────────────────────────────────
// Same data source and layout language as the shared FaqScreen, but scoped
// to the "Next of Kin" faqs category and with a search box instead of
// category chips, since there's only one category to show here.
class NextOfKinFaqScreen extends StatefulWidget {
  const NextOfKinFaqScreen({super.key});
  @override
  State<NextOfKinFaqScreen> createState() => _NextOfKinFaqScreenState();
}

class _NextOfKinFaqScreenState extends State<NextOfKinFaqScreen> {
  List<Map<String, dynamic>> _faqs = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final faqs = await SupabaseService.getFaqs(category: 'Next of Kin');
    if (mounted) setState(() { _faqs = faqs; _loading = false; });
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _faqs;
    return _faqs.where((f) {
      final question = (f['question'] as String? ?? '').toLowerCase();
      final answer = (f['answer'] as String? ?? '').toLowerCase();
      return question.contains(q) || answer.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: _loading
          ? const TBLoading()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, color: AppColors.textLight),
                        hintText: 'Search questions'),
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? const TBEmptyState(
                          emoji: '❓',
                          title: 'No results',
                          subtitle: 'Try a different search term.')
                      : ListView.builder(
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
                                  iconColor: AppColors.rose,
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
