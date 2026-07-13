import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';

// ── Post a Question to Volunteers ───────────────────────────────────
// An open Q&A board: the mum just writes her question, no volunteer
// selection or scheduling — any volunteer can see it and reply.
class PostVolunteerQuestionScreen extends StatefulWidget {
  const PostVolunteerQuestionScreen({super.key});

  @override
  State<PostVolunteerQuestionScreen> createState() =>
      _PostVolunteerQuestionScreenState();
}

class _PostVolunteerQuestionScreenState
    extends State<PostVolunteerQuestionScreen> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final question = _ctrl.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please write your question first.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.postVolunteerQuestion(question);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Your question has been posted to volunteers.')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
        title: const Text('Ask a Volunteer'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Post your question and any community volunteer will see it and reply.',
              style: TextStyle(color: AppColors.textMid, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            TBCard(
              child: TextField(
                controller: _ctrl,
                maxLines: 6,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText:
                      'e.g. How can I tell the difference between normal morning sickness and hyperemesis gravidarum?',
                  hintStyle: TextStyle(color: AppColors.textLight, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TBButton(
              label: 'Post Question',
              loading: _saving,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
