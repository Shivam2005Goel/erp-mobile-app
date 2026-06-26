import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/module.dart';
import 'models/user_profile.dart';
import 'supabase_service.dart';

class AppState extends ChangeNotifier {
  UserProfile? currentUser;
  bool loading = false;
  String? authError;

  /// Set after a registration / login attempt that resolves to a pending
  /// account, so the UI can route to the approval-waiting screen.
  String? pendingApprovalEmail;

  /// True when a Google user authenticated successfully but has no
  /// `final_employees` row yet — the UI must collect a department first.
  bool needsRoleSelection = false;
  String? googleEmail;

  List<Department> departments = [];

  /// Light/dark mode, persisted to disk (key 'argmac_theme'), default light —
  /// matching the web app's ThemeContext.
  ThemeMode themeMode = ThemeMode.light;
  static const _themeKey = 'argmac_theme';

  StreamSubscription<AuthState>? _authSub;
  bool _googleFlow = false;

  AppState();

  Future<void> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      themeMode =
          prefs.getString(_themeKey) == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    themeMode =
        themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _themeKey, themeMode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  /// Subscribes to Supabase auth changes so the asynchronous Google OAuth
  /// redirect (which returns via a deep link, not the original Future) is
  /// handled. Call once after `Supabase.initialize`.
  void initAuthListener() {
    _authSub ??= SupabaseService.client.auth.onAuthStateChange.listen((data) {
      // Only react to OAuth returns here; email/password is handled inline by
      // signInWithEmail. Defer the async work so we don't hold GoTrue's lock.
      if (data.event == AuthChangeEvent.signedIn && _googleFlow) {
        Future(() => _handleGoogleSignedIn());
      }
    });
  }

  Future<void> _handleGoogleSignedIn() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await SupabaseService.fetchProfile(user.id);
      if (profile == null) {
        // First-time Google user — needs to choose a department.
        googleEmail = user.email;
        needsRoleSelection = true;
      } else if (profile.isApproved) {
        currentUser = profile;
        needsRoleSelection = false;
        _googleFlow = false;
      } else {
        await SupabaseService.signOut();
        if (profile.isRejected) {
          authError = 'Your access request was rejected. Contact an admin.';
        } else {
          pendingApprovalEmail = user.email;
        }
        _googleFlow = false;
      }
    } catch (err) {
      authError = err.toString().replaceFirst('Exception: ', '');
      _googleFlow = false;
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void clearError() {
    authError = null;
    notifyListeners();
  }

  Future<List<Department>> loadDepartments() async {
    if (departments.isNotEmpty) return departments;
    try {
      departments = await SupabaseService.fetchDepartments();
    } catch (_) {
      departments = [];
    }
    notifyListeners();
    return departments;
  }

  Future<void> signInWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      currentUser = await SupabaseService.signIn(email, password);
      pendingApprovalEmail = null;
      authError = null;
    } catch (err) {
      final msg = err.toString().replaceFirst('Exception: ', '');
      if (msg == 'PENDING') {
        pendingApprovalEmail = email;
        authError = null;
      } else {
        authError = msg;
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Returns 'pending' on success — registration always requires approval.
  Future<String> signUpWithEmail(
    String email,
    String password,
    String fullName,
    String role,
  ) async {
    _setLoading(true);
    try {
      final status =
          await SupabaseService.signUp(email, password, fullName, role);
      pendingApprovalEmail = email;
      authError = null;
      return status;
    } catch (err) {
      authError = err.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Launches Google OAuth. Completion is delivered via [initAuthListener];
  /// callers should react to changes (currentUser / needsRoleSelection /
  /// pendingApprovalEmail) rather than awaiting a result here.
  Future<void> signInWithGoogle() async {
    authError = null;
    pendingApprovalEmail = null;
    needsRoleSelection = false;
    googleEmail = null;
    _googleFlow = true;
    notifyListeners();
    try {
      await SupabaseService.signInWithGoogle();
    } catch (err) {
      _googleFlow = false;
      authError = err.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  /// Completes first-time Google registration with the chosen department,
  /// creating a pending profile and signing the user out to await approval.
  Future<void> completeGoogleRegistration(String role) async {
    _setLoading(true);
    try {
      await SupabaseService.registerGoogleProfile(role);
      pendingApprovalEmail = googleEmail;
      needsRoleSelection = false;
      _googleFlow = false;
      authError = null;
    } catch (err) {
      authError = err.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
    currentUser = null;
    pendingApprovalEmail = null;
    needsRoleSelection = false;
    googleEmail = null;
    _googleFlow = false;
    authError = null;
    notifyListeners();
  }

  Future<void> restoreSession() async {
    _setLoading(true);
    try {
      currentUser = await SupabaseService.restoreProfile();
    } finally {
      _setLoading(false);
    }
  }

  bool canAccessCurrentModule(AppModule module) =>
      module.isAccessibleFor(currentUser?.role);

  String dashboardHomeRoute() =>
      AppModule.homePathForRole(currentUser?.role);

  void _setLoading(bool value) {
    loading = value;
    notifyListeners();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    required AppState notifier,
    required Widget child,
    Key? key,
  }) : super(key: key, notifier: notifier, child: child);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope must wrap the application');
    return scope!.notifier!;
  }
}
