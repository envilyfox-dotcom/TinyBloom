import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── Link to Pregnant User (Next of Kin) ──────────────────────────────
// Lets a next-of-kin account link straight to a mum by her user code — no
// email verification or mum-side approval yet, linking is immediate.
class LinkToMumScreen extends StatefulWidget {
  const LinkToMumScreen({super.key});
  @override
  State<LinkToMumScreen> createState() => _LinkToMumScreenState();
}

class _LinkToMumScreenState extends State<LinkToMumScreen> {
  static const _relationshipOptions = [
    'Husband / Partner', 'Mother', 'Father', 'Sister', 'Brother', 'Friend', 'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _userCodeCtrl = TextEditingController();
  String? _relationship;
  bool _sending = false;
  bool _loadingLinked = true;
  Map<String, dynamic>? _linkedMum;

  bool _verifying = false;
  String? _verifiedMumName;
  String? _verifyError;

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
    _userCodeCtrl.dispose();
    super.dispose();
  }

  String? _validateUserCode(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter a user code';
    return null;
  }

  // Clears any previous verification result whenever the code is edited, so
  // the Link button can't stay enabled for a code that's since changed.
  void _onUserCodeEdited(String _) {
    if (_verifiedMumName != null || _verifyError != null) {
      setState(() { _verifiedMumName = null; _verifyError = null; });
    }
  }

  Future<void> _verify() async {
    final code = _userCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _verifiedMumName = null;
        _verifyError = 'Please enter a user code';
      });
      return;
    }
    setState(() { _verifying = true; _verifiedMumName = null; _verifyError = null; });
    try {
      final mum = await SupabaseService.verifyMumUserCode(code);
      if (mounted) {
        setState(() => _verifiedMumName = mum['full_name'] as String? ?? 'Mum');
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _verifyError = e.toString().replaceFirst('Exception: ', ''));
      }
    }
    if (mounted) setState(() => _verifying = false);
  }

  Future<void> _link() async {
    if (!_formKey.currentState!.validate() || _verifiedMumName == null) return;
    setState(() => _sending = true);
    try {
      final mumName = await SupabaseService.linkToMum(
          _userCodeCtrl.text.trim().toUpperCase(), _relationship!);
      _userCodeCtrl.clear();
      setState(() { _relationship = null; _verifiedMumName = null; });
      await _loadLinkedMum();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Linked to $mumName!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _sending = false);
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
                      "Enter the user code of the pregnant user to link to her.",
                      style: TextStyle(color: AppColors.textMid, fontSize: 13)),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _userCodeCtrl,
                                textCapitalization: TextCapitalization.characters,
                                decoration: const InputDecoration(
                                    labelText: 'User code',
                                    hintText: "Enter the mum's user code"),
                                validator: _validateUserCode,
                                onChanged: _onUserCodeEdited,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 56,
                              child: OutlinedButton(
                                onPressed: _verifying ? null : _verify,
                                child: _verifying
                                    ? const SizedBox(
                                        width: 16, height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Verify'),
                              ),
                            ),
                          ],
                        ),
                        if (_verifiedMumName != null || _verifyError != null) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _verifiedMumName != null
                                ? Text('✓ Linked to: $_verifiedMumName',
                                    style: const TextStyle(
                                        color: AppColors.sage,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))
                                : Text('✗ $_verifyError',
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                          ),
                        ],
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _relationship,
                          decoration: const InputDecoration(
                              labelText: 'Relationship to Expectant Mother'),
                          hint: const Text('Select relationship'),
                          items: _relationshipOptions
                              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (v) => setState(() => _relationship = v),
                          validator: (v) =>
                              v == null ? 'Please select a relationship' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TBButton(
                      label: 'Link',
                      loading: _sending,
                      onPressed: _verifiedMumName == null ? null : _link),
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
                  subtitle: 'Enter a user code above to link to a pregnant user.')
            else
              _buildLinkedMumCard(_linkedMum!),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedMumCard(Map<String, dynamic> mum) {
    final name = mum['full_name'] as String? ?? 'Unnamed';
    final relationship = mum['relationship'] as String?;
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
                if (relationship != null) ...[
                  const SizedBox(height: 2),
                  Text(relationship,
                      style: const TextStyle(
                          color: AppColors.textMid, fontSize: 12)),
                ],
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
