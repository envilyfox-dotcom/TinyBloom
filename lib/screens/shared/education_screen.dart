import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'article_open_helper.dart';

// ── Education Screen ──────────────────────────────────────────────
class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  List<Map<String, dynamic>> _articles = [];
  bool _loading = true;
  String _search = '';
  String _selectedCat = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await SupabaseService.getArticles();
      if (mounted) {
        setState(() {
          _articles = a;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _categories {
    final cats = {
      'All',
      ..._articles.map((a) => a['category'] as String? ?? 'General')
    }.toList();

    cats.sort((a, b) {
      if (a == 'All') return -1;
      if (b == 'All') return 1;
      return a.compareTo(b);
    });

    return cats;
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.toLowerCase().trim();

    return _articles.where((a) {
      final title = (a['title'] as String? ?? '').toLowerCase();
      final excerpt = (a['excerpt'] as String? ?? '').toLowerCase();
      final category = a['category'] as String? ?? 'General';

      final matchCat = _selectedCat == 'All' || category == _selectedCat;
      final matchSearch = q.isEmpty || title.contains(q) || excerpt.contains(q);

      return matchCat && matchSearch;
    }).toList();
  }

  String _categoryEmoji(String? category) {
    final c = (category ?? '').toLowerCase();

    if (c.contains('trimester')) return '🤰';
    if (c.contains('nutrition')) return '🥗';
    if (c.contains('exercise') || c.contains('lifestyle')) return '🚶';
    if (c.contains('condition') || c.contains('diabetes')) return '🩺';
    if (c.contains('mental')) return '🌿';
    if (c.contains('baby') || c.contains('development')) return '👶';
    if (c.contains('labour') || c.contains('delivery')) return '👜';
    if (c.contains('postpartum')) return '🍼';
    return '📚';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Education',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading
            ? const TBLoading()
            : RefreshIndicator(
                color: AppColors.rose,
                onRefresh: _load,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppColors.blush,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.rose.withValues(alpha: 0.18),
                                ),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Learn from trusted pregnancy resources',
                                    style: TextStyle(
                                      color: AppColors.roseDeep,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Browse articles on pregnancy care, symptoms, nutrition, baby development and wellbeing.',
                                    style: TextStyle(
                                      color: AppColors.textMid,
                                      fontSize: 13,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              onChanged: (v) => setState(() => _search = v),
                              decoration: InputDecoration(
                                hintText: 'Search pregnancy articles...',
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: AppColors.textLight,
                                ),
                                suffixIcon: _search.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.close,
                                            color: AppColors.textLight),
                                        onPressed: () =>
                                            setState(() => _search = ''),
                                      ),
                                fillColor: AppColors.white,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(50),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 44,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _categories.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final cat = _categories[index];
                                  final selected = _selectedCat == cat;

                                  return ChoiceChip(
                                    label: Text(cat),
                                    selected: selected,
                                    onSelected: (_) =>
                                        setState(() => _selectedCat = cat),
                                    selectedColor: AppColors.tealLight,
                                    backgroundColor: AppColors.white,
                                    side: BorderSide(
                                      color: selected
                                          ? AppColors.teal
                                          : AppColors.textLight
                                              .withValues(alpha: 0.25),
                                    ),
                                    labelStyle: TextStyle(
                                      color: selected
                                          ? AppColors.teal
                                          : AppColors.textMid,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                    checkmarkColor: AppColors.teal,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedCat == 'All'
                                        ? 'All Articles'
                                        : _selectedCat,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${filtered.length} found',
                                  style: const TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                    if (filtered.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: TBEmptyState(
                            emoji: '📚',
                            title: 'No articles found',
                            subtitle: 'Try a different search or category.',
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        sliver: SliverList.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _articleCard(filtered[i]),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _articleCard(Map<String, dynamic> article) {
    final category = article['category'] as String? ?? 'General';
    final isLink = (article['url'] as String?)?.isNotEmpty == true;

    return TBCard(
      onTap: () => openArticle(context, article),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.blush,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                isLink ? '🔗' : _categoryEmoji(category),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article['title'] as String? ?? 'Untitled article',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textDark,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tealLight,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: AppColors.teal,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isLink)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Text(
                          'Source',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                if (article['excerpt'] != null &&
                    article['excerpt'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    article['excerpt'],
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: AppColors.textLight, size: 18),
        ],
      ),
    );
  }
}
