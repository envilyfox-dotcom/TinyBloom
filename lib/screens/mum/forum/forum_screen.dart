import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import 'forum_shared.dart';

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
        setState(() {
          _posts = posts;
          _likedIds = liked;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
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
      post['forum_likes'] = [
        {'count': wasLiked ? (current - 1).clamp(0, 1 << 30) : current + 1}
      ];
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
            left: 20,
            right: 20,
            top: 20),
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
            Expanded(
                child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Post'),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: ElevatedButton(
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
                  onButton: () {
                    setState(() => _loading = true);
                    _load();
                  })
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.rose,
                  child: _posts.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 80),
                          TBEmptyState(
                              emoji: '💬',
                              title: 'No posts yet',
                              subtitle:
                                  'Be the first to share something with the community.'),
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
                          color: AppColors.roseDeep,
                          fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(createdAt != null ? timeAgo(createdAt) : '',
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 11)),
                ],
              )),
              if (isMine)
                GestureDetector(
                  onTap: () => _delete(id),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                ),
            ]),
            const SizedBox(height: 10),
            Text(content,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textDark, fontSize: 14, height: 1.4)),
            const SizedBox(height: 10),
            Row(children: [
              GestureDetector(
                onTap: () => _toggleLike(post),
                child: Row(children: [
                  Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? AppColors.rose : AppColors.textLight,
                      size: 18),
                  const SizedBox(width: 4),
                  Text('$likeCount',
                      style: const TextStyle(
                          color: AppColors.textMid, fontSize: 12)),
                ]),
              ),
              const SizedBox(width: 20),
              const Icon(Icons.chat_bubble_outline,
                  color: AppColors.textLight, size: 16),
              const SizedBox(width: 4),
              Text('$commentCount',
                  style:
                      const TextStyle(color: AppColors.textMid, fontSize: 12)),
            ]),
          ],
        ),
      ),
    );
  }
}
