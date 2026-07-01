import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── Link to Pregnant User (Next of Kin) ──────────────────────────────
// Lets a next-of-kin account send a link request to a mum by email.
// Sending a request isn't wired up yet (no request/approval table), but the
// "Currently Linked" section reads the real link from next_of_kin_profiles.
class LinkToMumScreen extends StatefulWidget {
  const LinkToMumScreen({super.key});
  @override
  State<LinkToMumScreen> createState() => _LinkToMumScreenState();
}

class _LinkToMumScreenState extends State<LinkToMumScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sending = false;
  bool _loadingLinked = true;
  Map<String, dynamic>? _linkedMum;

  @override
  void initState() {
    super.initState();
    _loadLinkedMum();
  }

  Future<void> _loadLinkedMum() async {
    final mum = await SupabaseService.getLinkedMum();
    if (mounted) setState(() { _linkedMum = mum; _loadingLinked = false; });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter an email address';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  Future<void> _sendRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _sending = false);
      _emailCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link request sent!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link to Pregnant User')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TBCard(
              color: AppColors.blush,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Connect Account',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text(
                      "Enter the email of the pregnant user to send a link request.",
                      style: TextStyle(color: AppColors.textMid, fontSize: 13)),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          labelText: 'Email address',
                          hintText: 'Enter email address'),
                      validator: _validateEmail,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TBButton(
                      label: 'Send Link Request',
                      loading: _sending,
                      onPressed: _sendRequest),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text('Currently Linked',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            if (_loadingLinked)
              const TBLoading()
            else if (_linkedMum == null)
              const TBEmptyState(
                  emoji: '🔗',
                  title: 'Not linked yet',
                  subtitle: 'Send a link request above to connect to a pregnant user.')
            else
              _buildLinkedMumCard(_linkedMum!),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedMumCard(Map<String, dynamic> mum) {
    final name = mum['full_name'] as String? ?? 'Unnamed';
    final week = mum['current_week'] as int?;
    final email = mum['email'] as String? ?? '';
    final initials = name
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    final subtitle = [
      if (week != null) 'Week $week',
      if (email.isNotEmpty) email,
    ].join(' · ');

    return TBCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.rose.withValues(alpha: 0.15),
            child: Text(initials,
                style: const TextStyle(
                    color: AppColors.roseDeep,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
