import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    final auth = context.read<AuthProvider>();
    final error = await auth.signIn(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    if (error != null) {
      setState(() { _loading = false; _error = error; });
      return;
    }
    // Admin tooling lives on the marketing website, not this app.
    if (auth.isAdmin) {
      await auth.signOut();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Admin accounts are managed on the TinyBloom website, not this app.';
      });
      return;
    }
    setState(() { _loading = false; });
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blush,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Logo & branding
              const Text('🌸', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 12),
              Text(
                'TinyBloom',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.roseDeep, fontSize: 32),
              ),
              const SizedBox(height: 6),
              Text(
                'Your Pregnancy Support Companion',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMid),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Form card
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome Back',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 22)),
                    const SizedBox(height: 4),
                    const Text('Sign in to your account',
                      style: TextStyle(color: AppColors.textLight, fontSize: 14)),
                    const SizedBox(height: 24),

                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined, color: AppColors.textLight),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textLight),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.textLight),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        child: const Text('Forgot Password?',
                          style: TextStyle(
                            color: AppColors.teal, fontSize: 13)),
                      ),
                    ),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                              color: Colors.red.shade600, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                style: TextStyle(
                                  color: Colors.red.shade700, fontSize: 13))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 8),
                    TBButton(
                      label: 'Sign In',
                      onPressed: _login,
                      loading: _loading,
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
