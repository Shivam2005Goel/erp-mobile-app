import 'dart:async';

import 'package:flutter/material.dart';

import 'models/module.dart';
import 'models/user_profile.dart';
import 'supabase_service.dart';

class AppState extends ChangeNotifier {
  UserProfile? currentUser;
  bool loading = false;
  String? authError;

  AppState();

  static const availableRoles = [
    'admin',
    'hr',
    'inventory',
    'marketing',
    'production',
    'sales',
    'operations',
    'designer',
  ];

  void clearError() {
    authError = null;
    notifyListeners();
  }

  Future<void> signInWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      currentUser = await SupabaseService.signIn(email, password);
      authError = null;
    } catch (err) {
      authError = err.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<String> signUpWithEmail(
    String email,
    String password,
    String fullName,
    String role,
  ) async {
    _setLoading(true);
    try {
      await SupabaseService.signUp(email, password, fullName, role);
      authError = null;
      return 'approved';
    } catch (err) {
      authError = err.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signInWithGoogle() async {
    _setLoading(true);
    try {
      currentUser = await SupabaseService.signInWithGoogle();
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
    authError = null;
    notifyListeners();
  }

  Future<void> restoreSession() async {
    _setLoading(true);
    try {
      final session = SupabaseService.client.auth.currentSession;
      if (session?.user != null) {
        currentUser = await SupabaseService.fetchProfile(session!.user!.id);
      }
    } finally {
      _setLoading(false);
    }
  }

  bool canAccessCurrentModule(AppModule module) {
    return module.isAccessibleFor(currentUser?.role);
  }

  String dashboardHomeRoute() {
    return AppModule.homePathForRole(currentUser?.role);
  }

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
