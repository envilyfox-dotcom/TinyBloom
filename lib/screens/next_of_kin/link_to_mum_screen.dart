import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── Link to Pregnant User (Next of Kin) ──────────────────────────────
// Lets a next-of-kin account send a link request to a mum by email.
// Backend linking (a request table + mum-side approval) isn't built yet,
// so this only validates input and shows placeholder state for now.
class LinkToMumScreen extends StatefulWidget {
  const LinkToMumScreen({super.key});
  @override
  State<LinkToMumScreen> createState() => _LinkToMumScreenState();
}

class _LinkToMumScreenState extends State<LinkToMumScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sending = false;

  // Placeholder until the mum <-> next-of-kin link table exists — swap for
  // a real fetch of the linked mum's profile once that's built.
  static const _linkedMum = {
    'name': 'Sarah K',
    'week': 24,
    'email': 'sarahk@gmail.com',
  };

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
            TBCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                    child: Text(
                        (_linkedMum['name'] as String)
                            .split(' ')
                            .map((w) => w.isNotEmpty ? w[0] : '')
                            .take(2)
                            .join()
                            .toUpperCase(),
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
                        Text(_linkedMum['name'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                            'Week ${_linkedMum['week']} · ${_linkedMum['email']}',
                            style: const TextStyle(
                                color: AppColors.textLight, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
