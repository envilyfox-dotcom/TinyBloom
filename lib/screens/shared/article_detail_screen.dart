import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/article_content.dart';

// ── Article Detail ────────────────────────────────────────────────
class ArticleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> article;
  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  List<Map<String, dynamic>> _comments = [];
  bool _loadingComments = true;
  final _commentCtrl = TextEditingController();

  String? get _articleId => widget.article['id'] as String?;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final id = _articleId;
    if (id == null) {
      setState(() => _loadingComments = false);
      return;
    }
    try {
      final comments = await SupabaseService.getPublicComments(id);
      if (mounted) setState(() { _comments = comments; _loadingComments = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _postComment() async {
    final id = _articleId;
    final body = _commentCtrl.text.trim();
    if (id == null || body.isEmpty) return;
    _commentCtrl.clear();
    try {
      await SupabaseService.postPublicComment(id, body);
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    return Scaffold(
      appBar: AppBar(title: Text(article['category'] ?? 'Article')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article['category'] != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(50)),
                child: Text(article['category'],
                    style: const TextStyle(
                        color: AppColors.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 12),
            Text(article['title'] ?? '',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 22)),
            const SizedBox(height: 16),
            if ((article['url'] as String?)?.isNotEmpty == true) ...[
              if (article['excerpt'] != null) ...[
                Text(article['excerpt'],
                    style: const TextStyle(
                        color: AppColors.textMid, fontSize: 15, height: 1.7)),
                const SizedBox(height: 20),
              ],
              TBButton(
                label: 'Open Article',
                icon: Icons.open_in_new,
                onPressed: () => launchUrl(Uri.parse(article['url']),
                    mode: LaunchMode.externalApplication),
              ),
            ] else
              ArticleContent(
                  data: article['content'] ??
                      article['excerpt'] ??
                      'No content available.'),
            if (_articleId != null) ...[
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 12),
              const Text('Comments',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              if (_loadingComments)
                const TBLoading()
              else if (_comments.isEmpty)
                const Text('No comments yet. Be the first to share your thoughts.',
                    style: TextStyle(color: AppColors.textLight, fontSize: 13))
              else
                ..._comments.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (c['profiles']?['full_name'] as String?) ?? 'A mum',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(c['body'] as String? ?? '',
                              style: const TextStyle(
                                  color: AppColors.textMid, fontSize: 13)),
                        ],
                      ),
                    )),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      decoration: const InputDecoration(
                          hintText: 'Add a comment...'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.rose),
                    onPressed: _postComment,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
