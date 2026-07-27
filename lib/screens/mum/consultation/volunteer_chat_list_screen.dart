import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/quick_chat_volunteer.dart';

// ── "View All" destination for the Quick Chat with Volunteer dashboard
// widget. Unlike ConsultationListScreen (which mixes specialist bookings
// with volunteer Q&A), this screen is volunteer-chat-only, and drops any
// chat that has already ended (closed/completed) — those are done, so
// they don't need to keep taking up space in the list.
class VolunteerChatListScreen extends StatefulWidget {
  const VolunteerChatListScreen({super.key});

  @override
  State<VolunteerChatListScreen> createState() =>
      _VolunteerChatListScreenState();
}

class _VolunteerChatListScreenState extends State<VolunteerChatListScreen> {
  List<Map<String, dynamic>> _questions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await SupabaseService.getMyVolunteerQuestions();
      // A chat with no activity in 48h is done — flip it to closed here
      // too, not just when someone happens to open its own thread screen.
      await SupabaseService.autoCloseStaleRequests(raw);
      final active = raw.where((q) => !quickChatIsEnded(q)).toList();
      final enriched = await enrichQuickChatQuestions(active);
      if (mounted) {
        setState(() {
          _questions = enriched;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text('Chat with Volunteer'),
      ),
      body: _loading
          ? const TBLoading()
          : _error != null
              ? TBEmptyState(
                  emoji: '⚠️',
                  title: "Couldn't load chats",
                  subtitle: _error!,
                  buttonLabel: 'Retry',
                  onButton: () {
                    setState(() => _loading = true);
                    _load();
                  },
                )
              : _questions.isEmpty
                  ? const TBEmptyState(
                      emoji: '🤝',
                      title: 'No active chats',
                      subtitle:
                          'Questions you post to a volunteer will show up here while the chat is ongoing.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _questions.length,
                        itemBuilder: (ctx, i) => QuickChatPreviewCard(
                          question: _questions[i],
                          onReload: _load,
                        ),
                      ),
                    ),
    );
  }
}
