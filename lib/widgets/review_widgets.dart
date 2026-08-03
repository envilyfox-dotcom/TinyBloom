import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/mum/consultation/consultation_helpers.dart'
    show appointmentIdLabel;
import '../screens/specialist/specialist_notifications_helpers.dart'
    show timeAgoLabel;
import '../utils/app_theme.dart';
import 'common_widgets.dart';

// Shared "User Review" building blocks for the specialist and volunteer
// dashboards — same design for both, only the underlying provider_ratings
// data differs. Star-only: no comment is ever collected, so none is shown.
Widget providerReviewCard(Map<String, dynamic> rating) {
  final mum = rating['mum'] as Map<String, dynamic>?;
  final reviewerName = (mum?['full_name'] as String?) ?? 'A mum';
  final photoUrl = mum?['profile_picture_url'] as String?;
  final stars = (rating['rating'] as num?)?.toInt() ?? 0;
  final createdAt = DateTime.tryParse(rating['created_at']?.toString() ?? '');
  final sourceType = rating['source_type'] as String?;
  final sourceId = rating['source_id']?.toString();
  // Consultations get the same short SPC-xxxxxx/VOL-xxxxxx id shown
  // elsewhere for the same appointment; chat-sourced ratings (volunteer
  // quick chat) aren't consultations table rows, so they keep the raw id.
  final sourceLabel = sourceId == null
      ? null
      : sourceType == 'consultation'
          ? 'From Appointment: ${appointmentIdLabel(sourceId, rating['provider_type'] as String?)}'
          : 'From Chat: $sourceId';

  return TBCard(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.rose.withValues(alpha: 0.15),
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl != null && photoUrl.isNotEmpty
                ? null
                : Text(reviewerName.isNotEmpty ? reviewerName[0] : '?',
                    style: const TextStyle(
                        color: AppColors.rose,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reviewerName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                if (createdAt != null) ...[
                  const SizedBox(height: 2),
                  Text(timeAgoLabel(createdAt),
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 11)),
                ],
                if (sourceLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(sourceLabel,
                      style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 4),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < stars ? Icons.star : Icons.star_outline,
                      color: AppColors.gold,
                      size: 14,
                    ),
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

Widget providerReviewsSection(
  BuildContext context, {
  required List<Map<String, dynamic>> ratings,
  required String providerId,
  required String providerName,
  required String providerType,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text('User Review:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          if (ratings.isNotEmpty)
            TextButton(
              onPressed: () => context.push('/provider/reviews', extra: {
                'providerId': providerId,
                'providerName': providerName,
                'providerType': providerType,
              }),
              child: const Text('View All >'),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (ratings.isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: TBEmptyState(
              emoji: '⭐',
              title: 'No reviews yet',
              subtitle: 'Reviews from the mums you\'ve helped will show here.'),
        )
      else
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: providerReviewCard(ratings.first),
        ),
    ],
  );
}
