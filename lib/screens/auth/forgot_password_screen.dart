import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await SupabaseService.resetPassword(email);
      if (mounted) setState(() { _loading = false; _sent = true; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blush,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              const Text('🔒', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text('Reset Password',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24)),
              const SizedBox(height: 8),
              const Text(
                  'Enter your email and we\'ll send you a link to reset your password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMid, fontSize: 14)),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.textDark.withValues(alpha: 0.08),
                        blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: _sent ? _sentState() : _formState(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sentState() {
    return Column(
      children: [
        const Icon(Icons.mark_email_read_outlined, color: AppColors.sage, size: 48),
        const SizedBox(height: 12),
        const Text('Check your email',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 6),
        Text('We sent a password reset link to ${_emailCtrl.text.trim()}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
        const SizedBox(height: 20),
        TBButton(label: 'Back to Sign In', onPressed: () => context.pop()),
      ],
    );
  }

  Widget _formState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined, color: AppColors.textLight)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(children: [
              Icon(Icons.error_outline, color: Colors.red.shade600, size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(_error!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        TBButton(label: 'Send Reset Link', onPressed: _submit, loading: _loading),
      ],
    );
  }
}
