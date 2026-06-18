import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── AI Chatbot Screen ─────────────────────────────────────────────
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'text':
          'Hi! I\'m TinyBloom\'s AI assistant 🌸 I can help answer your pregnancy questions, provide symptom information, and give personalised tips. What would you like to know?'
    },
  ];
  bool _typing = false;

  final _suggestions = [
    'What foods should I avoid?',
    'Is it normal to feel tired?',
    'When should I feel baby move?',
    'Tips for better sleep',
  ];

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text.trim()});
      _typing = true;
    });
    _ctrl.clear();
    _scrollDown();

    // Simulated AI response (replace with actual API call)
    await Future.delayed(const Duration(seconds: 1));
    final response = _getResponse(text.toLowerCase());
    if (mounted) {
      setState(() {
        _messages.add({'role': 'ai', 'text': response});
        _typing = false;
      });
      _scrollDown();
    }
  }

  String _getResponse(String q) {
    if (q.contains('food') || q.contains('eat') || q.contains('avoid')) {
      return 'During pregnancy, avoid raw fish/sushi, unpasteurised cheeses, deli meats, high-mercury fish, and undercooked eggs. Focus on folate-rich foods, lean proteins, dairy, and plenty of fruits and vegetables. 🥗';
    }
    if (q.contains('tired') || q.contains('fatigue')) {
      return 'Fatigue is very common in pregnancy, especially in the first and third trimesters. Your body is working hard! Try to rest when you can, stay hydrated, eat iron-rich foods, and do light exercise. If fatigue is severe, consult your doctor. 💤';
    }
    if (q.contains('move') || q.contains('kick')) {
      return 'Most mums feel baby movements between 16-25 weeks. First-time mums may feel it later. By week 28, aim to notice at least 10 movements in 2 hours. If you\'re concerned about reduced movements, contact your midwife. 👶';
    }
    if (q.contains('sleep')) {
      return 'Sleep on your left side for better blood flow to baby. Use a pregnancy pillow for support. Avoid screens before bed, maintain a regular sleep schedule, and try a warm bath to relax. 🌙';
    }
    return 'That\'s a great question! For personalised advice about "${q.length > 30 ? '${q.substring(0, 30)}...' : q}", I recommend discussing with your healthcare provider who knows your specific situation. I\'m here to provide general guidance. Is there anything specific I can help with? 🌸';
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<AuthProvider>().isPremium;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🤖', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('AI Assistant'),
          ],
        ),
      ),
      body: !isPremium
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: PremiumGate(
                  feature: 'AI Assistant',
                  onUpgrade: () => context.push('/subscription')))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_typing ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _messages.length) {
                        return _buildTyping();
                      }
                      final m = _messages[i];
                      return _buildBubble(m['role']!, m['text']!);
                    },
                  ),
                ),
                // Suggestions
                if (_messages.length <= 2)
                  SizedBox(
                    height: 46,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      children: _suggestions
                          .map((s) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => _send(s),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.tealLight,
                                      borderRadius: BorderRadius.circular(50),
                                      border: Border.all(
                                          color:
                                              AppColors.teal.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(s,
                                        style: const TextStyle(
                                            color: AppColors.teal,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                // Input
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.textDark.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, -2))
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ctrl,
                          decoration: InputDecoration(
                            hintText: 'Ask anything about pregnancy...',
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
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
                              color: AppColors.teal, shape: BoxShape.circle),
                          child: const Icon(Icons.send,
                              color: AppColors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                  color: AppColors.blush, shape: BoxShape.circle),
              child: const Center(
                  child: Text('🌸', style: TextStyle(fontSize: 16))),
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
                            offset: const Offset(0, 2))
                      ]
                    : null,
              ),
              child: Text(text,
                  style: TextStyle(
                      color: isAI ? AppColors.textMid : AppColors.white,
                      fontSize: 14,
                      height: 1.5)),
            ),
          ),
          if (!isAI) const SizedBox(width: 8),
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
              color: AppColors.blush, shape: BoxShape.circle),
          child:
              const Center(child: Text('🌸', style: TextStyle(fontSize: 16))),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color: AppColors.white, borderRadius: BorderRadius.circular(16)),
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
        vsync: this, duration: const Duration(milliseconds: 600));
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
  Widget build(BuildContext context) => FadeTransition(
      opacity: _a,
      child: const CircleAvatar(radius: 4, backgroundColor: AppColors.teal));
}
