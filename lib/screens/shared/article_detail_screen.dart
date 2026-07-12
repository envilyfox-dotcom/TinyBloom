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

int _embeddedCount(Map<String, dynamic> row, String key) {
  final list = row[key] as List?;
  if (list == null || list.isEmpty) return 0;
  return (list.first as Map)['count'] as int? ?? 0;
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
  bool _isLiked = false;
  late int _likeCount;

  String? get _articleId => widget.article['id'] as String?;

  @override
  void initState() {
    super.initState();
    _likeCount = _embeddedCount(widget.article, 'article_likes');
    _loadComments();
    _loadLikeStatus();
  }

  Future<void> _loadLikeStatus() async {
    final id = _articleId;
    if (id == null) return;
    try {
      final liked = await SupabaseService.getLikedArticleIds([id]);
      if (mounted) setState(() => _isLiked = liked.contains(id));
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    final id = _articleId;
    if (id == null) return;
    final wasLiked = _isLiked;
    // Optimistic update so the tap feels instant.
    setState(() {
      _isLiked = !wasLiked;
      _likeCount = (_likeCount + (wasLiked ? -1 : 1)).clamp(0, 1 << 30);
    });
    try {
      if (wasLiked) {
        await SupabaseService.unlikeArticle(id);
      } else {
        await SupabaseService.likeArticle(id);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount = (_likeCount + (wasLiked ? 1 : -1)).clamp(0, 1 << 30);
        });
      }
    }
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

  Future<void> _deleteComment(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(
                child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            )),
          ]),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService.deletePublicComment(id);
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final author = article['author'] as Map<String, dynamic>?;
    final authorName = author?['full_name'] as String? ?? 'TinyBloom Team';
    final authorPhoto = author?['profile_picture_url'] as String?;
    final authorSpecialization = (author?['specialist_profiles']
        as Map<String, dynamic>?)?['specialization'] as String?;
    final createdAt = DateTime.tryParse(
        article['published_at'] as String? ??
            article['created_at'] as String? ??
            '');

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
      appBar: AppBar(title: const Text('Educational Post')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(22),
                    border:
                        Border.all(color: AppColors.rose.withValues(alpha: 0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                AppColors.rose.withValues(alpha: 0.15),
                            backgroundImage: authorPhoto != null
                                ? NetworkImage(authorPhoto)
                                : null,
                            child: authorPhoto == null
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
                                Text(
                                  [
                                    if (authorSpecialization != null)
                                      authorSpecialization,
                                    if (createdAt != null) _timeAgo(createdAt),
                                  ].join(' • '),
                                  style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (article['category'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
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
                        ),
                      Text(article['title'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 18)),
                      const SizedBox(height: 14),
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
                                'No content available.',
                            style: const TextStyle(
                                color: AppColors.textMid,
                                fontSize: 14,
                                height: 1.5)),
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _toggleLike,
                            child: Row(
                              children: [
                                Icon(
                                    _isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: _isLiked
                                        ? AppColors.rose
                                        : AppColors.textLight,
                                    size: 20),
                                const SizedBox(width: 4),
                                Text('$_likeCount',
                                    style: const TextStyle(
                                        color: AppColors.textMid,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          const Icon(Icons.chat_bubble_outline,
                              color: AppColors.textLight, size: 18),
                          const SizedBox(width: 4),
                          Text(
                              '${_loadingComments ? _embeddedCount(article, 'public_comments') : _comments.length}',
                              style: const TextStyle(
                                  color: AppColors.textMid, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_articleId != null) ...[
                  const SizedBox(height: 20),
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
    final isMine = c['user_id'] == SupabaseService.currentUser?.id;

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
        Flexible(
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _startReply(c),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Text('Reply',
                              style: TextStyle(
                                  color: AppColors.teal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      if (isMine) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('•',
                              style: TextStyle(
                                  color: AppColors.textLight, fontSize: 12)),
                        ),
                        GestureDetector(
                          onTap: () =>
                              _deleteComment(c['id'] as String),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Text('Delete',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ],
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
