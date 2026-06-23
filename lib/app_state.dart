import 'dart:async';

import 'package:flutter/material.dart';

import 'models/module.dart';
import 'models/user_profile.dart';

class AppState extends ChangeNotifier {
  UserProfile? currentUser;
  bool loading = false;
  String? authError;
  String? pendingApprovalEmail;

  final List<UserProfile> _users = [
    UserProfile(
      id: 'admin-1',
      fullName: 'Argmac Administrator',
      email: 'admin@argmac.com',
      role: 'admin',
      approved: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1400)),
      password: 'Admin@123',
    ),
  ];

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
    await Future.delayed(const Duration(milliseconds: 500));
    final found = _users.firstWhere(
      (user) => user.email.toLowerCase() == email.toLowerCase(),
      orElse: () => throw Exception('No account found for this email.'),
    );
    if (!found.approved) {
      _setLoading(false);
      throw Exception('Registration pending approval.');
    }
    if (found.password != password) {
      _setLoading(false);
      throw Exception('Invalid email or password.');
    }
    currentUser = found;
    authError = null;
    pendingApprovalEmail = null;
    _setLoading(false);
  }

  Future<String> signUpWithEmail(
    String email,
    String password,
    String fullName,
    String role,
  ) async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 500));
    final normalized = email.toLowerCase();
    final existing = _users
        .where((user) => user.email.toLowerCase() == normalized)
        .toList();
    if (existing.isNotEmpty && existing.first.approved) {
      _setLoading(false);
      throw Exception('A registered account already exists.');
    }
    final profile = UserProfile(
      id: 'user-${_users.length + 1}',
      fullName: fullName,
      email: normalized,
      role: role,
      approved: false,
      createdAt: DateTime.now(),
      password: password,
    );
    _users.removeWhere((user) => user.email.toLowerCase() == normalized);
    _users.add(profile);
    pendingApprovalEmail = normalized;
    currentUser = null;
    authError = null;
    _setLoading(false);
    return 'pending';
  }

  Future<void> signInWithGoogle() async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 600));
    const googleEmail = 'google.user@argmac.com';
    final existing = _users.firstWhere(
      (user) => user.email.toLowerCase() == googleEmail,
      orElse: () => null,
    );
    if (existing == null) {
      final profile = UserProfile(
        id: 'guser-${_users.length + 1}',
        fullName: 'Google Guest',
        email: googleEmail,
        role: 'sales',
        approved: false,
        createdAt: DateTime.now(),
        password: 'google-oauth',
      );
      _users.add(profile);
      pendingApprovalEmail = googleEmail;
      currentUser = null;
      authError = null;
      _setLoading(false);
      return;
    }
    if (!existing.approved) {
      pendingApprovalEmail = googleEmail;
      currentUser = null;
      authError = null;
      _setLoading(false);
      return;
    }
    currentUser = existing;
    pendingApprovalEmail = null;
    authError = null;
    _setLoading(false);
  }

  void signOut() {
    currentUser = null;
    authError = null;
    pendingApprovalEmail = null;
    notifyListeners();
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
