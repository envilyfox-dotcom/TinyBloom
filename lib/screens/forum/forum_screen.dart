import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

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

// ── Forum (post list) ─────────────────────────────────────────────
class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});
  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  List<Map<String, dynamic>> _posts = [];
  Set<String> _likedIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await SupabaseService.getForumPosts();
      final ids = posts.map((p) => p['id'] as String).toList();
      final liked = await SupabaseService.getLikedPostIds(ids);
      if (mounted) {
        setState(() { _posts = posts; _likedIds = liked; _loading = false; _error = null; });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final id = post['id'] as String;
    final wasLiked = _likedIds.contains(id);
    // Optimistic update so the tap feels instant.
    setState(() {
      if (wasLiked) {
        _likedIds.remove(id);
      } else {
        _likedIds.add(id);
      }
      final current = _embeddedCount(post, 'forum_likes');
      post['forum_likes'] = [{'count': wasLiked ? (current - 1).clamp(0, 1 << 30) : current + 1}];
    });
    try {
      if (wasLiked) {
        await SupabaseService.unlikeForumPost(id);
      } else {
        await SupabaseService.likeForumPost(id);
      }
    } catch (_) {
      _load(); // out of sync with the server — just refetch the truth.
    }
  }

  void _showCreatePost() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Post', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: ctrl,
              maxLines: 5,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'Share something with the community...'),
            ),
            const SizedBox(height: 16),
            TBButton(
              label: 'Post',
              onPressed: () async {
                if (ctrl.text.trim().isEmpty) return;
                await SupabaseService.createForumPost(ctrl.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  _load();
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Post'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            )),
          ]),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseService.deleteForumPost(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = SupabaseService.currentUser?.id;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Forum')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePost,
        backgroundColor: AppColors.rose,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const TBLoading()
          : _error != null
              ? TBEmptyState(
                  emoji: '⚠️',
                  title: 'Couldn\'t load the forum',
                  subtitle: _error!,
                  buttonLabel: 'Retry',
                  onButton: () { setState(() => _loading = true); _load(); })
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.rose,
                  child: _posts.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 80),
                          TBEmptyState(
                              emoji: '💬',
                              title: 'No posts yet',
                              subtitle: 'Be the first to share something with the community.'),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                          itemCount: _posts.length,
                          itemBuilder: (ctx, i) => _postCard(_posts[i], myId),
                        ),
                ),
    );
  }

  Widget _postCard(Map<String, dynamic> post, String? myId) {
    final id = post['id'] as String;
    final profile = post['profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] as String? ?? 'Member';
    final content = post['content'] as String? ?? '';
    final createdAt = DateTime.tryParse(post['created_at'] as String? ?? '');
    final commentCount = _embeddedCount(post, 'forum_comments');
    final likeCount = _embeddedCount(post, 'forum_likes');
    final isLiked = _likedIds.contains(id);
    final isMine = post['author_id'] == myId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TBCard(
        onTap: () async {
          await context.push('/forum/post', extra: post);
          _load();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: AppColors.roseDeep, fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(createdAt != null ? _timeAgo(createdAt) : '',
                      style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                ],
              )),
              if (isMine)
                GestureDetector(
                  onTap: () => _delete(id),
                  child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                ),
            ]),
            const SizedBox(height: 10),
            Text(content,
                maxLines: 5, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textDark, fontSize: 14, height: 1.4)),
            const SizedBox(height: 10),
            Row(children: [
              GestureDetector(
                onTap: () => _toggleLike(post),
                child: Row(children: [
                  Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? AppColors.rose : AppColors.textLight, size: 18),
                  const SizedBox(width: 4),
                  Text('$likeCount', style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
                ]),
              ),
              const SizedBox(width: 20),
              const Icon(Icons.chat_bubble_outline, color: AppColors.textLight, size: 16),
              const SizedBox(width: 4),
              Text('$commentCount', style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Post Detail (comments) ────────────────────────────────────────
class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  const PostDetailScreen({super.key, required this.post});
  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final comments = await SupabaseService.getForumComments(widget.post['id'] as String);
    if (mounted) setState(() { _comments = comments; _loading = false; });
  }

  Future<void> _send() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await SupabaseService.createForumComment(widget.post['id'] as String, text);
      _commentCtrl.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _deleteComment(String id) async {
    await SupabaseService.deleteForumComment(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final profile = post['profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] as String? ?? 'Member';
    final content = post['content'] as String? ?? '';
    final createdAt = DateTime.tryParse(post['created_at'] as String? ?? '');
    final myId = SupabaseService.currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TBCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                    color: AppColors.roseDeep, fontWeight: FontWeight.w700))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            Text(createdAt != null ? _timeAgo(createdAt) : '',
                                style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                          ],
                        )),
                      ]),
                      const SizedBox(height: 12),
                      Text(content,
                          style: const TextStyle(color: AppColors.textDark, fontSize: 15, height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Comments', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 12),
                if (_loading)
                  const TBLoading()
                else if (_comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('No comments yet. Be the first to reply!',
                        style: TextStyle(color: AppColors.textLight)),
                  )
                else
                  ..._comments.map((c) => _commentTile(c, myId)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                    color: AppColors.textDark.withValues(alpha: 0.06),
                    blurRadius: 8, offset: const Offset(0, -2))
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(children: [
                Expanded(
                    child: TextFormField(
                  controller: _commentCtrl,
                  decoration: const InputDecoration(
                      hintText: 'Add a comment...', border: InputBorder.none),
                )),
                IconButton(
                  icon: _sending
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, color: AppColors.rose),
                  onPressed: _sending ? null : _send,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentTile(Map<String, dynamic> c, String? myId) {
    final profile = c['profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] as String? ?? 'Member';
    final createdAt = DateTime.tryParse(c['created_at'] as String? ?? '');
    final isMine = c['author_id'] == myId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.tealLight,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 11))),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 6),
                Text(createdAt != null ? _timeAgo(createdAt) : '',
                    style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
              ]),
              const SizedBox(height: 2),
              Text(c['content'] as String? ?? '',
                  style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
            ],
          )),
          if (isMine)
            GestureDetector(
              onTap: () => _deleteComment(c['id'] as String),
              child: const Icon(Icons.close, size: 16, color: AppColors.textLight),
            ),
        ],
      ),
    );
  }
}
