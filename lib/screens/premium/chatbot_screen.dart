import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/supabase_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

enum ChatSectionType { ask, symptoms, faq }

class ChatSectionData {
  final ChatSectionType type;
  final String title;
  final String subtitle;
  final String emoji;

  const ChatSectionData({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.emoji,
  });
}

class GuidedQuestion {
  final String question;
  final String category;
  final IconData icon;
  final Color color;

  const GuidedQuestion({
    required this.question,
    required this.category,
    required this.icon,
    required this.color,
  });
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  static const String _chatFunctionName = 'tinybloom-chat';

  ChatSectionType _selectedSection = ChatSectionType.ask;
  bool _typing = false;

  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'text':
          'Hi mummy 🌸 I am TinyBloom AI Assistant. Choose a section below or ask your own pregnancy question. I provide general pregnancy guidance only, not a medical diagnosis.',
    },
  ];

  static const _sections = [
    ChatSectionData(
      type: ChatSectionType.ask,
      title: 'Ask Questions',
      subtitle: 'General pregnancy guidance',
      emoji: '💬',
    ),
    ChatSectionData(
      type: ChatSectionType.symptoms,
      title: 'Symptoms',
      subtitle: 'Common signs and when to seek help',
      emoji: '🩺',
    ),
    ChatSectionData(
      type: ChatSectionType.faq,
      title: 'FAQ',
      subtitle: 'Quick answers for mums',
      emoji: '❓',
    ),
  ];

  static const _askQuestions = [
    GuidedQuestion(
      question: 'What foods should I eat during pregnancy?',
      category: 'Nutrition',
      icon: Icons.restaurant_outlined,
      color: AppColors.sage,
    ),
    GuidedQuestion(
      question: 'What foods should I avoid during pregnancy?',
      category: 'Food safety',
      icon: Icons.no_food_outlined,
      color: AppColors.rose,
    ),
    GuidedQuestion(
      question: 'Can I exercise while pregnant?',
      category: 'Lifestyle',
      icon: Icons.directions_walk_outlined,
      color: AppColors.teal,
    ),
    GuidedQuestion(
      question: 'How can I sleep better during pregnancy?',
      category: 'Rest',
      icon: Icons.nights_stay_outlined,
      color: AppColors.gold,
    ),
    GuidedQuestion(
      question: 'When should I feel baby movement?',
      category: 'Baby movement',
      icon: Icons.child_care_outlined,
      color: AppColors.roseDeep,
    ),
    GuidedQuestion(
      question: 'What happens during antenatal check-ups?',
      category: 'Antenatal care',
      icon: Icons.local_hospital_outlined,
      color: AppColors.teal,
    ),
  ];

  static const _symptomQuestions = [
    GuidedQuestion(
      question: 'I feel very tired. Is it normal?',
      category: 'Fatigue',
      icon: Icons.bedtime_outlined,
      color: AppColors.gold,
    ),
    GuidedQuestion(
      question: 'What can I do for morning sickness?',
      category: 'Nausea',
      icon: Icons.sick_outlined,
      color: AppColors.sage,
    ),
    GuidedQuestion(
      question: 'Is mild cramping normal?',
      category: 'Cramps',
      icon: Icons.healing_outlined,
      color: AppColors.teal,
    ),
    GuidedQuestion(
      question: 'When is bleeding serious?',
      category: 'Bleeding',
      icon: Icons.warning_amber_rounded,
      color: AppColors.rose,
    ),
    GuidedQuestion(
      question: 'What if I have severe headache or blurred vision?',
      category: 'Warning signs',
      icon: Icons.visibility_outlined,
      color: AppColors.roseDeep,
    ),
    GuidedQuestion(
      question: 'What should I do about reduced baby movement?',
      category: 'Urgent',
      icon: Icons.favorite_border,
      color: AppColors.rose,
    ),
  ];

  static const _faqQuestions = [
    GuidedQuestion(
      question: 'What happens in the first trimester?',
      category: 'Trimester',
      icon: Icons.looks_one_outlined,
      color: AppColors.teal,
    ),
    GuidedQuestion(
      question: 'Why is folic acid important?',
      category: 'Supplements',
      icon: Icons.medication_outlined,
      color: AppColors.sage,
    ),
    GuidedQuestion(
      question: 'What is gestational diabetes?',
      category: 'Conditions',
      icon: Icons.water_drop_outlined,
      color: AppColors.gold,
    ),
    GuidedQuestion(
      question: 'What vaccines are recommended during pregnancy?',
      category: 'Vaccination',
      icon: Icons.vaccines_outlined,
      color: AppColors.teal,
    ),
    GuidedQuestion(
      question: 'How often should I attend antenatal visits?',
      category: 'Check-ups',
      icon: Icons.event_available_outlined,
      color: AppColors.roseDeep,
    ),
    GuidedQuestion(
      question: 'When should I seek urgent medical help?',
      category: 'Emergency',
      icon: Icons.emergency_outlined,
      color: AppColors.rose,
    ),
  ];

  List<GuidedQuestion> get _currentQuestions {
    switch (_selectedSection) {
      case ChatSectionType.ask:
        return _askQuestions;
      case ChatSectionType.symptoms:
        return _symptomQuestions;
      case ChatSectionType.faq:
        return _faqQuestions;
    }
  }

  ChatSectionData get _currentSection {
    return _sections.firstWhere((section) => section.type == _selectedSection);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || _typing) return;

    setState(() {
      _messages.add({'role': 'user', 'text': cleanText});
      _typing = true;
    });

    _ctrl.clear();
    _scrollDown();

    final reply = await _callChatbotApi(cleanText);

    if (!mounted) return;
    setState(() {
      _messages.add({'role': 'ai', 'text': reply});
      _typing = false;
    });
    _scrollDown();
  }

  Future<void> _sendGuidedQuestion(GuidedQuestion item) async {
    if (_typing) return;

    setState(() {
      _messages.add({'role': 'user', 'text': item.question});
      _typing = true;
    });

    _scrollDown();

    final reply = await _callChatbotApi(
      item.question,
      guidedQuestion: item,
    );

    if (!mounted) return;
    setState(() {
      _messages.add({'role': 'ai', 'text': reply});
      _typing = false;
    });
    _scrollDown();
  }

  Future<String> _callChatbotApi(
    String question, {
    GuidedQuestion? guidedQuestion,
  }) async {
    final cleanQuestion = question.trim();

    if (cleanQuestion.isEmpty) {
      return _apiErrorMessage('Please type a question first.');
    }

    try {
      final response = await SupabaseService.client.functions.invoke(
        _chatFunctionName,
        body: {
          'question': cleanQuestion,
          'section': _currentSection.title,
          'sectionType': _selectedSection.name,
          'guidedQuestion': guidedQuestion == null
              ? null
              : {
                  'question': guidedQuestion.question,
                  'category': guidedQuestion.category,
                },
          'messages': _recentMessagesForApi(),
          'profile': await _profileContextForApi(),
          'pregnancyProfile': await _pregnancyContextForApi(),
        },
      );

      final apiError = _extractApiError(response.data);
      if (apiError != null) {
        debugPrint('Chatbot API returned error: $apiError');
        return _apiErrorMessage(apiError);
      }

      final reply = _extractReply(response.data);
      if (reply.trim().isEmpty) {
        return _apiErrorMessage(
          'The AI service replied with an empty response. Check the Edge Function logs.',
        );
      }

      return _ensureDisclaimer(reply.trim());
    } catch (e) {
      debugPrint('Chatbot API failed: $e');
      return _apiErrorMessage(
        'Cannot connect to AI service. Check Supabase Edge Function deployment, OPENAI_API_KEY secret, and function logs.\n\nError: $e',
      );
    }
  }

  List<Map<String, String>> _recentMessagesForApi() {
    final startIndex = _messages.length > 8 ? _messages.length - 8 : 0;

    return _messages.sublist(startIndex).map((message) {
      final role = message['role'] ?? '';
      final text = message['text'] ?? '';

      return {
        'role': role,
        'text': text,
      };
    }).where((message) {
      final role = message['role'] ?? '';
      final text = message['text'] ?? '';

      return role.isNotEmpty && text.isNotEmpty;
    }).toList();
  }

  Future<Map<String, dynamic>?> _profileContextForApi() async {
    try {
      final rawProfile = await SupabaseService.getProfile();

      if (rawProfile == null) {
        return null;
      }

      final profile = Map<String, dynamic>.from(rawProfile as Map);

      return {
        'role': profile['role'],
        'subscription_plan': profile['subscription_plan'],
      };
    } catch (e) {
      debugPrint('Chatbot API profile context skipped: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _pregnancyContextForApi() async {
    try {
      final rawPregnancyProfile = await SupabaseService.getPregnancyProfile();

      if (rawPregnancyProfile == null) {
        return null;
      }

      final pregnancyProfile =
          Map<String, dynamic>.from(rawPregnancyProfile as Map);

      return {
        'due_date': pregnancyProfile['due_date'],
        'current_week': pregnancyProfile['current_week'] ??
            pregnancyProfile['pregnancy_week'],
        'is_first_pregnancy': pregnancyProfile['is_first_pregnancy'],
        'pregnancy_status': pregnancyProfile['pregnancy_status'],
        'areas_of_interest': pregnancyProfile['areas_of_interest'],
        'consultation_needs': pregnancyProfile['consultation_needs'],
      };
    } catch (e) {
      debugPrint('Chatbot API pregnancy context skipped: $e');
      return null;
    }
  }

  String _extractReply(dynamic data) {
    if (data is Map) {
      return (data['reply'] ?? data['answer'] ?? data['message'] ?? '')
          .toString();
    }

    if (data is String) return data;

    return '';
  }

  String? _extractApiError(dynamic data) {
    if (data is! Map) return null;

    final error = data['error']?.toString().trim() ?? '';
    final status = data['status']?.toString().trim() ?? '';
    final code = data['code']?.toString().trim() ?? '';
    final details = (data['details'] ??
                data['detail'] ??
                data['body'] ??
                data['openai_error'])
            ?.toString()
            .trim() ??
        '';

    final hasError = error.isNotEmpty ||
        status.isNotEmpty ||
        code.isNotEmpty ||
        details.isNotEmpty;

    if (!hasError) return null;

    final parts = <String>[];

    if (status.isNotEmpty) {
      parts.add('AI service error (status $status)');
    } else {
      parts.add('AI service error');
    }

    if (error.isNotEmpty) {
      parts.add(error);
    }

    if (code.isNotEmpty) {
      parts.add('Code: $code');
    }

    if (details.isNotEmpty) {
      parts.add('Details: ${_compactApiDetails(details)}');
    }

    return parts.join('\n');
  }

  String _compactApiDetails(String details) {
    final cleaned = details.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.length <= 700) {
      return cleaned;
    }

    return '${cleaned.substring(0, 700)}...';
  }

  String _ensureDisclaimer(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('does not replace') ||
        lower.contains('not replace') ||
        lower.contains('medical advice')) {
      return text;
    }

    return '$text\n\n${_disclaimer()}';
  }

  String _apiErrorMessage(String detail) {
    return '$detail\n\nThe chatbot is API-only now. No hardcoded pregnancy answer was used.\n\n${_disclaimer()}';
  }

  String _disclaimer() {
    return 'TinyBloom provides general information only and does not replace advice from your doctor, midwife or hospital.';
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages
        ..clear()
        ..add({
          'role': 'ai',
          'text':
              'Chat cleared 🌸 Choose a section below or ask me a pregnancy question.',
        });
      _typing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'AI Assistant',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            onPressed: _clearChat,
            icon: const Icon(Icons.delete_outline, color: AppColors.textMid),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                _buildHeroCard(),
                const SizedBox(height: 16),
                _buildSectionSelector(),
                const SizedBox(height: 18),
                _buildGuidedQuestions(),
                const SizedBox(height: 18),
                const TBSectionTitle(title: 'Conversation'),
                const SizedBox(height: 12),
                for (final message in _messages)
                  _buildBubble(
                    message['role'] ?? '',
                    message['text'] ?? '',
                  ),
                if (_typing) _buildTyping(),
              ],
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return TBCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.blush,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('🌸', style: TextStyle(fontSize: 23)),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TinyBloom AI Assistant',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Get AI-generated pregnancy information for questions, symptoms and common FAQs.',
                  style: TextStyle(
                    color: AppColors.textMid,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TBSectionTitle(title: 'Choose a Section'),
        const SizedBox(height: 12),
        for (final section in _sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _sectionCard(section),
          ),
      ],
    );
  }

  Widget _sectionCard(ChatSectionData section) {
    final selected = _selectedSection == section.type;
    return GestureDetector(
      onTap: () => setState(() => _selectedSection = section.type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.rose
                : AppColors.textLight.withValues(alpha: 0.12),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.rose.withValues(alpha: 0.15)
                    : AppColors.tealLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child:
                    Text(section.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    section.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.check_circle : Icons.chevron_right,
              color: selected ? AppColors.rose : AppColors.textLight,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidedQuestions() {
    final questions = _currentQuestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Guided Questions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.blush,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _currentSection.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.roseDeep,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final item in questions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _questionCard(item),
          ),
      ],
    );
  }

  Widget _questionCard(GuidedQuestion item) {
    return GestureDetector(
      onTap: () => _sendGuidedQuestion(item),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: item.color.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.icon, color: item.color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.category,
                    style: TextStyle(
                      color: item.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.question,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: item.color, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _ctrl,
                textInputAction: TextInputAction.send,
                onFieldSubmitted: _send,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Ask anything about pregnancy...',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _send(_ctrl.text),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _typing ? AppColors.textLight : AppColors.teal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: AppColors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(String role, String text) {
    final isAI = role == 'ai';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isAI ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAI) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.blush,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🌸', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isAI ? AppColors.white : AppColors.teal,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isAI ? 4 : 16),
                  topRight: Radius.circular(isAI ? 16 : 4),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
                boxShadow: isAI
                    ? [
                        BoxShadow(
                          color: AppColors.textDark.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: isAI
                  ? MarkdownBody(
                      data: text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          color: AppColors.textMid,
                          fontSize: 14,
                          height: 1.55,
                        ),
                        strong: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w800,
                        ),
                        listBullet: const TextStyle(
                          color: AppColors.textMid,
                          fontSize: 14,
                          height: 1.5,
                        ),
                        h3: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : Text(
                      text,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTyping() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.blush,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('🌸', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(delay: 0),
              SizedBox(width: 4),
              _Dot(delay: 200),
              SizedBox(width: 4),
              _Dot(delay: 400),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;

  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: const CircleAvatar(radius: 4, backgroundColor: AppColors.teal),
    );
  }
}
