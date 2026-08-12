import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/singapore_time.dart';

String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(toSingaporeTime(date));
}

String forumRoleLabel(String? role) {
  switch (role) {
    case 'free_user':
    case 'premium_user':
      return 'Mother';
    case 'next_of_kin':
      return 'Next of Kin';
    case 'specialist':
      return 'Specialist';
    case 'volunteer':
      return 'Volunteer';
    case 'admin':
      return 'Admin';
    default:
      return '';
  }
}

String? volunteerExpertise(Map<String, dynamic>? profile) {
  final vp = profile?['volunteer_profiles'];
  Map<String, dynamic>? row;
  if (vp is Map) row = Map<String, dynamic>.from(vp);
  if (vp is List && vp.isNotEmpty) row = Map<String, dynamic>.from(vp.first as Map);
  final expertise = (row?['expertise'] as String?)?.trim();
  return expertise != null && expertise.isNotEmpty ? expertise : null;
}

// Role label with a volunteer's expertise tacked on, e.g.
// "Volunteer • Breastfeeding Support".
String forumRoleSubtitle(Map<String, dynamic>? profile) {
  final label = forumRoleLabel(profile?['role'] as String?);
  final expertise = volunteerExpertise(profile);
  if (expertise == null) return label;
  return '$label • $expertise';
}

// Author avatar for a post/comment: their profile photo if they have one,
// otherwise their initial on a tinted circle.
Widget forumAvatar({
  required Map<String, dynamic>? profile,
  required String name,
  required double radius,
  required Color backgroundColor,
  required Color foregroundColor,
  double? fontSize,
}) {
  final photoUrl = profile?['profile_picture_url'] as String?;
  final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
  return CircleAvatar(
    radius: radius,
    backgroundColor: backgroundColor,
    backgroundImage:
        hasPhoto ? CachedNetworkImageProvider(photoUrl, maxWidth: 200) : null,
    child: hasPhoto
        ? null
        : Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
            ),
          ),
  );
}
