import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_theme.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      publishableKey: AppConstants.supabaseAnonKey,
    );
  }

  // Auth
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

  // Profile
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

  // Profile picture — stored in the public 'avatars' bucket at
  // <user_id>/avatar.<ext>, one file per user (upsert overwrites any
  // previous picture, so there's nothing extra to clean up on re-upload).
  static Future<String> uploadProfilePicture(Uint8List bytes, String fileExt) async {
    final user = currentUser;
    if (user == null) throw Exception('Not signed in.');

    final ext = fileExt.toLowerCase();
    final path = '${user.id}/avatar.$ext';
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    await client.storage.from('avatars').uploadBinary(
        path, bytes,
        fileOptions: FileOptions(upsert: true, contentType: contentType));

    // Cache-bust so the new photo shows immediately instead of a
    // browser/CDN-cached copy of whatever used to be at this path.
    final url =
        '${client.storage.from('avatars').getPublicUrl(path)}?t=${DateTime.now().millisecondsSinceEpoch}';
    await updateProfile({'profile_picture_url': url});
    return url;
  }

  static Future<void> removeProfilePicture() async {
    final user = currentUser;
    if (user == null) return;
    await updateProfile({'profile_picture_url': null});
    try {
      final files = await client.storage.from('avatars').list(path: user.id);
      final paths = files.map((f) => '${user.id}/${f.name}').toList();
      if (paths.isNotEmpty) await client.storage.from('avatars').remove(paths);
    } catch (_) {
      // Best-effort cleanup — profile_picture_url is already cleared either way.
    }
  }

  // Subscription — there's no real payment gateway wired up, so "upgrading"
  // just records the chosen plan and flips the role. Passing null cancels.
  static Future<void> setSubscriptionPlan(String? plan) async {
    await updateProfile({
      'subscription_plan': plan,
      'role': plan == null ? 'free_user' : 'premium_user',
    });
  }

  // Same as setSubscriptionPlan, but for a next-of-kin gifting premium to
  // the mum they're linked to, rather than subscribing themselves. Goes
  // through the gift_subscription_to_linked_mum RPC rather than a direct
  // table update — that function checks the link and touches only
  // subscription_plan/role, instead of relying on a table-wide UPDATE grant
  // that could otherwise let a next-of-kin write any column on the row.
  static Future<void> giftSubscriptionPlan(String mumId, String plan) async {
    await client.rpc('gift_subscription_to_linked_mum', params: {
      'mum_id': mumId,
      'plan': plan,
    });
  }

  // Pregnancy profile
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
      final dueDate = DateTime.tryParse(data['due_date']);
      if (dueDate != null) {
        final daysUntilDue = dueDate.difference(DateTime.now()).inDays;
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

  // Current pregnancy week, derived from due_date (preferred) or the stored
  // weeks_pregnant snapshot. Shared by any screen that needs "what week is
  // it" without duplicating the calculation.
  static Future<int> getCurrentPregnancyWeek() async {
    try {
      final data = await getPregnancyProfile();
      if (data == null) return 0;
      if (data['due_date'] != null) {
        final due = DateTime.parse(data['due_date']);
        final daysUntilDue = due.difference(DateTime.now()).inDays;
        return ((280 - daysUntilDue) / 7).floor().clamp(1, 40);
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
    final conception = data['due_date'] != null
        ? DateTime.tryParse(data['due_date'])
            ?.subtract(const Duration(days: 280))
        : null;
    final week = conception != null
        ? DateTime.now().difference(conception).inDays ~/ 7
        : null;
    await client.from('pregnancy_profiles').upsert(
      {
        'user_id': user.id,
        if (data['due_date'] != null) 'due_date': data['due_date'],
        if (week != null) 'current_week': week.clamp(1, 42),
      },
      onConflict: 'user_id',
    );
  }

  static Future<void> updateDueDate(DateTime dueDate) async {
    final user = currentUser;
    if (user == null) return;
    final conception = dueDate.subtract(const Duration(days: 280));
    final week = DateTime.now().difference(conception).inDays ~/ 7;
    await client.from('pregnancy_profiles').upsert(
      {
        'user_id': user.id,
        'due_date': dueDate.toIso8601String().split('T').first,
        'current_week': week.clamp(1, 42),
      },
      onConflict: 'user_id',
    );
  }

  // Health logs
  static Future<List<Map<String, dynamic>>> getLogs() async {
    final user = currentUser;
    if (user == null) return [];
    try {
      final res = await client
          .from('health_logs')
          .select('*')
          .eq('user_id', user.id)
          .order('logged_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  static Future<void> createLog(Map<String, dynamic> data) async {
    final user = currentUser;
    if (user == null) return;
    await client.from('health_logs').insert({
      ...data,
      'user_id': user.id,
      'logged_at': data['logged_at'] ?? DateTime.now().toIso8601String(),
      'log_date':
          data['log_date'] ?? DateTime.now().toIso8601String().split('T').first,
    });
  }

  static Future<void> updateLog(String id, Map<String, dynamic> data) async {
    await client.from('health_logs').update(data).eq('id', id);
  }

  static Future<void> deleteLog(String id) async {
    await client.from('health_logs').delete().eq('id', id);
  }

  // FAQs
  static Future<List<Map<String, dynamic>>> getFaqs({String? category}) async {
    List<Map<String, dynamic>> res;
    if (category != null) {
      res = await client
          .from('faqs')
          .select('*')
          .eq('is_published', true)
          .eq('category', category)
          .order('display_order');
    } else {
      res = await client
          .from('faqs')
          .select('*')
          .eq('is_published', true)
          .order('display_order');
    }
    return res;
  }

  // Articles
  static Future<List<Map<String, dynamic>>> getArticles(
      {String? category}) async {
    List<Map<String, dynamic>> res;
    if (category != null) {
      res = await client
          .from('articles')
          .select('*')
          .eq('status', 'published')
          .eq('category', category)
          .order('published_at', ascending: false);
    } else {
      res = await client
          .from('articles')
          .select('*')
          .eq('status', 'published')
          .order('published_at', ascending: false);
    }
    return res;
  }

  // ── Specialist article review pipeline ──────────────────────────────
  // See Article_System_specialist.md. All state transitions (submit,
  // approve, reject, emergency-pending) go through the security-definer RPC
  // functions in add_review_pipeline_functions.sql — the client never writes
  // `status`/`approvals`/`emergency_pending_clicks` rows directly.

  static Future<List<Map<String, dynamic>>> getReviewGroups() async {
    final res = await client.from('review_groups').select('*').order('id');
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getSpecialties() async {
    final res = await client.from('specialties').select('*').order('name');
    return List<Map<String, dynamic>>.from(res);
  }

  // The current specialist's primary review group, derived from their
  // specialty (specialist_profiles.specialty_id -> specialty_group_map),
  // never chosen manually — see Article_System_specialist.md §2.
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
    // specialty_group_map is many-to-many at the schema level (future-
    // proofing per the doc), but every specialty maps to exactly one group
    // today — take the first if there's ever more than one row.
    final rows = await client
        .from('specialty_group_map')
        .select('group_id, review_groups(id, name)')
        .eq('specialty_id', specialtyId)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first['review_groups'] as Map<String, dynamic>?;
  }

  // Existing category tags, sourced from the same published articles shown
  // on the Learn tab — so specialists pick from what's actually in use
  // there instead of typing free text.
  static Future<List<String>> getArticleCategories() async {
    final articles = await getArticles();
    final cats = <String>{};
    for (final a in articles) {
      final c = a['category'] as String?;
      if (c != null && c.trim().isNotEmpty) cats.add(c.trim());
    }
    final list = cats.toList()..sort();
    return list;
  }

  static Future<Map<String, dynamic>> createArticleDraft({
    required String title,
    required String content,
    required int primaryGroupId,
    required String category,
    int? trimester,
  }) async {
    final user = currentUser;
    final slug =
        '${title.toLowerCase().replaceAll(RegExp(r"[^a-z0-9\s-]"), '').trim().replaceAll(RegExp(r'\s+'), '-')}-${DateTime.now().millisecondsSinceEpoch}';
    final res = await client.from('articles').insert({
      'title': title,
      'slug': slug,
      'content': content,
      'category': category,
      'trimester': trimester,
      'primary_group_id': primaryGroupId,
      'status': 'draft',
      'created_by': user?.id,
    }).select().single();
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
        .select('*')
        .eq('created_by', user.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> deleteArticleDraft(String id) async {
    await client.from('articles').delete().eq('id', id);
  }

  static Future<List<Map<String, dynamic>>> getReviewQueue() async {
    final res = await client.rpc('get_review_queue');
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Map<String, dynamic>?> getReviewThreadContent(
      String contentId) async {
    final res = await client
        .from('articles')
        .select('*, approvals(*), author:profiles!created_by(full_name)')
        .eq('id', contentId)
        .maybeSingle();
    return res;
  }

  static Future<List<Map<String, dynamic>>> getReviewComments(
      String contentId) async {
    final res = await client
        .from('review_comments')
        .select('*, profiles(full_name)')
        .eq('content_id', contentId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> postReviewComment(String contentId, String body,
      {String? approvalId}) async {
    final user = currentUser;
    await client.from('review_comments').insert({
      'content_id': contentId,
      'author_id': user?.id,
      'body': body,
      if (approvalId != null) 'approval_id': approvalId,
    });
  }

  static Future<void> approveContent(String contentId, int stage) async {
    await client.rpc('approve_content',
        params: {'p_content_id': contentId, 'p_stage': stage});
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
        .select('*, profiles(full_name)')
        .eq('content_id', contentId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> postPublicComment(String contentId, String body) async {
    final user = currentUser;
    await client.from('public_comments').insert({
      'content_id': contentId,
      'user_id': user?.id,
      'body': body,
    });
  }

  // Testimonials
  static Future<List<Map<String, dynamic>>> getTestimonials() async {
    final res = await client
        .from('testimonials')
        .select('*')
        .eq('is_published', true)
        .order('review_date', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  // Consultations
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

  // Best-effort: a linked mum's consultations, for the next-of-kin
  // dashboard's Active Alerts. Depending on RLS this may come back empty
  // rather than erroring, so it's wrapped defensively.
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

  static Future<void> bookConsultation(Map<String, dynamic> data) async {
    final user = currentUser;
    if (user == null) return;
    await client.from('consultations').insert({
      ...data,
      'patient_id': user.id,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Cancelling marks the row as "cancelled" rather than deleting it, so the
  // specialist still sees it (as a Cancelled entry) instead of it vanishing
  // outright. .select() so we get back the rows that were actually updated —
  // an UPDATE blocked by a missing RLS policy doesn't throw by default, it
  // just silently affects zero rows, which would otherwise look like a
  // successful cancel that didn't actually happen.
  static Future<void> cancelConsultation(String id, {String? reason}) async {
    final res = await client
        .from('consultations')
        .update({
          'status': 'cancelled',
          'cancellation_reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
        })
        .eq('id', id)
        .select();
    if (res.isEmpty) {
      throw Exception(
          'Could not cancel this consultation — you may not have permission to.');
    }
  }

  static Future<void> updateConsultationStatus(
      String id, String status) async {
    final res = await client
        .from('consultations')
        .update({'status': status})
        .eq('id', id)
        .select();
    if (res.isEmpty) {
      throw Exception('Could not update consultation status.');
    }
  }

  // Looks up the specialist/volunteer profile (+ name) for a consultation's
  // other party, trying specialist_profiles first then volunteer_profiles.
  static Future<Map<String, dynamic>?> getProviderProfile(String userId) async {
    try {
      final spec = await client
          .from('specialist_profiles')
          .select('*, profiles(full_name, email)')
          .eq('user_id', userId)
          .maybeSingle();
      if (spec != null) return {...spec, 'provider_type': 'specialist'};
    } catch (_) {}
    try {
      final vol = await client
          .from('volunteer_profiles')
          .select('*, profiles(full_name, email)')
          .eq('user_id', userId)
          .maybeSingle();
      if (vol != null) return {...vol, 'provider_type': 'volunteer'};
    } catch (_) {}
    return null;
  }

  // Next of kin — the mum this next-of-kin account is linked to, via the
  // next_of_kin_profiles table (user_id -> linked_pregnant_user_id).
  static Future<Map<String, dynamic>?> getLinkedMum() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      final link = await client
          .from('next_of_kin_profiles')
          .select('relationship, mum:linked_pregnant_user_id(id, full_name, email)')
          .eq('user_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      final mum = link?['mum'] as Map<String, dynamic>?;
      if (mum == null) return null;

      // Best-effort: the linked mum's own pregnancy_profiles row may not be
      // readable depending on RLS, so a missing week just means we show none.
      int? week;
      try {
        final pp = await client
            .from('pregnancy_profiles')
            .select('due_date, current_week')
            .eq('user_id', mum['id'])
            .maybeSingle()
            .timeout(const Duration(seconds: 6));
        final dueDateStr = pp?['due_date'] as String?;
        if (dueDateStr != null) {
          final due = DateTime.tryParse(dueDateStr);
          if (due != null) {
            final conception = due.subtract(const Duration(days: 280));
            week = (DateTime.now().difference(conception).inDays ~/ 7)
                .clamp(1, 42);
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
      };
    } catch (_) {
      return null;
    }
  }

  // Shared lookup for the user_code linking flow — throws a user-facing
  // message if the code doesn't exist or doesn't belong to a mum account.
  static Future<Map<String, dynamic>> _findMumByUserCode(String userCode) async {
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

  // Verifies a user_code belongs to a registered mum, without linking — used
  // to enable the Link button only once the code checks out.
  static Future<Map<String, dynamic>> verifyMumUserCode(String userCode) {
    return _findMumByUserCode(userCode);
  }

  // Looks up a mum by her user_code and links this next-of-kin account to
  // her, replacing any previous link. Throws a user-facing message if the
  // code doesn't exist or doesn't belong to a mum account.
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

  // Specialists & volunteers
  static Future<List<Map<String, dynamic>>> getSpecialists() async {
    final res = await client
        .from('specialist_profiles')
        .select('*, profiles(full_name, email)')
        .eq('is_verified', true);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getVolunteers() async {
    final res = await client
        .from('volunteer_profiles')
        .select('*, profiles(full_name, email)')
        .eq('is_verified', true);
    return List<Map<String, dynamic>>.from(res);
  }

  // Get current specialist's profile (for their own dashboard)
  static Future<Map<String, dynamic>?> getMySpecialistProfile() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      final res = await client
          .from('specialist_profiles')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();
      return res;
    } catch (_) {
      return null;
    }
  }

  // Get current volunteer's profile (for their own dashboard)
  static Future<Map<String, dynamic>?> getMyVolunteerProfile() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      final res = await client
          .from('volunteer_profiles')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();
      return res;
    } catch (_) {
      return null;
    }
  }

  // Update volunteer profile
  static Future<void> updateVolunteerProfile(Map<String, dynamic> data) async {
    final user = currentUser;
    if (user == null) return;

    // Check if a row already exists
    final existing = await client
        .from('volunteer_profiles')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing != null) {
      // Row exists — just update the fields we care about
      await client
          .from('volunteer_profiles')
          .update(data)
          .eq('user_id', user.id);
    } else {
      // No row yet — insert with required fields defaulted
      await client.from('volunteer_profiles').insert({
        'user_id': user.id,
        'expertise': '', // satisfies NOT NULL
        'is_verified': false,
        ...data,
      });
    }
  }

  // Update specialist profile
static Future<void> updateSpecialistProfile(Map<String, dynamic> data) async {
  final user = currentUser;
  if (user == null) return;

  final existing = await client
      .from('specialist_profiles')
      .select('*')
      .eq('user_id', user.id)
      .maybeSingle();

  if (existing != null) {
    // .select() so we can tell a silent RLS-blocked update (0 rows
    // affected, no error thrown) apart from a real success.
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

  // Site settings
  static Future<Map<String, String>> getSiteSettings() async {
    final res =
        await client.from('site_settings').select('setting_key, setting_value');
    final map = <String, String>{};
    for (final row in res) {
      map[row['setting_key']] = row['setting_value'] ?? '';
    }
    return map;
  }

  // Forum
  static Future<List<Map<String, dynamic>>> getForumPosts() async {
    final res = await client
        .from('forum_posts')
        // profiles!forum_posts_author_id_fkey disambiguates from the other
        // path PostgREST finds via forum_likes (which also references both
        // forum_posts and profiles, looking like a many-to-many join).
        .select(
            '*, profiles!forum_posts_author_id_fkey(full_name), forum_comments(count), forum_likes(count)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  // Which of the given posts the current user has already liked.
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

  static Future<void> deleteForumPost(String id) async {
    await client.from('forum_posts').delete().eq('id', id);
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
        .select('*, profiles(full_name)')
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
}
