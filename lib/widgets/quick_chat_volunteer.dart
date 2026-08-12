import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../utils/app_theme.dart';
import '../utils/singapore_time.dart';
import 'common_widgets.dart';

// Volunteer question rows can come from a few different queries/views that
// don't all use the same column names, so most helpers below just try a
// list of possible keys and take whichever one is actually populated.
String firstNonEmptyText(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return '';
}

Map<String, dynamic>? _nestedMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _titleCase(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return clean;
  return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
}

String _joinPreviewParts(List<String> parts) {
  return parts
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(' • ');
}

// Which column actually holds the volunteer's id depends on which query
// produced this row - try them in order.
String? quickChatVolunteerId(Map<String, dynamic> q) {
  final id = firstNonEmptyText([
    q['volunteer_id'],
    q['assigned_volunteer_id'],
    q['volunteer_user_id'],
    q['provider_id'],
    q['responder_id'],
    q['answered_by'],
    q['last_reply_by'],
    q['reply_by'],
  ]);

  return id.isEmpty ? null : id;
}

// Same idea as quickChatVolunteerId: try a flat column first, then fall
// back to digging through whichever joined/nested object this row has
// (some queries embed "profiles" a level deeper than others).
String quickChatVolunteerName(Map<String, dynamic> q) {
  final direct = firstNonEmptyText([
    q['volunteer_name'],
    q['provider_name'],
    q['assigned_volunteer_name'],
    q['responder_name'],
    q['helper_name'],
  ]);

  if (direct.isNotEmpty) return direct;

  for (final key in [
    'volunteer',
    'provider',
    'assigned_volunteer',
    'responder',
    'profiles',
  ]) {
    final map = _nestedMap(q[key]);
    if (map == null) continue;

    final nestedName = firstNonEmptyText([
      map['full_name'],
      map['name'],
      map['display_name'],
      map['username'],
    ]);
    if (nestedName.isNotEmpty) return nestedName;

    final nestedProfile = _nestedMap(map['profiles']);
    if (nestedProfile != null) {
      final profileName = firstNonEmptyText([
        nestedProfile['full_name'],
        nestedProfile['name'],
        nestedProfile['display_name'],
      ]);
      if (profileName.isNotEmpty) return profileName;
    }
  }

  return 'Volunteer Support';
}

String? quickChatVolunteerPhotoUrl(Map<String, dynamic> q) {
  final direct = firstNonEmptyText([
    q['provider_photo_url'],
    q['volunteer_photo_url'],
    q['profile_picture_url'],
    q['photo_url'],
    q['avatar_url'],
  ]);

  if (direct.isNotEmpty) return direct;

  for (final key in [
    'volunteer',
    'provider',
    'assigned_volunteer',
    'responder',
    'profiles',
  ]) {
    final map = _nestedMap(q[key]);
    if (map == null) continue;

    final nestedPhoto = firstNonEmptyText([
      map['profile_picture_url'],
      map['photo_url'],
      map['avatar_url'],
    ]);
    if (nestedPhoto.isNotEmpty) return nestedPhoto;

    final nestedProfile = _nestedMap(map['profiles']);
    if (nestedProfile != null) {
      final profilePhoto = firstNonEmptyText([
        nestedProfile['profile_picture_url'],
        nestedProfile['photo_url'],
        nestedProfile['avatar_url'],
      ]);
      if (profilePhoto.isNotEmpty) return profilePhoto;
    }
  }

  return null;
}

// The mum's original question text, whichever column it's stored under.
String quickChatQuestionText(Map<String, dynamic> q) {
  final text = firstNonEmptyText([
    q['question'],
    q['title'],
    q['subject'],
    q['content'],
  ]);

  return text.isEmpty ? 'No question details available.' : text;
}

// The volunteer's latest reply, if any. Some rows echo the question back
// into what would otherwise look like a "reply" field, so we treat that
// as no reply rather than showing the question twice.
String quickChatLatestReplyText(Map<String, dynamic> q) {
  final question = quickChatQuestionText(q);
  final reply = firstNonEmptyText([
    q['latest_reply'],
    q['last_reply'],
    q['volunteer_reply'],
    q['reply'],
    q['response'],
    q['answer'],
    q['latest_message'],
    q['last_message'],
    q['message'],
  ]);

  if (reply.isEmpty || reply == question) return '';
  return reply;
}

// Human-readable status label. Different backends/flows use different
// status strings for the same state, so this groups the synonyms together.
String quickChatStatusText(Map<String, dynamic> q) {
  final status = (q['status'] ?? '').toString().trim().toLowerCase();
  final reply = quickChatLatestReplyText(q);

  if (status == 'pending' || status == 'open' || status == 'waiting') {
    return 'Waiting for volunteer reply';
  }

  if (status == 'closed' || status == 'completed' || status == 'resolved') {
    return 'Chat completed';
  }

  if (status == 'answered' || status == 'replied' || reply.isNotEmpty) {
    return 'Volunteer replied';
  }

  if (status.isEmpty) return 'Quick chat';
  return _titleCase(status.replaceAll('_', ' '));
}

bool quickChatIsEnded(Map<String, dynamic> q) {
  final status = (q['status'] ?? '').toString().trim().toLowerCase();
  return status == 'closed' || status == 'completed' || status == 'resolved';
}

// Colour to match quickChatStatusText - keep the two in sync if you change
// either.
Color quickChatStatusColor(Map<String, dynamic> q) {
  final status = (q['status'] ?? '').toString().trim().toLowerCase();
  final reply = quickChatLatestReplyText(q);

  if (status == 'pending' || status == 'open' || status == 'waiting') {
    return AppColors.gold;
  }

  if (status == 'closed' || status == 'completed' || status == 'resolved') {
    return AppColors.textMid;
  }

  if (status == 'answered' || status == 'replied' || reply.isNotEmpty) {
    return AppColors.sage;
  }

  return AppColors.infoBlue;
}

String quickChatTimeText(Map<String, dynamic> q) {
  final raw = firstNonEmptyText([
    q['last_reply_at'],
    q['updated_at'],
    q['created_at'],
    q['submitted_at'],
  ]);

  if (raw.isEmpty) return '';
  final parsed = sgtFrom(raw);
  if (parsed == null) return '';

  return DateFormat('d MMM, h:mm a').format(parsed);
}

// One-line preview shown in list cards: status, time, and either the
// latest reply or the original question if there's no reply yet.
String quickChatPreviewText(Map<String, dynamic> q) {
  final question = quickChatQuestionText(q);
  final reply = quickChatLatestReplyText(q);
  final status = quickChatStatusText(q);
  final time = quickChatTimeText(q);

  return _joinPreviewParts([
    status,
    if (time.isNotEmpty) time,
    if (reply.isNotEmpty) 'Latest reply: $reply' else 'Question: $question',
  ]);
}

// Looks up a volunteer's display name/photo by id, for rows where that
// wasn't already embedded in the query result. Tries the dedicated provider
// profile endpoint first, then falls back to querying `profiles` directly
// if that comes back empty.
Future<Map<String, String?>> loadQuickChatProviderDisplay(
  String? providerId, {
  required String fallbackName,
}) async {
  final cleanId = providerId?.trim();

  if (cleanId == null || cleanId.isEmpty) {
    return {'name': fallbackName, 'photo_url': null};
  }

  try {
    final provider = await SupabaseService.getProviderProfile(cleanId);
    final profile = provider?['profiles'];

    if (profile is Map<String, dynamic>) {
      final name = (profile['full_name'] ?? '').toString().trim();
      final photoUrl = (profile['profile_picture_url'] ?? '').toString();

      if (name.isNotEmpty) {
        return {'name': name, 'photo_url': photoUrl.isEmpty ? null : photoUrl};
      }
    }

    final directName = (provider?['full_name'] ?? '').toString().trim();
    final directPhotoUrl =
        (provider?['profile_picture_url'] ?? '').toString().trim();

    if (directName.isNotEmpty) {
      return {
        'name': directName,
        'photo_url': directPhotoUrl.isEmpty ? null : directPhotoUrl,
      };
    }
  } catch (e) {
    debugPrint('Provider profile lookup failed for $cleanId: $e');
  }

  try {
    final profile = await SupabaseService.client
        .from('profiles')
        .select('full_name,profile_picture_url')
        .eq('id', cleanId)
        .maybeSingle();

    final name = (profile?['full_name'] ?? '').toString().trim();
    final photoUrl = (profile?['profile_picture_url'] ?? '').toString();

    if (name.isNotEmpty) {
      return {'name': name, 'photo_url': photoUrl.isEmpty ? null : photoUrl};
    }
  } catch (e) {
    debugPrint('Direct profile lookup failed for $cleanId: $e');
  }

  return {'name': fallbackName, 'photo_url': null};
}

// Fills in missing volunteer name/photo for each question (by looking them
// up when needed) and sorts the list newest-activity-first.
Future<List<Map<String, dynamic>>> enrichQuickChatQuestions(
  List<Map<String, dynamic>> questions,
) async {
  final enriched = <Map<String, dynamic>>[];

  for (final question in questions) {
    final row = Map<String, dynamic>.from(question);
    final existingName = quickChatVolunteerName(row);
    final existingPhoto = quickChatVolunteerPhotoUrl(row);
    final volunteerId = quickChatVolunteerId(row);

    if (volunteerId != null &&
        (existingName == 'Volunteer Support' || existingPhoto == null)) {
      try {
        final provider = await loadQuickChatProviderDisplay(
          volunteerId,
          fallbackName: existingName,
        );

        final providerName = provider['name']?.trim();
        final providerPhoto = provider['photo_url']?.trim();

        if (providerName != null &&
            providerName.isNotEmpty &&
            providerName != 'Volunteer Support') {
          row['provider_name'] = providerName;
        }

        if (providerPhoto != null && providerPhoto.isNotEmpty) {
          row['provider_photo_url'] = providerPhoto;
        }
      } catch (e) {
        debugPrint('Failed to enrich quick chat volunteer $volunteerId: $e');
      }
    }

    enriched.add(row);
  }

  enriched.sort((a, b) {
    final aDate = DateTime.tryParse(firstNonEmptyText([
          a['last_reply_at'],
          a['updated_at'],
          a['created_at'],
          a['submitted_at'],
        ])) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = DateTime.tryParse(firstNonEmptyText([
          b['last_reply_at'],
          b['updated_at'],
          b['created_at'],
          b['submitted_at'],
        ])) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return bDate.compareTo(aDate);
  });

  return enriched;
}

// List-item card for a single quick-chat question, shown on the home/
// consultation screens. Tapping it opens the full chat and reloads on
// return in case the volunteer replied while it was open.
class QuickChatPreviewCard extends StatelessWidget {
  final Map<String, dynamic> question;
  final Future<void> Function() onReload;
  const QuickChatPreviewCard(
      {super.key, required this.question, required this.onReload});

  @override
  Widget build(BuildContext context) {
    final q = question;
    final volunteerName = quickChatVolunteerName(q);
    final photoUrl = quickChatVolunteerPhotoUrl(q);
    final status = quickChatStatusText(q);
    final statusColor = quickChatStatusColor(q);
    final questionText = quickChatQuestionText(q);
    final preview = quickChatPreviewText(q);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TBCard(
        onTap: () async {
          await context.push('/ask-volunteer/detail', extra: q);
          await onReload();
        },
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                image: photoUrl != null && photoUrl.isNotEmpty
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(
                          photoUrl,
                          maxWidth: 200,
                        ),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? null
                  : Center(
                      child: Text(
                        volunteerName.isNotEmpty
                            ? volunteerName[0].toUpperCase()
                            : 'V',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Quick Chat with Volunteer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.infoBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    volunteerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    questionText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textLight,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// "Quick Chat with Volunteer" section on the home screen: a short list of
// the most recent quick-chat questions, or an empty state if none.
class QuickChatVolunteerSection extends StatelessWidget {
  final List<Map<String, dynamic>> questions;
  final Future<void> Function() onReload;
  const QuickChatVolunteerSection(
      {super.key, required this.questions, required this.onReload});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Quick Chat with Volunteer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/consultation/volunteer-chats'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Latest volunteer replies and question updates at a glance.',
          style: TextStyle(
            color: AppColors.textMid,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        if (questions.isEmpty)
          TBCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: const Row(
              children: [
                Icon(Icons.chat_bubble_outline,
                    color: AppColors.textLight, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No ongoing chats with a volunteer right now.',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (final q in questions.take(3))
            QuickChatPreviewCard(question: q, onReload: onReload),
        const SizedBox(height: 8),
      ],
    );
  }
}
