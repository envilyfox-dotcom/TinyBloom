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

// Small role label shown under a forum post/comment author's name.
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
