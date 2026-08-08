class SpecialistGroupCache {
  static String? userId;
  static String? name;
  static String? specialization;
  static Map<String, dynamic>? primaryGroup;
  static List<Map<String, dynamic>> secondaryGroups = [];
  static Map<int, List<String>> groupSpecialties = {};

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
