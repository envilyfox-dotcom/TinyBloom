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
  Map<String, dynamic>? _linkedMum;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SupabaseService.getProfile();
    Map<String, dynamic>? linkedMum;
    if (p?['role'] == 'next_of_kin') {
      try { linkedMum = await SupabaseService.getLinkedMum(); } catch (_) {}
    }
    if (mounted) {
      setState(() { _profile = p; _linkedMum = linkedMum; _loading = false; });
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'free_user':
        return 'Free Member';
      case 'premium_user':
        return 'Premium Member';
      case 'specialist':
        return 'Specialist / Doctor';
      case 'volunteer':
        return 'Volunteer';
      case 'next_of_kin':
        return 'Next of Kin';
      case 'admin':
        return 'Admin';
      default:
        return 'Member';
    }
  }

  IconData _roleIcon(String? role) {
    switch (role) {
      case 'premium_user':
        return Icons.workspace_premium_outlined;
      case 'specialist':
        return Icons.medical_services_outlined;
      case 'volunteer':
        return Icons.volunteer_activism_outlined;
      case 'next_of_kin':
        return Icons.family_restroom_outlined;
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.local_florist_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: TBLoading());

    final name = (_profile?['full_name'] as String?)?.trim().isNotEmpty == true
        ? _profile!['full_name'] as String
        : 'User';
    final email = _profile?['email'] as String? ?? '';
    final role = _profile?['role'] as String? ?? '';
    final userCode = _profile?['user_code'];
    final photoUrl = _profile?['profile_picture_url'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.rose,
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileHeader(
                name: name,
                email: email,
                roleLabel: _roleLabel(role),
                roleIcon: _roleIcon(role),
                photoUrl: photoUrl,
              ),
              const SizedBox(height: 16),
              if (userCode != null &&
                  (role == 'free_user' || role == 'premium_user')) ...[
                _UserCodeCard(userCode: userCode.toString()),
                const SizedBox(height: 16),
              ],
              if (role == 'next_of_kin') ...[
                TBCard(
                  color: AppColors.blush,
                  child: Row(
                    children: [
                      Icon(
                        _linkedMum != null ? Icons.favorite : Icons.link_off,
                        color: AppColors.roseDeep, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('CONNECTED TO',
                              style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: AppColors.roseDeep, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(
                              _linkedMum != null
                                  ? (_linkedMum!['full_name'] as String? ?? 'Unnamed')
                                  : 'Not linked to a pregnant user yet',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                            if (_linkedMum?['relationship'] != null) ...[
                              const SizedBox(height: 2),
                              Text(_linkedMum!['relationship'] as String,
                                style: const TextStyle(
                                  color: AppColors.textMid, fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _SectionCard(
                title: 'Account',
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
                  if (role == 'next_of_kin') ...[
                    _menuItem(Icons.link, 'Link to Pregnant User',
                      onTap: () => context.push('/next-of-kin/link')),
                    _divider(),
                    _menuItem(Icons.help_outline, 'FAQ',
                      onTap: () => context.push('/next-of-kin/faq')),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(
    IconData icon,
    String label, {
    String? subtitle,
    VoidCallback? onTap,
    Color? color,
    bool showChevron = true,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: (color ?? AppColors.rose).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color ?? AppColors.roseDeep, size: 21),
      ),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color ?? AppColors.textDark,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textLight, fontSize: 12),
            ),
      trailing: showChevron
          ? const Icon(Icons.chevron_right,
              color: AppColors.textLight, size: 20)
          : null,
      onTap: onTap,
    );
  }

  Widget _divider() => const Divider(
        height: 1,
        indent: 72,
        endIndent: 16,
        color: AppColors.textLight,
        thickness: 0.25,
      );

  void _showFeedback() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _FeedbackSheet(),
    );
  }

  Future<void> _signOut() async {
    final auth = context.read<AuthProvider>();
    await auth.signOut();
    if (mounted) context.go('/login');
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String roleLabel;
  final IconData roleIcon;
  final String? photoUrl;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.roleLabel,
    required this.roleIcon,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.blush,
            AppColors.rose.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: AppColors.white,
            backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl != null
                ? null
                : Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: AppColors.roseDeep,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMid, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(roleIcon, color: AppColors.teal, size: 16),
                const SizedBox(width: 6),
                Text(
                  roleLabel,
                  style: const TextStyle(
                    color: AppColors.teal,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCodeCard extends StatelessWidget {
  final String userCode;

  const _UserCodeCard({required this.userCode});

  @override
  Widget build(BuildContext context) {
    return TBCard(
      color: AppColors.white,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.badge_outlined, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Unique User ID',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.roseDeep,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Share this with your family to link accounts.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textLight, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('User ID copied!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy, color: AppColors.textMid, size: 20),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        TBCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet();

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  int _rating = 0;
  bool _loading = false;
  String _name = 'User';
  final _feedbackCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    SupabaseService.getProfile().then((p) {
      if (mounted && p != null) {
        setState(() {
          final fullName = p['full_name'] as String?;
          _name =
              fullName?.trim().isNotEmpty == true ? fullName!.trim() : 'User';
        });
      }
    });
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      _showSnack('Please select a rating.');
      return;
    }
    if (_feedbackCtrl.text.trim().isEmpty) {
      _showSnack('Please enter your feedback.');
      return;
    }

    setState(() => _loading = true);
    try {
      await SupabaseService.client.from('testimonials').insert({
        'reviewer_name': _name,
        'content': _feedbackCtrl.text.trim(),
        'rating': _rating,
        'review_date': DateTime.now().toIso8601String().split('T')[0],
        'is_published': false,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for your feedback! 🌸'),
          backgroundColor: AppColors.sage,
        ),
      );
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppColors.rose,
      ),
    );
  }

  String get _ratingLabel {
    switch (_rating) {
      case 5:
        return 'Excellent! 🌟';
      case 4:
        return 'Very Good! 😊';
      case 3:
        return 'Good 👍';
      case 2:
        return 'Fair 😐';
      case 1:
        return 'Poor 😔';
      default:
        return 'Tap a star to rate your experience';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textLight.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.rose.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.feedback_outlined,
                          color: AppColors.roseDeep),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share Your Feedback',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontSize: 20),
                          ),
                          const Text(
                            'Your feedback helps us improve TinyBloom.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.textLight, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TBCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          color: AppColors.textLight, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Feedback name',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Rating',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: List.generate(5, (i) {
                      final starIndex = i + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = starIndex),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            starIndex <= _rating
                                ? Icons.star
                                : Icons.star_border,
                            color: starIndex <= _rating
                                ? AppColors.gold
                                : AppColors.textLight,
                            size: 38,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _ratingLabel,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _feedbackCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Your Feedback',
                    hintText: 'Tell us about your experience...',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Feedback',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
