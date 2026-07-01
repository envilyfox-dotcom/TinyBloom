import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import 'forum_shared.dart';

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
    final comments =
        await SupabaseService.getForumComments(widget.post['id'] as String);
    if (mounted)
      setState(() {
        _comments = comments;
        _loading = false;
      });
  }

  Future<void> _send() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await SupabaseService.createForumComment(
          widget.post['id'] as String, text);
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
                            backgroundColor:
                                AppColors.rose.withValues(alpha: 0.15),
                            child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
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
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
                    blurRadius: 8,
                    offset: const Offset(0, -2))
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
                          width: 20,
                          height: 20,
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
                      color: AppColors.teal,
                      fontWeight: FontWeight.w700,
                      fontSize: 11))),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 6),
                Text(createdAt != null ? timeAgo(createdAt) : '',
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 11)),
              ]),
              const SizedBox(height: 2),
              Text(c['content'] as String? ?? '',
                  style:
                      const TextStyle(color: AppColors.textMid, fontSize: 13)),
            ],
          )),
          if (isMine)
            GestureDetector(
              onTap: () => _deleteComment(c['id'] as String),
              child:
                  const Icon(Icons.close, size: 16, color: AppColors.textLight),
            ),
        ],
      ),
    );
  }
}
