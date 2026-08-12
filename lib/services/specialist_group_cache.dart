// In-memory cache of a specialist's review group + specialties, so screens
// that need this don't have to re-fetch it on every navigation. Cleared on
// sign-out and keyed off userId so a stale cache from a previous user never
// leaks in.
class SpecialistGroupCache {
  static String? userId;
  static String? name;
  static String? specialization;
  static Map<String, dynamic>? primaryGroup;
  static List<Map<String, dynamic>> secondaryGroups = [];
  static Map<int, List<String>> groupSpecialties = {};

  // True if the cached data belongs to the currently signed-in user.
  static bool isValidFor(String currentUserId) => userId == currentUserId;

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
