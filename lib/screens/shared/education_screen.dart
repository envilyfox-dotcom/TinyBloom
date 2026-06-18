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
    final a = await SupabaseService.getArticles();
    if (mounted) {
      setState(() {
        _articles = a;
        _loading = false;
      });
    }
  }

  List<String> get _categories {
    final cats = {
      'All',
      ..._articles.map((a) => a['category'] as String? ?? 'General')
    };
    return cats.toList();
  }

  List<Map<String, dynamic>> get _filtered => _articles.where((a) {
        final matchCat = _selectedCat == 'All' || a['category'] == _selectedCat;
        final matchSearch = _search.isEmpty ||
            (a['title'] as String? ?? '')
                .toLowerCase()
                .contains(_search.toLowerCase());
        return matchCat && matchSearch;
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Educational Content')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextFormField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search articles...',
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textLight),
                fillColor: AppColors.white,
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: _categories
                  .map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat),
                          selected: _selectedCat == cat,
                          onSelected: (_) => setState(() => _selectedCat = cat),
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
            child: _loading
                ? const TBLoading()
                : _filtered.isEmpty
                    ? const TBEmptyState(
                        emoji: '📚',
                        title: 'No articles found',
                        subtitle: 'Try a different search or category.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final article = _filtered[i];
                          final isLink = (article['url'] as String?)?.isNotEmpty == true;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TBCard(
                              onTap: () => openArticle(context, article),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                        color: AppColors.blush,
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Center(
                                        child: Text(isLink ? '🔗' : '📄',
                                            style: const TextStyle(fontSize: 28))),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(article['title'] ?? '',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        if (article['category'] != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: AppColors.tealLight,
                                                borderRadius:
                                                    BorderRadius.circular(50)),
                                            child: Text(article['category'],
                                                style: const TextStyle(
                                                    color: AppColors.teal,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ),
                                        if (article['excerpt'] != null) ...[
                                          const SizedBox(height: 4),
                                          Text(article['excerpt'],
                                              style: const TextStyle(
                                                  color: AppColors.textLight,
                                                  fontSize: 12),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis),
                                        ],
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
          ),
        ],
      ),
    );
  }
}
