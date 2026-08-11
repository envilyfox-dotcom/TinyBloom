import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_theme.dart';
import '../utils/singapore_time.dart';

class SupabaseService {
  static const int maxProfilePictureBytes = 5 * 1024 * 1024;
  static const int maxArticleImageBytes = 10 * 1024 * 1024;
  static const Set<String> allowedImageExtensions = {
    'png',
    'jpg',
    'jpeg',
    'webp',
  };

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      publishableKey: AppConstants.supabaseAnonKey,
    );
  }

  static User? get currentUser => client.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;

  static Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth
        .signInWithPassword(email: email, password: password);
  }

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': role},
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final res = await client
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .maybeSingle()
        .timeout(const Duration(seconds: 6));
    return res;
  }

  static Future<Map<String, dynamic>?> getProfileById(String userId) async {
    final res = await client
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle();
    return res;
  }

  static Future<void> updateProfile(Map<String, dynamic> data) async {
    final user = currentUser;
    if (user == null) return;
    await client.from('profiles').update(data).eq('id', user.id);
  }

  static Future<String> uploadProfilePicture(
      Uint8List bytes, String fileExt) async {
    final user = currentUser;
    if (user == null) throw Exception('Not signed in.');

    final ext = fileExt.toLowerCase();
    _validateImageUpload(
      bytes: bytes,
      extension: ext,
      maxBytes: maxProfilePictureBytes,
      label: 'Profile picture',
    );
    final path = '${user.id}/avatar.$ext';
    final contentType = _imageContentType(ext);
    await client.storage.from('avatars').uploadBinary(path, bytes,
        fileOptions: FileOptions(upsert: true, contentType: contentType));

    final url =
        '${client.storage.from('avatars').getPublicUrl(path)}?t=${DateTime.now().millisecondsSinceEpoch}';
    await updateProfile({'profile_picture_url': url});
    return url;
  }

  static Future<String> uploadArticleImage(
      Uint8List bytes, String fileExt) async {
    final user = currentUser;
    if (user == null) throw Exception('Not signed in.');

    final ext = fileExt.toLowerCase();
    _validateImageUpload(
      bytes: bytes,
      extension: ext,
      maxBytes: maxArticleImageBytes,
      label: 'Educational post image',
    );
    final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final contentType = _imageContentType(ext);
    await client.storage.from('article-images').uploadBinary(path, bytes,
        fileOptions: FileOptions(contentType: contentType));

    return client.storage.from('article-images').getPublicUrl(path);
  }

  static String _imageContentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  static void _validateImageUpload({
    required Uint8List bytes,
    required String extension,
    required int maxBytes,
    required String label,
  }) {
    if (!allowedImageExtensions.contains(extension)) {
      throw Exception('$label must be PNG, JPG, or WebP.');
    }
    if (bytes.length > maxBytes) {
      final maxMb = maxBytes ~/ (1024 * 1024);
      throw Exception('$label must be ${maxMb}MB or smaller.');
    }
  }

  static Future<void> removeProfilePicture() async {
    final user = currentUser;
    if (user == null) return;
    await updateProfile({'profile_picture_url': null});
    try {
      final files = await client.storage.from('avatars').list(path: user.id);
      final paths = files.map((f) => '${user.id}/${f.name}').toList();
      if (paths.isNotEmpty) await client.storage.from('avatars').remove(paths);
    } catch (_) {}
  }

  static Future<void> setSubscriptionPlan(String? plan) async {
    await updateProfile({
      'subscription_plan': plan,
      'role': plan == null ? 'free_user' : 'premium_user',
    });
  }

  static Future<void> giftSubscriptionPlan(String mumId, String plan) async {
    await client.rpc('gift_subscription_to_linked_mum', params: {
      'mum_id': mumId,
      'plan': plan,
    });
  }

  static Future<Map<String, dynamic>?> getPregnancyProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final res = await client
        .from('pregnancy_profiles')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle()
        .timeout(const Duration(seconds: 6));
    return res;
  }

  static Future<Map<String, dynamic>?> getPregnancyProfileByUserId(
      String userId) async {
    final res = await client
        .from('pregnancy_profiles')
        .select('*')
        .eq('user_id', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 6));
    return res;
  }

  static int pregnancyWeekFromProfile(Map<String, dynamic>? data) {
    if (data == null) return 0;
    if (data['due_date'] != null) {
      final dueDate = sgtDateFrom(data['due_date']);
      if (dueDate != null) {
        final daysUntilDue = dueDate.difference(sgtNow()).inDays;
        return ((280 - daysUntilDue) / 7).floor().clamp(1, 40);
      }
    }
    if (data['current_week'] != null) {
      return (data['current_week'] as num).toInt().clamp(1, 42);
    }
    if (data['pregnancy_week'] != null) {
      return (data['pregnancy_week'] as num).toInt().clamp(1, 42);
    }
    return 0;
  }

  static Future<int> getCurrentPregnancyWeekByUserId(String userId) async {
    try {
      final data = await getPregnancyProfileByUserId(userId);
      return pregnancyWeekFromProfile(data);
    } catch (_) {
      return 0;
    }
  }

  static Future<int> getCurrentPregnancyWeek() async {
    try {
      final data = await getPregnancyProfile();
      if (data == null) return 0;
      if (data['due_date'] != null) {
        final due = sgtDateFrom(data['due_date']);
        if (due != null) {
          final daysUntilDue = due.difference(sgtNow()).inDays;
          return ((280 - daysUntilDue) / 7).floor().clamp(1, 40);
        }
      }
      if (data['weeks_pregnant'] != null) {
        return (data['weeks_pregnant'] as int).clamp(1, 40);
      }
    } catch (_) {}
    return 0;
  }

  static Future<void> savePregnancyProfile(Map<String, dynamic> data) async {
    final user = currentUser;
    if (user == null) return;
    final conception =
        sgtDateFrom(data['due_date'])?.subtract(const Duration(days: 280));
    final week =
        conception != null ? sgtNow().difference(conception).inDays ~/ 7 : null;
    await client.from('pregnancy_profiles').upsert(
      {
        'user_id': user.id,
        if (data['age'] != null) 'age': data['age'],
        if (data['pregnancy_status'] != null)
          'pregnancy_status': data['pregnancy_status'],
        if (data['due_date'] != null) 'due_date': data['due_date'],
        if (week != null) 'current_week': week.clamp(1, 42),
        if (data['pregnancy_week'] != null)
          'pregnancy_week': data['pregnancy_week'],
        if (data['height_cm'] != null) 'height_cm': data['height_cm'],
        if (data['weight_kg'] != null) 'weight_kg': data['weight_kg'],
        if (data['medical_conditions'] != null)
          'medical_conditions': data['medical_conditions'],
        if (data['allergies'] != null) 'allergies': data['allergies'],
        if (data['areas_of_interest'] != null)
          'areas_of_interest': data['areas_of_interest'],
        if (data['consultation_needs'] != null)
          'consultation_needs': data['consultation_needs'],
      },
      onConflict: 'user_id',
    );
  }

  static Future<void> updateDueDate(DateTime dueDate) async {
    final user = currentUser;
    if (user == null) return;
    final conception =
        asSgtWallClock(dueDate).subtract(const Duration(days: 280));
    final week = sgtNow().difference(conception).inDays ~/ 7;
    await client.from('pregnancy_profiles').upsert(
      {
        'user_id': user.id,
        'due_date': dateOnly(dueDate),
        'current_week': week.clamp(1, 42),
      },
      onConflict: 'user_id',
    );
  }

  static Future<List<Map<String, dynamic>>> getLogs() async {
    final user = currentUser;
    if (user == null) return [];
    try {
      final res = await client
          .from('pregnancy_logs')
          .select('*')
          .eq('user_id', user.id)
          .order('log_date', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getLogsForPatient(
      String patientId) async {
    try {
      final res = await client
          .from('pregnancy_logs')
          .select('*')
          .eq('user_id', patientId)
          .order('log_date', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  // Moods are returned as {'label': ..., 'icon': ...} maps (icon may be
  // empty if the admin hasn't set one) so the UI can show the emoji the
  // admin actually picked instead of guessing from the label text.
  static Future<Map<String, dynamic>> getPregnancyLogOptions() async {
    final res = await client
        .from('pregnancy_log_options')
        .select('category, label, icon')
        .order('category', ascending: true)
        .order('sort_order', ascending: true);
    final moods = <Map<String, String>>[];
    final symptoms = <String>[];
    final milestones = <String>[];
    for (final row in List<Map<String, dynamic>>.from(res)) {
      if (row['category'] == 'mood') {
        moods.add({
          'label': row['label'] as String,
          'icon': (row['icon'] as String?) ?? '',
        });
      } else if (row['category'] == 'symptom') {
        symptoms.add(row['label'] as String);
      } else if (row['category'] == 'milestone') {
        milestones.add(row['label'] as String);
      }
    }
    return {'mood': moods, 'symptom': symptoms, 'milestone': milestones};
  }

  static Future<Map<String, dynamic>> getOnboardingOptions() async {
    final res = await client
        .from('onboarding_options')
        .select('category, label, description, is_text_input')
        .order('category', ascending: true)
        .order('sort_order', ascending: true);
    final conditions = <String>[];
    final allergies = <String>[];
    final allergyDescriptions = <String, String>{};
    final textInputLabels = <String>{};
    for (final row in List<Map<String, dynamic>>.from(res)) {
      final label = row['label'] as String;
      if (row['is_text_input'] == true) textInputLabels.add(label);
      if (row['category'] == 'medical_condition') {
        conditions.add(label);
      } else if (row['category'] == 'allergy') {
        allergies.add(label);
        final desc = row['description'] as String?;
        if (desc != null && desc.isNotEmpty) allergyDescriptions[label] = desc;
      }
    }
    return {
      'conditions': conditions,
      'allergies': allergies,
      'allergyDescriptions': allergyDescriptions,
      'textInputLabels': textInputLabels,
    };
  }

  static Future<void> createLog(Map<String, dynamic> data) async {
    final user = currentUser;
    if (user == null) return;
    await client.from('pregnancy_logs').insert({
      ...data,
      'user_id': user.id,
      'log_date': data['log_date'] ?? sgtToday(),
    });
  }

  static Future<void> updateLog(String id, Map<String, dynamic> data) async {
    await client.from('pregnancy_logs').update(data).eq('id', id);
  }

  static Future<void> deleteLog(String id) async {
    await client.from('pregnancy_logs').delete().eq('id', id);
  }

  static Future<List<Map<String, dynamic>>> getFaqs({String? category}) async {
    List<Map<String, dynamic>> res;
    if (category != null) {
      res = await client
          .from('faqs')
          .select('*')
          .eq('is_published', true)
          .eq('category', category)
          .order('display_order', ascending: true);
    } else {
      res = await client
          .from('faqs')
          .select('*')
          .eq('is_published', true)
          .order('display_order', ascending: true);
    }
    return res;
  }

  static const _articleSelect =
      '*, author:profiles!created_by(full_name, profile_picture_url, specialist_profiles(specialization)), '
      'public_comments(count), article_likes(count)';

  static Future<List<Map<String, dynamic>>> getArticles(
      {String? category}) async {
    List<Map<String, dynamic>> res;
    if (category != null) {
      res = await client
          .from('articles')
          .select(_articleSelect)
          .eq('status', 'published')
          .eq('category', category)
          .order('published_at', ascending: false);
    } else {
      res = await client
          .from('articles')
          .select(_articleSelect)
          .eq('status', 'published')
          .order('published_at', ascending: false);
    }
    return res;
  }

  static Future<List<Map<String, dynamic>>> getArticleApprovals(
      String contentId) async {
    try {
      final res = await client
          .from('approvals')
          .select('stage, reviewer_id, has_suggestion, '
              'reviewer:profiles!reviewer_id(full_name, profile_picture_url, '
              'specialist_profiles(specialization))')
          .eq('content_id', contentId)
          .eq('decision', 'approve')
          .eq('superseded', false)
          .order('stage', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  static Future<Set<String>> getLikedArticleIds(List<String> articleIds) async {
    final user = currentUser;
    if (user == null || articleIds.isEmpty) return {};
    final res = await client
        .from('article_likes')
        .select('article_id')
        .eq('user_id', user.id)
        .inFilter('article_id', articleIds);
    return List<Map<String, dynamic>>.from(res)
        .map((r) => r['article_id'] as String)
        .toSet();
  }

  static Future<void> likeArticle(String articleId) async {
    final user = currentUser;
    if (user == null) return;
    await client
        .from('article_likes')
        .insert({'article_id': articleId, 'user_id': user.id});
  }

  static Future<void> unlikeArticle(String articleId) async {
    final user = currentUser;
    if (user == null) return;
    await client
        .from('article_likes')
        .delete()
        .eq('article_id', articleId)
        .eq('user_id', user.id);
  }

  static Future<List<Map<String, dynamic>>> getReviewGroups() async {
    final res = await client
        .from('review_groups')
        .select('*')
        .order('id', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getSpecialties() async {
    final res = await client
        .from('specialties')
        .select('*')
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Map<String, dynamic>?> getMyPrimaryGroup() async {
    final user = currentUser;
    if (user == null) return null;
    final profile = await client
        .from('specialist_profiles')
        .select('specialty_id')
        .eq('user_id', user.id)
        .maybeSingle();
    final specialtyId = profile?['specialty_id'] as int?;
    if (specialtyId == null) return null;
    final rows = await client
        .from('specialty_group_map')
        .select('group_id, review_groups(id, name)')
        .eq('specialty_id', specialtyId)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first['review_groups'] as Map<String, dynamic>?;
  }

  static Future<List<Map<String, dynamic>>> getSecondaryGroupsFor(
      int primaryGroupId) async {
    final rows = await client
        .from('group_secondary_map')
        .select(
            'secondary_group_id, review_groups!secondary_group_id(id, name)')
        .eq('primary_group_id', primaryGroupId);
    return List<Map<String, dynamic>>.from(rows)
        .map((r) => r['review_groups'] as Map<String, dynamic>)
        .toList();
  }

  static Future<List<String>> getSpecialtiesForGroup(int groupId) async {
    final rows = await client
        .from('specialty_group_map')
        .select('specialties(name)')
        .eq('group_id', groupId);
    return List<Map<String, dynamic>>.from(rows)
        .map((r) =>
            (r['specialties'] as Map<String, dynamic>?)?['name'] as String?)
        .whereType<String>()
        .toList()
      ..sort();
  }

  static const trimesterTags = [
    '1st Trimester',
    '2nd Trimester',
    '3rd Trimester'
  ];

  static (String, int?) _deriveCategoryAndTrimester(List<String> tags) {
    final category = tags.firstWhere((t) => !trimesterTags.contains(t),
        orElse: () => 'General');
    int? trimester;
    for (var i = 0; i < trimesterTags.length; i++) {
      if (tags.contains(trimesterTags[i])) {
        trimester = i + 1;
        break;
      }
    }
    return (category, trimester);
  }

  static Future<List<String>> getLearnTags() async {
    final res = await client
        .from('learn_tags')
        .select('label')
        .order('sort_order');
    return List<Map<String, dynamic>>.from(res)
        .map((r) => r['label'] as String)
        .toList();
  }

  static Future<Map<String, dynamic>> createArticleDraft({
    required String title,
    required String content,
    required int primaryGroupId,
    required List<String> tags,
  }) async {
    final user = currentUser;
    final slug =
        '${title.toLowerCase().replaceAll(RegExp(r"[^a-z0-9\s-]"), '').trim().replaceAll(RegExp(r'\s+'), '-')}-${DateTime.now().millisecondsSinceEpoch}';
    final (category, trimester) = _deriveCategoryAndTrimester(tags);
    final res = await client
        .from('articles')
        .insert({
          'title': title,
          'slug': slug,
          'content': content,
          'category': category,
          'trimester': trimester,
          'tags': tags,
          'primary_group_id': primaryGroupId,
          'status': 'draft',
          'created_by': user?.id,
        })
        .select()
        .single();
    return res;
  }

  static Future<void> submitContentForReview(String contentId) async {
    await client.rpc('resubmit_content', params: {'p_content_id': contentId});
  }

  static Future<List<Map<String, dynamic>>> getMyArticleSubmissions() async {
    final user = currentUser;
    if (user == null) return [];
    final res = await client
        .from('articles')
        .select('*, author:profiles!created_by(full_name, profile_picture_url, '
            'specialist_profiles(specialization))')
        .eq('created_by', user.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<int> getPublishedArticlesCountForUser(String userId) async {
    try {
      final res = await client
          .from('articles')
          .select('id')
          .eq('created_by', userId)
          .eq('status', 'published');
      return List.from(res).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> getMyPublishedArticlesCount() async {
    final user = currentUser;
    if (user == null) return 0;
    return getPublishedArticlesCountForUser(user.id);
  }

  static Future<int> getReviewActionsCountForUser(String userId) async {
    try {
      final res = await client
          .from('approvals')
          .select('content_id')
          .eq('reviewer_id', userId);
      final contentIds = List<Map<String, dynamic>>.from(res)
          .map((row) => row['content_id'])
          .whereType<Object>()
          .toSet();
      return contentIds.length;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> getMyReviewActionsCount() async {
    final user = currentUser;
    if (user == null) return 0;
    return getReviewActionsCountForUser(user.id);
  }

  static Future<void> deleteArticleDraft(String id) async {
    await client.from('articles').delete().eq('id', id);
  }

  static Future<void> updateArticleDraft(
    String id, {
    required String title,
    required String content,
    required List<String> tags,
  }) async {
    await client.rpc('edit_article_content', params: {
      'p_content_id': id,
      'p_title': title,
      'p_content': content,
      'p_tags': tags,
    });
  }

  static Future<List<Map<String, dynamic>>> getReviewQueue() async {
    final res = await client.rpc('get_review_queue');
    return List<Map<String, dynamic>>.from(res);
  }

  static const _reviewThreadSelect = '*, '
      'approvals(*, reviewer:profiles!reviewer_id(full_name, profile_picture_url, specialist_profiles(specialization))), '
      'article_edit_history(*), '
      'author:profiles!created_by(full_name, profile_picture_url, specialist_profiles(specialization))';

  static Future<Map<String, dynamic>?> getReviewThreadContent(
      String contentId) async {
    final res = await client
        .from('articles')
        .select(_reviewThreadSelect)
        .eq('id', contentId)
        .maybeSingle();
    return res;
  }

  static Future<List<Map<String, dynamic>>> getReviewComments(
      String contentId) async {
    final res = await client
        .from('review_comments')
        .select('*, profiles(full_name, profile_picture_url)')
        .eq('content_id', contentId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> postReviewComment(String contentId, String body,
      {String? approvalId, String? parentCommentId}) async {
    final user = currentUser;
    await client.from('review_comments').insert({
      'content_id': contentId,
      'author_id': user?.id,
      'body': body,
      if (approvalId != null) 'approval_id': approvalId,
      if (parentCommentId != null) 'parent_comment_id': parentCommentId,
    });
  }

  static Future<void> approveContent(String contentId, int stage) async {
    await client.rpc('approve_content',
        params: {'p_content_id': contentId, 'p_stage': stage});
  }

  static Future<void> approveContentWithSuggestion(
      String contentId, int stage, String comment) async {
    await client.rpc('approve_content_with_suggestion', params: {
      'p_content_id': contentId,
      'p_stage': stage,
      'p_comment': comment,
    });
  }

  static Future<void> rejectContent(
      String contentId, int stage, String category, String reason) async {
    await client.rpc('reject_content', params: {
      'p_content_id': contentId,
      'p_stage': stage,
      'p_category': category,
      'p_reason': reason,
    });
  }

  static Future<void> resolveReviewIssue(
      String approvalId, String reply) async {
    await client.rpc('resolve_review_issue', params: {
      'p_approval_id': approvalId,
      'p_reply': reply,
    });
  }

  static Future<void> triggerEmergencyPending(
      String contentId, String category, String reason) async {
    await client.rpc('trigger_emergency_pending', params: {
      'p_content_id': contentId,
      'p_category': category,
      'p_reason': reason,
    });
  }

  static Future<List<Map<String, dynamic>>> getPublicComments(
      String contentId) async {
    final res = await client
        .from('public_comments')
        .select('*, profiles(full_name, profile_picture_url)')
        .eq('content_id', contentId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> postPublicComment(String contentId, String body,
      {String? parentCommentId}) async {
    final user = currentUser;
    await client.from('public_comments').insert({
      'content_id': contentId,
      'user_id': user?.id,
      'body': body,
      'parent_comment_id': parentCommentId,
    });
  }

  static Future<void> deletePublicComment(String id) async {
    await client.from('public_comments').delete().eq('id', id);
  }

  static Future<List<Map<String, dynamic>>> getTestimonials() async {
    final res = await client
        .from('testimonials')
        .select('*')
        .eq('is_published', true)
        .order('review_date', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> ensureRatingNotification({
    required String mumId,
    required String providerId,
    required String providerType,
    required String providerName,
    required String sourceType,
    required String sourceId,
  }) async {
    try {
      final alreadyRated = await client
          .from('provider_ratings')
          .select('id')
          .eq('mum_id', mumId)
          .eq('source_type', sourceType)
          .eq('source_id', sourceId)
          .maybeSingle();
      if (alreadyRated != null) return;

      final alreadyPrompted = await client
          .from('notifications')
          .select('id')
          .eq('user_id', mumId)
          .eq('rating_source_type', sourceType)
          .eq('rating_source_id', sourceId)
          .maybeSingle();
      if (alreadyPrompted != null) return;

      final isSpecialist = providerType == 'specialist';
      await client.from('notifications').insert({
        'user_id': mumId,
        'type': 'consultation',
        'title': isSpecialist ? 'Rate Dr $providerName' : 'Rate $providerName',
        'message': isSpecialist
            ? 'How was your consultation with Dr. $providerName?'
            : 'How was your chat with $providerName?',
        'rating_provider_id': providerId,
        'rating_provider_type': providerType,
        'rating_source_type': sourceType,
        'rating_source_id': sourceId,
      });
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getProviderRatings(
      String providerId) async {
    final res = await client
        .from('provider_ratings')
        .select('*, mum:profiles!mum_id(full_name,profile_picture_url)')
        .eq('provider_id', providerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> submitProviderRating({
    required String providerId,
    required String providerType,
    required String sourceType,
    required String sourceId,
    required int rating,
    String? notificationId,
  }) async {
    final user = currentUser;
    if (user == null) return;
    await client.from('provider_ratings').insert({
      'mum_id': user.id,
      'provider_id': providerId,
      'provider_type': providerType,
      'source_type': sourceType,
      'source_id': sourceId,
      'rating': rating,
    });
    if (notificationId != null) {
      await client.from('notifications').delete().eq('id', notificationId);
    }
  }

  static Future<List<Map<String, dynamic>>> getConsultations() async {
    final user = currentUser;
    if (user == null) return [];
    final res = await client
        .from('consultations')
        .select('*')
        .or('patient_id.eq.${user.id},specialist_id.eq.${user.id}')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getConsultationsForPatient(
      String patientId) async {
    try {
      final res = await client
          .from('consultations')
          .select('*')
          .eq('patient_id', patientId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  static Future<Set<String>> getBookedConsultationSlots(
    List<String> specialistIds,
    DateTime date,
  ) async {
    if (specialistIds.isEmpty) return {};
    final dateString =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final rows = await client.rpc('get_booked_consultation_slots', params: {
      'p_specialist_ids': specialistIds,
      'p_date': dateString,
    });
    return List<Map<String, dynamic>>.from(rows as List)
        .map((row) => row['scheduled_time']?.toString() ?? '')
        .where((time) => time.isNotEmpty)
        .toSet();
  }

  static Future<void> bookConsultation(Map<String, dynamic> data) async {
    final user = currentUser;
    if (user == null) return;
    try {
      await client.from('consultations').insert({
        ...data,
        'patient_id': user.id,
        'status': 'pending',
        'created_at': dbNow(),
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception(
            'That time slot is no longer available. Please choose a different time.');
      }
      rethrow;
    }
  }

  static Future<void> postVolunteerQuestion(String question) async {
    final user = currentUser;
    if (user == null) return;
    await client.from('volunteer_requests').insert({
      'patient_id': user.id,
      'question': question,
      'status': 'pending',
    });
  }

  static Future<void> updateVolunteerQuestion(
      String id, String question) async {
    final res = await client
        .from('volunteer_requests')
        .update({'question': question})
        .eq('id', id)
        .select();
    if (res.isEmpty) {
      throw Exception('Could not update — it may have already been answered.');
    }
  }

  static Future<List<Map<String, dynamic>>> getMyVolunteerQuestions() async {
    final user = currentUser;
    if (user == null) return [];
    try {
      final res = await client
          .from('volunteer_requests')
          .select()
          .eq('patient_id', user.id)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getRequestMessages(
      String requestId) async {
    final res = await client
        .from('volunteer_request_messages')
        .select()
        .eq('request_id', requestId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> sendRequestMessage(
      String requestId, String message) async {
    final user = currentUser;
    if (user == null) return;
    await client.from('volunteer_request_messages').insert({
      'request_id': requestId,
      'sender_id': user.id,
      'message': message,
    });
  }

  static Future<bool> claimAndReplyToRequest(
      String requestId, String message) async {
    final user = currentUser;
    if (user == null) return false;
    final claimed = await client
        .from('volunteer_requests')
        .update({'volunteer_id': user.id, 'status': 'responded'})
        .eq('id', requestId)
        .isFilter('volunteer_id', null)
        .select();
    if (claimed.isEmpty) return false;
    await sendRequestMessage(requestId, message);
    return true;
  }

  static Future<void> closeRequestChat(Map<String, dynamic> request) async {
    final requestId = request['id'].toString();
    await client
        .from('volunteer_requests')
        .update({'status': 'closed'}).eq('id', requestId);

    final mumId = request['patient_id']?.toString();
    final volunteerId = request['volunteer_id']?.toString();
    if (mumId == null || volunteerId == null) return;
    final volunteerProfile = await getProfileById(volunteerId);
    final volunteerName =
        volunteerProfile?['full_name'] as String? ?? 'Volunteer';
    await ensureRatingNotification(
      mumId: mumId,
      providerId: volunteerId,
      providerType: 'volunteer',
      providerName: volunteerName,
      sourceType: 'chat',
      sourceId: requestId,
    );
  }

  static Future<void> requestVideoCall(
      String requestId, DateTime scheduledDate, String scheduledTime) async {
    final user = currentUser;
    if (user == null) return;
    await client.from('volunteer_requests').update({
      'call_status': 'requested',
      'call_requested_by': user.id,
      'call_requested_at': dbNow(),
      'scheduled_date': dateOnly(scheduledDate),
      'scheduled_time': scheduledTime,
    }).eq('id', requestId);
  }

  static Future<void> declineVideoCall(String requestId) async {
    await client
        .from('volunteer_requests')
        .update({'call_status': 'declined'}).eq('id', requestId);
  }

  static Future<Set<String>> getHeldCallTimesForDate(DateTime date) async {
    final user = currentUser;
    if (user == null) return {};
    final cutoff = DateTime.now().subtract(const Duration(hours: 48));
    final dateStr = dateOnly(date);
    try {
      final rows = await client
          .from('volunteer_requests')
          .select('scheduled_time, call_requested_at, call_status')
          .eq('volunteer_id', user.id)
          .neq('status', 'closed')
          .eq('scheduled_date', dateStr)
          .inFilter('call_status', ['requested', 'accepted']);
      return List<Map<String, dynamic>>.from(rows)
          .where((r) {
            if (r['call_status'] == 'accepted') return true;
            final requestedAt =
                DateTime.tryParse(r['call_requested_at']?.toString() ?? '');
            return requestedAt != null && requestedAt.isAfter(cutoff);
          })
          .map((r) => r['scheduled_time'] as String)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> expireStaleCallRequests(
      List<Map<String, dynamic>> requests) async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 48));
    final stale = requests.where((r) {
      if (r['call_status'] != 'requested') return false;
      final requestedAt =
          DateTime.tryParse(r['call_requested_at']?.toString() ?? '');
      return requestedAt != null && requestedAt.isBefore(cutoff);
    }).toList();
    if (stale.isEmpty) return;
    final staleIds = stale.map((r) => r['id'].toString()).toList();
    try {
      await client
          .from('volunteer_requests')
          .update({'call_status': 'none'}).inFilter('id', staleIds);
      for (final r in stale) {
        r['call_status'] = 'none';
      }
    } catch (_) {}
  }

  static Future<String> acceptVideoCall(String requestId) async {
    final response = await client.functions.invoke(
      'create-zoom-meeting-volunteer-call',
      body: {'request_id': requestId},
    );
    final data = response.data;
    final link = data is Map ? data['meeting_link']?.toString() : null;
    if (link == null || link.isEmpty) {
      final error = data is Map
          ? (data['error']?.toString() ?? 'Could not create the Zoom meeting.')
          : 'Could not create the Zoom meeting.';
      throw Exception(error);
    }
    return link;
  }

  static Future<void> sendMeetingLink(String requestId, String link) async {
    await client
        .from('volunteer_requests')
        .update({'meeting_link': link}).eq('id', requestId);
  }

  static Future<void> autoCloseStaleRequests(
      List<Map<String, dynamic>> requests) async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 48));
    final stale = requests.where((r) {
      if (r['status'] != 'responded') return false;
      final last = DateTime.tryParse(r['last_activity_at']?.toString() ??
          r['created_at']?.toString() ??
          '');
      return last != null && last.isBefore(cutoff);
    }).toList();
    if (stale.isEmpty) return;
    final staleIds = stale.map((r) => r['id'].toString()).toList();
    try {
      await client
          .from('volunteer_requests')
          .update({'status': 'closed'}).inFilter('id', staleIds);
      for (final r in stale) {
        r['status'] = 'closed';
      }
      await Future.wait(stale.map((r) async {
        final mumId = r['patient_id']?.toString();
        final volunteerId = r['volunteer_id']?.toString();
        if (mumId == null || volunteerId == null) return;
        final volunteerProfile = await getProfileById(volunteerId);
        final volunteerName =
            volunteerProfile?['full_name'] as String? ?? 'Volunteer';
        await ensureRatingNotification(
          mumId: mumId,
          providerId: volunteerId,
          providerType: 'volunteer',
          providerName: volunteerName,
          sourceType: 'chat',
          sourceId: r['id'].toString(),
        );
      }));
    } catch (_) {}
  }

  static Future<void> cancelConsultation(String id, {String? reason}) async {
    final res = await client
        .from('consultations')
        .update({
          'status': 'cancelled',
          'cancellation_reason':
              reason?.trim().isEmpty == true ? null : reason?.trim(),
        })
        .eq('id', id)
        .select();
    if (res.isEmpty) {
      throw Exception(
          'Could not cancel this consultation — you may not have permission to.');
    }
  }

  static Future<void> updateConsultationStatus(String id, String status) async {
    final res = await client
        .from('consultations')
        .update({'status': status})
        .eq('id', id)
        .select();
    if (res.isEmpty) {
      throw Exception('Could not update consultation status.');
    }
  }

  static Future<void> rescheduleConsultation(
    String id, {
    required String scheduledDate,
    required String scheduledTime,
    String? previousScheduledDate,
    String? previousScheduledTime,
  }) async {
    try {
      final res = await client
          .from('consultations')
          .update({
            'scheduled_date': scheduledDate,
            'scheduled_time': scheduledTime,
            'status': 'pending',
            'meeting_link': null,
            'previous_scheduled_date': previousScheduledDate,
            'previous_scheduled_time': previousScheduledTime,
            'rescheduled_at': dbNow(),
          })
          .eq('id', id)
          .select();
      if (res.isEmpty) {
        throw Exception(
            'Could not reschedule this consultation — you may not have permission to.');
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception(
            'That time slot is no longer available. Please choose a different time.');
      }
      rethrow;
    }
  }

  static Future<String> approveConsultation(String id) async {
    final response = await client.functions.invoke(
      'create-zoom-meeting',
      body: {'consultation_id': id},
    );
    final data = response.data;
    final link = data is Map ? data['meeting_link']?.toString() : null;
    if (link == null || link.isEmpty) {
      final error = data is Map
          ? (data['error']?.toString() ?? 'Could not create the Zoom meeting.')
          : 'Could not create the Zoom meeting.';
      throw Exception(error);
    }
    return link;
  }

  static Future<String> createServiceZoomMeeting({
    required String title,
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    final response = await client.functions.invoke(
      'create-zoom-meeting-service',
      body: {
        'title': title,
        'date': dateOnly(date),
        'start_time': startTime,
        'end_time': endTime,
      },
    );
    final data = response.data;
    final link = data is Map ? data['meeting_link']?.toString() : null;
    if (link == null || link.isEmpty) {
      final error = data is Map
          ? (data['error']?.toString() ?? 'Could not create the Zoom meeting.')
          : 'Could not create the Zoom meeting.';
      throw Exception(error);
    }
    return link;
  }

  static Future<Map<String, dynamic>?> getProviderProfile(String userId) async {
    try {
      final spec = await client
          .from('specialist_profiles')
          .select('*, profiles(full_name, email, profile_picture_url)')
          .eq('user_id', userId)
          .maybeSingle();
      if (spec != null) return {...spec, 'provider_type': 'specialist'};
    } catch (_) {}
    try {
      final vol = await client
          .from('volunteer_profiles')
          .select('*, profiles(full_name, email, profile_picture_url)')
          .eq('user_id', userId)
          .maybeSingle();
      if (vol != null) return {...vol, 'provider_type': 'volunteer'};
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> getLinkedMum() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      final link = await client
          .from('next_of_kin_profiles')
          .select(
              'relationship, mum:linked_pregnant_user_id(id, full_name, email, role, subscription_plan)')
          .eq('user_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      final mum = link?['mum'] as Map<String, dynamic>?;
      if (mum == null) return null;

      int? week;
      DateTime? weekStartDate;
      try {
        final pp = await client
            .from('pregnancy_profiles')
            .select('due_date, current_week')
            .eq('user_id', mum['id'])
            .maybeSingle()
            .timeout(const Duration(seconds: 6));
        final dueDateStr = pp?['due_date'] as String?;
        if (dueDateStr != null) {
          final due = sgtDateFrom(dueDateStr);
          if (due != null) {
            final conception = due.subtract(const Duration(days: 280));
            week = (sgtNow().difference(conception).inDays ~/ 7).clamp(1, 42);
            weekStartDate = conception.add(Duration(days: week * 7));
          }
        }
        week ??= (pp?['current_week'] as num?)?.toInt();
      } catch (_) {}

      return {
        'id': mum['id'],
        'full_name': mum['full_name'],
        'email': mum['email'],
        'relationship': link?['relationship'],
        'current_week': week,
        'current_week_start_date': weekStartDate?.toIso8601String(),
        'role': mum['role'],
        'subscription_plan': mum['subscription_plan'],
      };
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> _findMumByUserCode(
      String userCode) async {
    final mum = await client
        .from('profiles')
        .select('id, full_name, role')
        .eq('user_code', userCode)
        .maybeSingle()
        .timeout(const Duration(seconds: 6));
    if (mum == null) throw Exception('User code not found.');

    final role = mum['role'] as String?;
    if (role != 'free_user' && role != 'premium_user') {
      throw Exception('This code does not belong to a registered mum.');
    }
    return mum;
  }

  static Future<Map<String, dynamic>> verifyMumUserCode(String userCode) {
    return _findMumByUserCode(userCode);
  }

  static Future<String> linkToMum(String userCode, String relationship) async {
    final user = currentUser;
    if (user == null) throw Exception('Not signed in.');

    final mum = await _findMumByUserCode(userCode);

    await client.from('next_of_kin_profiles').delete().eq('user_id', user.id);
    await client.from('next_of_kin_profiles').insert({
      'user_id': user.id,
      'linked_pregnant_user_id': mum['id'],
      'relationship': relationship,
    });

    return mum['full_name'] as String? ?? 'Mum';
  }

  static Future<void> updateNextOfKinRelationship(String relationship) async {
    final user = currentUser;
    if (user == null) throw Exception('Not signed in.');
    final res = await client
        .from('next_of_kin_profiles')
        .update({'relationship': relationship})
        .eq('user_id', user.id)
        .select();
    if (res.isEmpty) {
      throw Exception('Could not update — you may not be linked yet.');
    }
  }

  static Future<List<Map<String, dynamic>>> getSpecialists() async {
    final res = await client
        .from('specialist_profiles')
        .select('*, profiles(full_name, email, profile_picture_url)')
        .eq('is_verified', true);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getVolunteers() async {
    final res = await client
        .from('volunteer_profiles')
        .select('*, profiles(full_name, email, profile_picture_url)')
        .eq('is_verified', true);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Map<String, ({double average, int count})>>
      getProviderRatingSummaries(String providerType) async {
    try {
      final res = await client
          .from('provider_ratings')
          .select('provider_id, rating')
          .eq('provider_type', providerType);
      final sums = <String, num>{};
      final counts = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(res)) {
        final id = row['provider_id']?.toString();
        final rating = (row['rating'] as num?)?.toDouble();
        if (id == null || rating == null) continue;
        sums[id] = (sums[id] ?? 0) + rating;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return {
        for (final id in counts.keys)
          id: (average: sums[id]! / counts[id]!, count: counts[id]!),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<List<Map<String, dynamic>>> getVolunteerServices(
      String volunteerId) async {
    try {
      final res = await client
          .from('volunteer_services')
          .select()
          .eq('volunteer_id', volunteerId)
          .eq('status', 'available');
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getMySpecialistProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return getSpecialistProfileByUserId(user.id);
  }

  static Future<Map<String, dynamic>?> getSpecialistProfileByUserId(
      String userId) async {
    try {
      final res = await client
          .from('specialist_profiles')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();
      return res;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getMyVolunteerProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return getVolunteerProfileByUserId(user.id);
  }

  static Future<Map<String, dynamic>?> getVolunteerProfileByUserId(
      String userId) async {
    try {
      final res = await client
          .from('volunteer_profiles')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();
      return res;
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateVolunteerProfile(Map<String, dynamic> data) async {
    final user = currentUser;
    if (user == null) return;

    final existing = await client
        .from('volunteer_profiles')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing != null) {
      await client
          .from('volunteer_profiles')
          .update(data)
          .eq('user_id', user.id);
    } else {
      await client.from('volunteer_profiles').insert({
        'user_id': user.id,
        'expertise': '', // satisfies NOT NULL
        'is_verified': false,
        ...data,
      });
    }
  }

  static Future<void> updateSpecialistProfile(Map<String, dynamic> data) async {
    final user = currentUser;
    if (user == null) return;

    final existing = await client
        .from('specialist_profiles')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing != null) {
      final res = await client
          .from('specialist_profiles')
          .update(data)
          .eq('user_id', user.id)
          .select();
      if (res.isEmpty) {
        throw Exception(
            'Could not update your profile — you may not have permission to.');
      }
    } else {
      final res = await client.from('specialist_profiles').insert({
        'user_id': user.id,
        'specialization': '', // satisfies NOT NULL
        'is_verified': false,
        ...data,
      }).select();
      if (res.isEmpty) {
        throw Exception(
            'Could not create your profile — you may not have permission to.');
      }
    }
  }

  static Future<Map<String, String>> getSiteSettings() async {
    final res =
        await client.from('site_settings').select('setting_key, setting_value');
    final map = <String, String>{};
    for (final row in res) {
      map[row['setting_key']] = row['setting_value'] ?? '';
    }
    return map;
  }

  static Future<List<Map<String, dynamic>>> getForumPosts() async {
    final res = await client
        .from('forum_posts')
        .select(
            '*, profiles!forum_posts_author_id_fkey(full_name, role, profile_picture_url, volunteer_profiles(expertise)), forum_comments(count), forum_likes(count)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Set<String>> getLikedPostIds(List<String> postIds) async {
    final user = currentUser;
    if (user == null || postIds.isEmpty) return {};
    final res = await client
        .from('forum_likes')
        .select('post_id')
        .eq('user_id', user.id)
        .inFilter('post_id', postIds);
    return res.map((r) => r['post_id'] as String).toSet();
  }

  static Future<void> createForumPost(String content) async {
    final user = currentUser;
    if (user == null) return;
    await client.from('forum_posts').insert({
      'author_id': user.id,
      'content': content,
    });
  }

  static Future<void> updateForumPost(String id, String content) async {
    final updated = await client
        .from('forum_posts')
        .update({'content': content})
        .eq('id', id)
        .select('id');
    if (updated.isEmpty) {
      throw Exception(
          'Post could not be updated — you may need to sign in again.');
    }
  }

  static Future<void> deleteForumPost(String id) async {
    final deleted =
        await client.from('forum_posts').delete().eq('id', id).select('id');
    if (deleted.isEmpty) {
      throw Exception(
          'Post could not be deleted — you may need to sign in again.');
    }
  }

  static Future<void> likeForumPost(String postId) async {
    final user = currentUser;
    if (user == null) return;
    await client
        .from('forum_likes')
        .insert({'post_id': postId, 'user_id': user.id});
  }

  static Future<void> unlikeForumPost(String postId) async {
    final user = currentUser;
    if (user == null) return;
    await client
        .from('forum_likes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', user.id);
  }

  static Future<List<Map<String, dynamic>>> getForumComments(
      String postId) async {
    final res = await client
        .from('forum_comments')
        .select('*, profiles(full_name, role, profile_picture_url)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> createForumComment(String postId, String content) async {
    final user = currentUser;
    if (user == null) return;
    await client.from('forum_comments').insert({
      'post_id': postId,
      'author_id': user.id,
      'content': content,
    });
  }

  static Future<void> deleteForumComment(String id) async {
    await client.from('forum_comments').delete().eq('id', id);
  }

  static Future<List<Map<String, dynamic>>> getMyDailyReminders() async {
    final user = currentUser;
    if (user == null) return [];

    try {
      await client.rpc('ensure_my_daily_reminders');
    } catch (_) {}

    try {
      final today = sgtToday();
      final res = await client
          .from('daily_reminder_sends')
          .select(
              'id, created_at, template:template_id(title, subtitle_template, icon_name, display_order)')
          .eq('user_id', user.id)
          .eq('sent_date', today)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getChecklistTemplates() async {
    final res = await client
        .from('checklist_templates')
        .select('*')
        .order('display_order');
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getOrCreateChecklistItems() async {
    final user = currentUser;
    if (user == null) return [];

    var items = List<Map<String, dynamic>>.from(await client
        .from('checklist_items')
        .select('*')
        .eq('user_id', user.id)
        .order('display_order'));

    if (items.isEmpty) {
      final templates = await getChecklistTemplates();
      if (templates.isNotEmpty) {
        await client.from('checklist_items').insert([
          for (final t in templates)
            {
              'user_id': user.id,
              'template_item_id': t['id'],
              'phase': t['phase'],
              'phase_emoji': t['phase_emoji'],
              'category': t['category'],
              'item_text': t['item_text'],
              'display_order': t['display_order'],
            }
        ]);
        items = List<Map<String, dynamic>>.from(await client
            .from('checklist_items')
            .select('*')
            .eq('user_id', user.id)
            .order('display_order'));
      }
    }
    return items;
  }

  static Future<void> setChecklistItemCompleted(
      String id, bool completed) async {
    await client
        .from('checklist_items')
        .update({'is_completed': completed}).eq('id', id);
  }

  static Future<void> updateChecklistItemText(String id, String text) async {
    await client
        .from('checklist_items')
        .update({'item_text': text}).eq('id', id);
  }

  static Future<void> deleteChecklistItem(String id) async {
    await client.from('checklist_items').delete().eq('id', id);
  }

  static Future<void> addChecklistItem({
    required String phase,
    required String phaseEmoji,
    required String category,
    required String itemText,
    required int displayOrder,
  }) async {
    final user = currentUser;
    if (user == null) return;
    await client.from('checklist_items').insert({
      'user_id': user.id,
      'phase': phase,
      'phase_emoji': phaseEmoji,
      'category': category,
      'item_text': itemText,
      'display_order': displayOrder,
    });
  }
}
