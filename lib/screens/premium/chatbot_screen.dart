import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

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
  final String answer;
  final String category;
  final IconData icon;
  final Color color;

  const GuidedQuestion({
    required this.question,
    required this.answer,
    required this.category,
    required this.icon,
    required this.color,
  });
}

// ── AI Chatbot Screen ─────────────────────────────────────────────
// Organised into 3 user-friendly sections:
// 1. Ask Questions
// 2. Symptoms Information
// 3. FAQ
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

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
      answer:
          'A balanced pregnancy diet should include wholegrains, lean protein, dairy or calcium-rich alternatives, fruits, vegetables and enough water. Include folate, iron and calcium-rich foods where possible. If you have gestational diabetes or other conditions, follow your doctor or dietitian’s advice.',
    ),
    GuidedQuestion(
      question: 'What foods should I avoid during pregnancy?',
      category: 'Food safety',
      icon: Icons.no_food_outlined,
      color: AppColors.rose,
      answer:
          'It is safer to avoid raw or undercooked meat, raw fish, raw eggs, unpasteurised dairy, alcohol, and fish high in mercury. Choose freshly cooked food and practise good food hygiene to lower the risk of food poisoning.',
    ),
    GuidedQuestion(
      question: 'Can I exercise while pregnant?',
      category: 'Lifestyle',
      icon: Icons.directions_walk_outlined,
      color: AppColors.teal,
      answer:
          'Many pregnant mums can do light to moderate activities such as walking, stretching or swimming if their doctor says it is safe. Stop and seek advice if you feel pain, dizziness, bleeding, contractions, chest pain or severe breathlessness.',
    ),
    GuidedQuestion(
      question: 'How can I sleep better during pregnancy?',
      category: 'Rest',
      icon: Icons.nights_stay_outlined,
      color: AppColors.gold,
      answer:
          'Try sleeping on your side, using pillows for support, keeping a regular sleep routine, reducing screens before bed and avoiding heavy meals close to bedtime. If sleep problems are severe or linked to pain, breathlessness or anxiety, speak to your doctor.',
    ),
    GuidedQuestion(
      question: 'When should I feel baby movement?',
      category: 'Baby movement',
      icon: Icons.child_care_outlined,
      color: AppColors.roseDeep,
      answer:
          'Many mums feel baby movements between 16 and 25 weeks, but first-time mums may notice them later. If movements become reduced, weaker, or very different from usual, seek medical advice immediately. Do not wait until the next day.',
    ),
    GuidedQuestion(
      question: 'What happens during antenatal check-ups?',
      category: 'Antenatal care',
      icon: Icons.local_hospital_outlined,
      color: AppColors.teal,
      answer:
          'Antenatal visits may include weight, blood pressure, urine checks, blood tests, scans, baby growth checks and baby heartbeat checks in later weeks. These visits help monitor mother and baby and allow symptoms to be raised early.',
    ),
  ];

  static const _symptomQuestions = [
    GuidedQuestion(
      question: 'I feel very tired. Is it normal?',
      category: 'Fatigue',
      icon: Icons.bedtime_outlined,
      color: AppColors.gold,
      answer:
          'Tiredness is common, especially in the first and third trimester. Rest when possible, drink enough water, eat regular meals and include iron-rich foods. Seek medical advice if tiredness is extreme or comes with dizziness, breathlessness, fainting or paleness.',
    ),
    GuidedQuestion(
      question: 'What can I do for morning sickness?',
      category: 'Nausea',
      icon: Icons.sick_outlined,
      color: AppColors.sage,
      answer:
          'Morning sickness is common in early pregnancy. Small frequent meals, plain crackers, fluids and avoiding strong smells may help. Seek medical help if you cannot keep food or fluids down, feel dehydrated or lose weight.',
    ),
    GuidedQuestion(
      question: 'Is mild cramping normal?',
      category: 'Cramps',
      icon: Icons.healing_outlined,
      color: AppColors.teal,
      answer:
          'Mild cramps can happen as the uterus grows, but severe pain, one-sided pain, pain with bleeding, fever, shoulder tip pain or dizziness should be checked urgently.',
    ),
    GuidedQuestion(
      question: 'When is bleeding serious?',
      category: 'Bleeding',
      icon: Icons.warning_amber_rounded,
      color: AppColors.rose,
      answer:
          'Bleeding during pregnancy should be taken seriously. Contact your doctor or seek urgent care, especially if bleeding is heavy, bright red, painful, or comes with cramps, dizziness or fainting.',
    ),
    GuidedQuestion(
      question: 'What if I have severe headache or blurred vision?',
      category: 'Warning signs',
      icon: Icons.visibility_outlined,
      color: AppColors.roseDeep,
      answer:
          'Severe headache, blurred vision, swelling of face or hands, chest pain or upper abdominal pain can be warning signs. Please seek medical help urgently.',
    ),
    GuidedQuestion(
      question: 'What should I do about reduced baby movement?',
      category: 'Urgent',
      icon: Icons.favorite_border,
      color: AppColors.rose,
      answer:
          'If your baby’s movements are reduced, weaker, or different from usual, seek medical advice immediately. Do not wait to see if it improves tomorrow.',
    ),
  ];

  static const _faqQuestions = [
    GuidedQuestion(
      question: 'What happens in the first trimester?',
      category: 'Trimester',
      icon: Icons.looks_one_outlined,
      color: AppColors.teal,
      answer:
          'The first trimester is week 1 to week 12. Common changes include missed period, nausea, tiredness, breast tenderness and mood changes. Early baby development happens quickly, so folic acid, healthy eating and antenatal care are important.',
    ),
    GuidedQuestion(
      question: 'Why is folic acid important?',
      category: 'Supplements',
      icon: Icons.medication_outlined,
      color: AppColors.sage,
      answer:
          'Folic acid supports early development of the baby’s nervous system. It is commonly recommended before pregnancy and during the first 12 weeks. Ask your doctor or pharmacist about the correct dose for you.',
    ),
    GuidedQuestion(
      question: 'What is gestational diabetes?',
      category: 'Conditions',
      icon: Icons.water_drop_outlined,
      color: AppColors.gold,
      answer:
          'Gestational diabetes is diabetes that develops during pregnancy. It may not cause obvious symptoms, so screening is important. Healthy eating, glucose monitoring and medical advice help reduce risks for mother and baby.',
    ),
    GuidedQuestion(
      question: 'What vaccines are recommended during pregnancy?',
      category: 'Vaccination',
      icon: Icons.vaccines_outlined,
      color: AppColors.teal,
      answer:
          'Some vaccines, such as flu and whooping cough vaccination, may be recommended during pregnancy depending on your situation. Always confirm with your doctor before taking any vaccine.',
    ),
    GuidedQuestion(
      question: 'How often should I attend antenatal visits?',
      category: 'Check-ups',
      icon: Icons.event_available_outlined,
      color: AppColors.roseDeep,
      answer:
          'The schedule depends on your pregnancy stage and risk factors. Regular antenatal visits allow healthcare providers to monitor your health, baby growth and any symptoms. Follow the schedule given by your clinic or hospital.',
    ),
    GuidedQuestion(
      question: 'When should I seek urgent medical help?',
      category: 'Emergency',
      icon: Icons.emergency_outlined,
      color: AppColors.rose,
      answer:
          'Seek urgent medical help for heavy bleeding, severe abdominal pain, severe headache, vision changes, fever, chest pain, fainting, reduced baby movement, or fluid leaking from the vagina.',
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
    return _sections.firstWhere((s) => s.type == _selectedSection);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': cleanText});
      _typing = true;
    });

    _ctrl.clear();
    _scrollDown();

    await Future.delayed(const Duration(milliseconds: 550));

    if (!mounted) return;
    setState(() {
      _messages.add({'role': 'ai', 'text': _getResponse(cleanText)});
      _typing = false;
    });
    _scrollDown();
  }

  Future<void> _sendGuidedQuestion(GuidedQuestion item) async {
    setState(() {
      _messages.add({'role': 'user', 'text': item.question});
      _typing = true;
    });

    _scrollDown();
    await Future.delayed(const Duration(milliseconds: 450));

    if (!mounted) return;
    setState(() {
      _messages
          .add({'role': 'ai', 'text': '${item.answer}\n\n${_disclaimer()}'});
      _typing = false;
    });
    _scrollDown();
  }

  String _getResponse(String question) {
    final q = question.toLowerCase();

    for (final item in [
      ..._askQuestions,
      ..._symptomQuestions,
      ..._faqQuestions
    ]) {
      final keywords = item.question
          .toLowerCase()
          .replaceAll('?', '')
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 3);

      if (keywords.any((word) => q.contains(word))) {
        return '${item.answer}\n\n${_disclaimer()}';
      }
    }

    if (_containsAny(q, ['bleed', 'bleeding', 'spotting'])) {
      return '${_symptomQuestions[3].answer}\n\n${_disclaimer()}';
    }
    if (_containsAny(q, ['headache', 'vision', 'blur', 'swelling'])) {
      return '${_symptomQuestions[4].answer}\n\n${_disclaimer()}';
    }
    if (_containsAny(q, ['kick', 'movement', 'reduced'])) {
      return '${_symptomQuestions[5].answer}\n\n${_disclaimer()}';
    }
    if (_containsAny(q, ['vomit', 'nausea', 'morning sickness'])) {
      return '${_symptomQuestions[1].answer}\n\n${_disclaimer()}';
    }
    if (_containsAny(q, ['food', 'eat', 'nutrition', 'avoid'])) {
      return q.contains('avoid')
          ? '${_askQuestions[1].answer}\n\n${_disclaimer()}'
          : '${_askQuestions[0].answer}\n\n${_disclaimer()}';
    }
    if (_containsAny(q, ['exercise', 'walk', 'active', 'workout'])) {
      return '${_askQuestions[2].answer}\n\n${_disclaimer()}';
    }
    if (_containsAny(q, ['urgent', 'emergency', 'doctor', 'hospital'])) {
      return '${_urgentAdvice()}\n\n${_disclaimer()}';
    }

    return 'That is a good question 🌸 I can provide general pregnancy information. For more specific guidance, try one of the guided questions under Ask Questions, Symptoms, or FAQ.\n\n${_disclaimer()}';
  }

  bool _containsAny(String text, List<String> words) {
    return words.any((word) => text.contains(word));
  }

  String _urgentAdvice() {
    return 'Please seek medical help urgently if you have heavy bleeding, severe abdominal pain, severe headache, vision changes, fever, chest pain, fainting, reduced baby movement, or fluid leaking from the vagina.';
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
          onPressed: () => context.pop(),
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
                for (final m in _messages) _buildBubble(m['role']!, m['text']!),
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
            child:
                const Center(child: Text('🌸', style: TextStyle(fontSize: 23))),
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
                  'Get guided pregnancy information for questions, symptoms and common FAQs.',
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
                decoration: const BoxDecoration(
                  color: AppColors.teal,
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
              child: Text(
                text,
                style: TextStyle(
                  color: isAI ? AppColors.textMid : AppColors.white,
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
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _a = Tween<double>(begin: 0.3, end: 1.0).animate(_c);

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: const CircleAvatar(radius: 4, backgroundColor: AppColors.teal),
    );
  }
}
