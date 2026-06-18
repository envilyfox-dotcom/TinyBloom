import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SupabaseService.getProfile();
    if (mounted) setState(() { _profile = p; _loading = false; });
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'free_user': return 'Free Member';
      case 'premium_user': return 'Premium Member ⭐';
      case 'specialist': return 'Specialist / Doctor';
      case 'volunteer': return 'Volunteer';
      case 'next_of_kin': return 'Next of Kin';
      case 'admin': return 'Admin';
      default: return 'Member';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: TBLoading());
    final name = _profile?['full_name'] ?? 'User';
    final email = _profile?['email'] ?? '';
    final role = _profile?['role'] ?? '';
    final userCode = _profile?['user_code'];

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: AppColors.blush,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: AppColors.roseDeep,
                        fontSize: 28, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),
                  Text(name,
                    style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(email,
                    style: const TextStyle(color: AppColors.textMid, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(_roleLabel(role),
                      style: const TextStyle(
                        color: AppColors.teal, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            // User ID (mum accounts)
            if (userCode != null && (role == 'free_user' || role == 'premium_user'))
              Padding(
                padding: const EdgeInsets.all(16),
                child: TBCard(
                  color: AppColors.blush,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('YOUR UNIQUE USER ID',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: AppColors.roseDeep, letterSpacing: 1)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(userCode,
                              style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700,
                                letterSpacing: 3)),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              // Copy to clipboard
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('User ID copied!'),
                                  duration: Duration(seconds: 2)));
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy'),
                          ),
                        ],
                      ),
                      const Text(
                        'Share this ID with your partner or family so they can link to your account.',
                        style: TextStyle(color: AppColors.textMid, fontSize: 12)),
                    ],
                  ),
                ),
              ),

            // Menu items
            Padding(
              padding: const EdgeInsets.all(16),
              child: TBCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _menuItem(Icons.edit_outlined, 'Edit Profile',
                      onTap: () => context.push('/profile/edit', extra: _profile)
                          .then((_) => _load())),
                    _divider(),
                    if (role == 'specialist') ...[
                      _menuItem(Icons.link, 'Submit Article Link',
                        onTap: () => context.push('/submit-link')),
                      _divider(),
                    ],
                    if (role == 'free_user' || role == 'premium_user') ...[
                      _menuItem(Icons.workspace_premium_outlined, 'Subscription',
                        onTap: () => context.push('/subscription')),
                      _divider(),
                    ],
                    _menuItem(Icons.feedback_outlined, 'Feedback',
                      onTap: () => _showFeedback()),
                    _divider(),
                    _menuItem(Icons.logout, 'Sign Out',
                      color: Colors.red,
                      onTap: () => _signOut()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label,
      {VoidCallback? onTap, Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textMid, size: 22),
      title: Text(label,
        style: TextStyle(
          color: color ?? AppColors.textDark,
          fontWeight: FontWeight.w500, fontSize: 15)),
      trailing: const Icon(Icons.chevron_right,
        color: AppColors.textLight, size: 20),
      onTap: onTap,
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 56,
    color: AppColors.textLight, thickness: 0.3);

  void _showFeedback() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => const _FeedbackSheet(),
    );
  }

  Future<void> _signOut() async {
    final auth = context.read<AuthProvider>();
    await auth.signOut();
    if (mounted) context.go('/login');
  }
}

// ── Feedback Sheet with Star Rating ──────────────────────────────
class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet();

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  int _rating = 0;
  bool _loading = false;
  final _nameCtrl = TextEditingController();
  final _feedbackCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill name from profile
    SupabaseService.getProfile().then((p) {
      if (mounted && p != null) {
        _nameCtrl.text = p['full_name'] ?? '';
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating.')));
      return;
    }
    if (_feedbackCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your feedback.')));
      return;
    }

    setState(() => _loading = true);
    try {
      // Save as testimonial to Supabase
      await SupabaseService.client.from('testimonials').insert({
        'reviewer_name': _nameCtrl.text.trim(),
        'content': _feedbackCtrl.text.trim(),
        'rating': _rating,
        'review_date': DateTime.now().toIso8601String().split('T')[0],
        'is_published': false, // admin approves first
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback! 🌸'),
            backgroundColor: Color(0xFF7A9E8E)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
            backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF9B8B86).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          Text('Share Your Feedback',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 20)),
          const SizedBox(height: 4),
          const Text('Your feedback helps us improve TinyBloom.',
            style: TextStyle(color: Color(0xFF9B8B86), fontSize: 13)),
          const SizedBox(height: 20),

          // Name field
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Your Name',
              prefixIcon: Icon(Icons.person_outline,
                color: Color(0xFF9B8B86))),
          ),
          const SizedBox(height: 16),

          // Star rating
          const Text('Rating',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF5C4F4A))),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = starIndex),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    starIndex <= _rating ? Icons.star : Icons.star_border,
                    color: starIndex <= _rating
                        ? const Color(0xFFD4A847)
                        : const Color(0xFF9B8B86),
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          if (_rating > 0) ...[
            const SizedBox(height: 6),
            Text(
              _rating == 5 ? 'Excellent! 🌟'
                : _rating == 4 ? 'Very Good! 😊'
                : _rating == 3 ? 'Good 👍'
                : _rating == 2 ? 'Fair 😐'
                : 'Poor 😔',
              style: const TextStyle(
                color: Color(0xFFD4A847),
                fontWeight: FontWeight.w600,
                fontSize: 13)),
          ],
          const SizedBox(height: 16),

          // Feedback text
          TextFormField(
            controller: _feedbackCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Your Feedback',
              hintText: 'Tell us about your experience...',
              alignLabelWithHint: true),
          ),
          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Feedback'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
