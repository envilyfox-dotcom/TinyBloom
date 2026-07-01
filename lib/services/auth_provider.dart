import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Single shared instance so the router (refreshListenable) and the
/// Provider tree above the widget tree observe the same object.
final authProvider = AuthProvider();

class AuthProvider extends ChangeNotifier {
  User? _user;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _needsOnboarding = false;

  User? get user => _user;
  Map<String, dynamic>? get profile => _profile;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  bool get needsOnboarding => _needsOnboarding;
  String get role => _profile?['role'] ?? '';
  bool get isPremium => role == 'premium_user';
  String? get subscriptionPlan => _profile?['subscription_plan'] as String?;
  bool get isMum => role == 'free_user' || role == 'premium_user';
  bool get isAdmin => role == 'admin';
  bool get isSpecialist => role == 'specialist';
  bool get isVolunteer => role == 'volunteer';

  AuthProvider() {
    _init();
  }

  void _init() {
    // Synchronous check — no waiting for a stream event.
    _user = SupabaseService.currentUser;

    // Load profile then release the loading gate, with a hard 5s cap.
    Future.microtask(() async {
      if (_user != null) {
        try {
          await _loadProfile().timeout(const Duration(seconds: 5), onTimeout: () {});
        } catch (_) {}
      }
      _applyMetaFallback();
      _loading = false;
      notifyListeners();
    });

    // Keep listening for sign-in / sign-out events after initial load.
    SupabaseService.client.auth.onAuthStateChange.listen((data) async {
      _user = data.session?.user;
      if (_user != null) {
        try {
          await _loadProfile().timeout(const Duration(seconds: 5), onTimeout: () {});
        } catch (_) {}
        _applyMetaFallback();
      } else {
        _profile = null;
        _needsOnboarding = false;
      }
      _loading = false;
      notifyListeners();
    });
  }

  void _applyMetaFallback() {
    if (_profile == null && _user != null) {
      final meta = _user!.userMetadata;
      if (meta != null) {
        _profile = {'full_name': meta['full_name'], 'role': meta['role']};
      }
    }
  }

  Future<void> _loadProfile() async {
    try {
      _profile = await SupabaseService.getProfile();
    } catch (_) {
      _profile = null;
    }
    // Fall back to JWT metadata so isMum works even if profiles table is inaccessible.
    if (_profile == null && _user != null) {
      final meta = _user!.userMetadata;
      if (meta != null) {
        _profile = {'full_name': meta['full_name'], 'role': meta['role']};
      }
    }
    try {
      if (isMum) {
        final pp = await SupabaseService.getPregnancyProfile();
        _needsOnboarding = pp == null;
      } else {
        _needsOnboarding = false;
      }
    } catch (_) {
      _needsOnboarding = false;
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      final res = await SupabaseService.signIn(email, password);
      _user = res.user;
      if (_user != null) await _loadProfile();
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An error occurred. Please try again.';
    }
  }

  Future<String?> signOut() async {
    try {
      await SupabaseService.signOut();
      _user = null;
      _profile = null;
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> refreshProfile() async {
    await _loadProfile();
    notifyListeners();
  }
}
