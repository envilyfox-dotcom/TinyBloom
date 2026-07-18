import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── Chat with a Volunteer (Next of Kin) ───────────────────────────────
// A dedicated volunteer-browsing screen for next-of-kin, separate from the
// mum's VolunteersListScreen (mum/consultation/volunteers_list_screen.dart)
// since that one is about booking a scheduled consultation — this one
// drops the "consultation"/timings framing entirely. There's no chat
// feature built yet, so the CTA is a placeholder until that's designed.
class ChatVolunteerScreen extends StatefulWidget {
  const ChatVolunteerScreen({super.key});
  @override
  State<ChatVolunteerScreen> createState() => _ChatVolunteerScreenState();
}

class _ChatVolunteerScreenState extends State<ChatVolunteerScreen> {
  List<Map<String, dynamic>> _volunteers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.getVolunteers();
      if (mounted) {
        setState(() {
          _volunteers = data;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _comingSoon(String name) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Chat with $name — coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chat with a Volunteer')),
      body: _loading
          ? const TBLoading()
          : RefreshIndicator(
              color: AppColors.rose,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  const Text(
                    'Choose a community volunteer to connect with.',
                    style: TextStyle(color: AppColors.textMid, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    TBEmptyState(
                        emoji: '⚠️',
                        title: "Couldn't load volunteers",
                        subtitle: _error!,
                        buttonLabel: 'Retry',
                        onButton: () {
                          setState(() => _loading = true);
                          _load();
                        })
                  else if (_volunteers.isEmpty)
                    const TBEmptyState(
                        emoji: '🤝',
                        title: 'No volunteers available',
                        subtitle: 'Check back later for available volunteers.')
                  else
                    ..._volunteers.map(_volunteerCard),
                ],
              ),
            ),
    );
  }

  Widget _volunteerCard(Map<String, dynamic> volunteer) {
    final profile = volunteer['profiles'] as Map<String, dynamic>? ?? {};
    final name = profile['full_name'] as String? ?? 'Volunteer';
    final photoUrl = profile['profile_picture_url'] as String?;
    final expertise = volunteer['expertise'] as String? ?? 'Volunteer';
    final rating = (volunteer['rating'] as num?)?.toStringAsFixed(1);
    final years = volunteer['years_experience'];
    final affiliation = volunteer['affiliation'] as String? ?? '';
    final certification = volunteer['certification'] as String? ?? '';
    final helpsWith =
        (volunteer['helps_with'] as List?)?.map((e) => e.toString()).toList() ??
            const <String>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TBCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                    image: photoUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(photoUrl,
                                maxWidth: 400),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  child: photoUrl != null
                      ? null
                      : Center(
                          child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'V',
                              style: const TextStyle(
                                  color: AppColors.sage,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700)),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.textDark)),
                      const SizedBox(height: 3),
                      Text(expertise,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textMid, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (rating != null)
                            _chip('$rating Rating', AppColors.gold,
                                Icons.star_rounded),
                          if (years != null)
                            _chip('$years Years', AppColors.rose,
                                Icons.work_outline),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (affiliation.isNotEmpty || certification.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (affiliation.isNotEmpty)
                      _infoLine(Icons.location_city_outlined, affiliation),
                    if (affiliation.isNotEmpty && certification.isNotEmpty)
                      const SizedBox(height: 6),
                    if (certification.isNotEmpty)
                      _infoLine(Icons.school_outlined, certification),
                  ],
                ),
              ),
            ],
            if (helpsWith.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Helps with',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.textDark)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: helpsWith
                    .take(4)
                    .map((h) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.sage.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(h,
                              style: const TextStyle(
                                  color: AppColors.sage,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _comingSoon(name),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sage,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                label: const Text('Chat with Volunteer',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _infoLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textLight, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: AppColors.textMid, fontSize: 12, height: 1.35)),
        ),
      ],
    );
  }
}
