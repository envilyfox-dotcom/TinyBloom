import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/article_content.dart';

String _timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(date);
}

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
  final _commentFocusNode = FocusNode();
  // The comment being replied to — the fixed bottom bar doubles as the
  // reply box, with a "Replying to X" chip shown above it while set.
  Map<String, dynamic>? _replyingTo;

  String? get _articleId => widget.article['id'] as String?;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocusNode.dispose();
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
    // Replies to a reply flatten to the same top-level thread (one reply
    // depth in storage/UI, like Facebook) — the chip above the input still
    // names the specific person being replied to.
    final parentId =
        _replyingTo == null ? null : _topLevelParentId(_replyingTo!);
    _commentCtrl.clear();
    setState(() => _replyingTo = null);
    try {
      await SupabaseService.postPublicComment(id, body,
          parentCommentId: parentId);
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String _topLevelParentId(Map<String, dynamic> comment) =>
      (comment['parent_comment_id'] as String?) ?? comment['id'] as String;

  void _startReply(Map<String, dynamic> comment) {
    setState(() => _replyingTo = comment);
    FocusScope.of(context).requestFocus(_commentFocusNode);
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;

    final topLevel =
        _comments.where((c) => c['parent_comment_id'] == null).toList();
    final repliesByParent = <String, List<Map<String, dynamic>>>{};
    for (final c in _comments) {
      final parentId = c['parent_comment_id'] as String?;
      if (parentId != null) {
        repliesByParent.putIfAbsent(parentId, () => []).add(c);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(article['category'] ?? 'Article')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (article['category'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
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
                            color: AppColors.textMid,
                            fontSize: 15,
                            height: 1.7)),
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
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (_loadingComments)
                    const TBLoading()
                  else if (topLevel.isEmpty)
                    const Text(
                        'No comments yet. Be the first to share your thoughts.',
                        style:
                            TextStyle(color: AppColors.textLight, fontSize: 13))
                  else
                    ...topLevel.map((c) =>
                        _commentTile(c, repliesByParent[c['id']] ?? [])),
                ],
              ],
            ),
          ),
          if (_articleId != null) _commentInputBar(),
        ],
      ),
    );
  }

  Widget _commentTile(
      Map<String, dynamic> comment, List<Map<String, dynamic>> replies) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _commentRow(comment),
          for (final r in replies)
            Padding(
              padding: const EdgeInsets.only(left: 38, top: 10),
              child: _commentRow(r),
            ),
        ],
      ),
    );
  }

  Widget _commentRow(Map<String, dynamic> c) {
    final profile = c['profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] as String? ?? 'A mum';
    final photoUrl = profile?['profile_picture_url'] as String?;
    final createdAt = DateTime.tryParse(c['created_at'] as String? ?? '');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.rose.withValues(alpha: 0.15),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.roseDeep,
                      fontWeight: FontWeight.w700,
                      fontSize: 12))
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.textLight.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(createdAt != null ? _timeAgo(createdAt) : '',
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(c['body'] as String? ?? '',
                    style: const TextStyle(
                        color: AppColors.textMid, fontSize: 13)),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: GestureDetector(
                    onTap: () => _startReply(c),
                    child: const Text('Reply',
                        style: TextStyle(
                            color: AppColors.teal,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Fixed to the bottom of the screen (not the scroll content) so it's
  // always reachable; SafeArea(top: false) lifts it clear of the Android
  // gesture/nav bar.
  Widget _commentInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
              color: AppColors.textDark.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_replyingTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to ${(_replyingTo!['profiles']?['full_name'] as String?) ?? 'comment'}',
                        style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _replyingTo = null),
                      child: const Icon(Icons.close,
                          size: 16, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    focusNode: _commentFocusNode,
                    decoration: InputDecoration(
                      hintText: _replyingTo != null
                          ? 'Write a reply...'
                          : 'Add a comment...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.rose),
                  onPressed: _postComment,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
