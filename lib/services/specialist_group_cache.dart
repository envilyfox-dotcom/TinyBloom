// In-memory cache of the current specialist's review-group standing
// (primary/secondary group + member specialties) — see
// Article_System_specialist.md §2. A specialist's specialization is fixed
// at registration and can't be changed from the app, so this data never
// changes for the lifetime of a signed-in session; re-fetching it every
// time the Review tab is opened only added a network round-trip that could
// race the "?" info button before it landed. Cleared on sign-out so a
// different account signing in on the same session never sees stale data.
class SpecialistGroupCache {
  static String? userId;
  static String? name;
  static String? specialization;
  static Map<String, dynamic>? primaryGroup;
  static List<Map<String, dynamic>> secondaryGroups = [];
  static Map<int, List<String>> groupSpecialties = {};

  static bool isValidFor(String currentUserId) =>
      userId == currentUserId;

  static void save({
    required String userId,
    required String? name,
    required String? specialization,
    required Map<String, dynamic>? primaryGroup,
    required List<Map<String, dynamic>> secondaryGroups,
    required Map<int, List<String>> groupSpecialties,
  }) {
    SpecialistGroupCache.userId = userId;
    SpecialistGroupCache.name = name;
    SpecialistGroupCache.specialization = specialization;
    SpecialistGroupCache.primaryGroup = primaryGroup;
    SpecialistGroupCache.secondaryGroups = secondaryGroups;
    SpecialistGroupCache.groupSpecialties = groupSpecialties;
  }

  static void clear() {
    userId = null;
    name = null;
    specialization = null;
    primaryGroup = null;
    secondaryGroups = [];
    groupSpecialties = {};
  }
}
