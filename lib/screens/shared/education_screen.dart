import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'article_open_helper.dart';

void _openAuthorProfile(BuildContext context, Map<String, dynamic>? article) {
  final authorId = article?['created_by'] as String?;
  if (authorId == null) return;
  context.push('/specialist/profile-view', extra: authorId);
}

String _timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(date);
}

int _embeddedCount(Map<String, dynamic> row, String key) {
  final list = row[key] as List?;
  if (list == null || list.isEmpty) return 0;
  return (list.first as Map)['count'] as int? ?? 0;
}

// The image markdown syntax (Create Article's image button) at the very
// start of an article's body, if any — used to show a cropped photo preview
// on the card instead of an empty/awkward text snippet.
final _leadingImagePattern = RegExp(r'^!\[[^\]]*\]\(([^)]+)\)');
String? _leadingImageUrl(String content) {
  final match = _leadingImagePattern.firstMatch(content.trimLeft());
  return match?.group(1);
}

// Strips markdown formatting down to plain text for the card's body
// preview, since the full ArticleContent markdown renderer is only used on
// the detail screen.
String _plainTextPreview(String markdown) {
  var text = markdown;
  text = text.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '');
  text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m.group(1) ?? '');
  text = text.replaceAll(RegExp(r'\+\+|\*\*|__|[*_]'), '');
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

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

  // Report is UI-only for now (per product decision) — it collects a
  // category + reason like "Flag for emergency review" does for specialists,
  // but nothing is persisted or sent anywhere yet.
  Future<void> _showReportDialog(Map<String, dynamic> article) async {
    String category = 'clinical';
    final reasonCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Report post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                ChoiceChip(
                  label: const Text('Clinical'),
                  selected: category == 'clinical',
                  onSelected: (_) =>
                      setDialogState(() => category = 'clinical'),
                ),
                ChoiceChip(
                  label: const Text('Non-clinical'),
                  selected: category == 'non_clinical',
                  onSelected: (_) =>
                      setDialogState(() => category = 'non_clinical'),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Reason (required)'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Thanks — our team will take a look.')));
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
                          itemBuilder: (ctx, i) => _ArticleCard(
                            article: filtered[i],
                            onReport: () => _showReportDialog(filtered[i]),
                            onReturn: _load,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Article Card ──────────────────────────────────────────────────
// Styled after the specialist-authored feed mockup: author strip (photo,
// name, specialization, time), category pill, title, an expandable excerpt,
// and a like/comment footer — all in the app's existing rose/teal palette.
class _ArticleCard extends StatefulWidget {
  final Map<String, dynamic> article;
  final VoidCallback onReport;
  final VoidCallback onReturn;

  const _ArticleCard({
    required this.article,
    required this.onReport,
    required this.onReturn,
  });

  @override
  State<_ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<_ArticleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final category = article['category'] as String? ?? 'General';
    final isLink = (article['url'] as String?)?.isNotEmpty == true;
    final author = article['author'] as Map<String, dynamic>?;
    final authorName = author?['full_name'] as String? ?? 'TinyBloom Team';
    final specialization = (author?['specialist_profiles']
        as Map<String, dynamic>?)?['specialization'] as String?;
    final photoUrl = author?['profile_picture_url'] as String?;
    final createdAt = DateTime.tryParse(
        article['published_at'] as String? ??
            article['created_at'] as String? ??
            '');
    final excerpt = article['excerpt'] as String? ?? '';
    final content = article['content'] as String? ?? '';
    final leadingImageUrl = _leadingImageUrl(content);
    final previewText =
        excerpt.trim().isNotEmpty ? excerpt : _plainTextPreview(content);
    final canExpand = previewText.length > 110;
    final likeCount = _embeddedCount(article, 'article_likes');
    final commentCount = _embeddedCount(article, 'public_comments');

    return TBCard(
      onTap: () async {
        await openArticle(context, article);
        widget.onReturn();
      },
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _openAuthorProfile(context, article),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                          authorName.isNotEmpty
                              ? authorName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: AppColors.roseDeep,
                              fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(authorName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textDark)),
                    const SizedBox(height: 1),
                    Text(
                      [
                        if (specialization != null) specialization,
                        if (createdAt != null) _timeAgo(createdAt),
                      ].join(' • '),
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 11),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onReport,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.more_vert,
                      color: AppColors.textLight, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  category,
                  style: const TextStyle(
                      color: AppColors.teal,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
              if (isLink)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Text(
                    'Source',
                    style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            article['title'] as String? ?? 'Untitled article',
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.textDark,
                height: 1.25),
          ),
          if (leadingImageUrl != null) ...[
            const SizedBox(height: 8),
            _ContentImagePreview(url: leadingImageUrl),
          ] else if (previewText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              previewText,
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textMid, fontSize: 13, height: 1.4),
            ),
            if (canExpand)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _expanded ? 'Show less' : 'Show more',
                    style: const TextStyle(
                        color: AppColors.rose,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.favorite_border,
                  color: AppColors.textLight, size: 18),
              const SizedBox(width: 4),
              Text('$likeCount',
                  style: const TextStyle(
                      color: AppColors.textMid, fontSize: 12)),
              const SizedBox(width: 20),
              const Icon(Icons.chat_bubble_outline,
                  color: AppColors.textLight, size: 16),
              const SizedBox(width: 4),
              Text('$commentCount',
                  style: const TextStyle(
                      color: AppColors.textMid, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// Preview of an article whose body opens straight with an image (no leading
// text) — cropped to a fixed height with a fade-to-white at the bottom
// instead of stretching the full image or showing a blank card, since the
// full photo is still one tap away on the detail screen.
class _ContentImagePreview extends StatelessWidget {
  final String url;
  const _ContentImagePreview({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 120,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                color: AppColors.rose.withValues(alpha: 0.08),
                child: const Icon(Icons.broken_image_outlined,
                    color: AppColors.textLight),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 36,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.white.withValues(alpha: 0),
                      AppColors.white,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
