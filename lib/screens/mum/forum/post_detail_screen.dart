import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import 'forum_shared.dart';

// Single forum post with its comment thread.
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
  Map<String, dynamic>? _replyingTo;

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
    final comments =
        await SupabaseService.getForumComments(widget.post['id'] as String);
    if (mounted) {
      setState(() {
        _comments = comments;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final parentId = _replyingTo?['parent_comment_id'] as String? ??
          _replyingTo?['id'] as String?;
      if (parentId == null) {
        await SupabaseService.createForumComment(widget.post['id'] as String, text);
      } else {
        await SupabaseService.createForumCommentReply(
            widget.post['id'] as String, text, parentId);
      }
      _commentCtrl.clear();
      setState(() => _replyingTo = null);
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await SupabaseService.deleteForumComment(id);
      await _load();
    }
  }

  Future<void> _editComment(Map<String, dynamic> comment) async {
    final ctrl = TextEditingController(text: comment['content'] as String? ?? '');
    final updated = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(controller: ctrl, autofocus: true, maxLines: 4),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (updated != null && updated.isNotEmpty) {
      await SupabaseService.updateForumComment(comment['id'] as String, updated);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final profile = post['profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] as String? ?? 'Member';
    final roleLabel = forumRoleSubtitle(profile);
    final content = post['content'] as String? ?? '';
    final createdAt = DateTime.tryParse(post['created_at'] as String? ?? '');
    final myId = SupabaseService.currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TBCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                forumAvatar(
                                  profile: profile,
                                  name: name,
                                  radius: 18,
                                  backgroundColor:
                                      AppColors.rose.withValues(alpha: 0.15),
                                  foregroundColor: AppColors.roseDeep,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                    if (roleLabel.isNotEmpty)
                                      Text(roleLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: AppColors.textLight,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                    Text(
                                        createdAt != null
                                            ? timeAgo(createdAt)
                                            : '',
                                        style: const TextStyle(
                                            color: AppColors.textLight,
                                            fontSize: 11)),
                                  ],
                                )),
                              ]),
                              const SizedBox(height: 12),
                              Text(content,
                                  style: const TextStyle(
                                      color: AppColors.textDark,
                                      fontSize: 15,
                                      height: 1.5)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Comments',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: _loading
                      ? const SliverToBoxAdapter(child: TBLoading())
                      : _comments.isEmpty
                          ? const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Text(
                                    'No comments yet. Be the first to reply!',
                                    style:
                                        TextStyle(color: AppColors.textLight)),
                              ),
                            )
                          : SliverList.builder(
                              itemCount: _comments
                                  .where((c) => c['parent_comment_id'] == null)
                                  .length,
                              itemBuilder: (context, i) {
                                final topLevel = _comments
                                    .where((c) => c['parent_comment_id'] == null)
                                    .toList();
                                final replies = _comments
                                    .where((c) => c['parent_comment_id'] == topLevel[i]['id'])
                                    .toList()
                                  ..sort((a, b) => (b['created_at'] as String)
                                      .compareTo(a['created_at'] as String));
                                return _commentTile(topLevel[i], replies, myId);
                              },
                            ),
                ),
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
                    blurRadius: 8,
                    offset: const Offset(0, -2))
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_replyingTo != null)
                  Row(children: [
                    Expanded(child: Text('Replying to ${_replyingTo!['profiles']?['full_name'] ?? 'comment'}',
                        style: const TextStyle(color: AppColors.textLight, fontSize: 12))),
                    IconButton(onPressed: () => setState(() => _replyingTo = null),
                        icon: const Icon(Icons.close, size: 16)),
                  ]),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _commentCtrl,
                    decoration: InputDecoration(
                        hintText: _replyingTo == null ? 'Add a comment...' : 'Write a reply...',
                        border: InputBorder.none),
                  )),
                  IconButton(
                    icon: _sending
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send, color: AppColors.rose),
                    onPressed: _sending ? null : _send,
                  ),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentTile(Map<String, dynamic> c,
      List<Map<String, dynamic>> replies, String? myId) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _commentRow(c, myId),
        for (final reply in replies)
          Padding(
              padding: const EdgeInsets.only(left: 38, top: 10),
              child: _commentRow(reply, myId)),
      ]),
    );
  }

  Widget _commentRow(Map<String, dynamic> c, String? myId) {
    final profile = c['profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] as String? ?? 'Member';
    final roleLabel = forumRoleLabel(profile?['role'] as String?);
    final createdAt = DateTime.tryParse(c['created_at'] as String? ?? '');
    final isMine = c['author_id'] == myId;
    return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          forumAvatar(
            profile: profile,
            name: name,
            radius: 14,
            backgroundColor: AppColors.tealLight,
            foregroundColor: AppColors.teal,
            fontSize: 11,
          ),
          const SizedBox(width: 10),
          Flexible(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.textLight.withValues(alpha: 0.3)),
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 6),
                if (roleLabel.isNotEmpty) ...[
                  Text(roleLabel,
                      style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  const Text('•',
                      style:
                          TextStyle(color: AppColors.textLight, fontSize: 11)),
                  const SizedBox(width: 6),
                ],
                Text(createdAt != null ? timeAgo(createdAt) : '',
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 11)),
              ]),
              const SizedBox(height: 2),
              Text(c['content'] as String? ?? '',
                  style:
                      const TextStyle(color: AppColors.textMid, fontSize: 13)),
              Padding(padding: const EdgeInsets.only(top: 4), child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(onTap: () => setState(() => _replyingTo = c),
                      child: const Text('Reply', style: TextStyle(color: AppColors.teal,
                          fontSize: 12, fontWeight: FontWeight.w700))),
                  if (isMine) ...[
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('•',
                        style: TextStyle(color: AppColors.textLight, fontSize: 12))),
                    GestureDetector(onTap: () => _editComment(c), child: const Text('Edit',
                        style: TextStyle(color: AppColors.teal, fontSize: 12, fontWeight: FontWeight.w700))),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('•',
                        style: TextStyle(color: AppColors.textLight, fontSize: 12))),
                    GestureDetector(onTap: () => _deleteComment(c['id'] as String), child: const Text('Delete',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w700))),
                  ],
                ],
              )),
            ],
          ))),
        ],
      );
  }
}
