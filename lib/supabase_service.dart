import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';
import 'models/user_profile.dart';

/// Auth + profile service. Mirrors the Next.js `AuthContext`: profiles live in
/// the `final_employees` table (keyed by `auth_user_id`) and are gated on
/// `approval_status` ('pending' / 'approved' / 'rejected').
class SupabaseService {
  static late final SupabaseClient client;
  static const String profileTable = 'final_employees';

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    client = Supabase.instance.client;
  }

  static SupabaseClient get db => client;

  /// Loads the workspace departments for the registration role picker.
  static Future<List<Department>> fetchDepartments() async {
    final rows = await client
        .from('departments')
        .select('department_id, department_name')
        .order('department_id');
    return (rows as List)
        .map((e) => Department.fromMap(e as Map<String, dynamic>))
        .where((d) => d.name.trim().isNotEmpty)
        .toList();
  }

  static Future<int?> _departmentIdForRole(String role) async {
    final res = await client
        .from('departments')
        .select('department_id')
        .ilike('department_name', role)
        .maybeSingle();
    return (res?['department_id'] as num?)?.toInt();
  }

  static Future<UserProfile?> fetchProfile(String authUserId) async {
    final data = await client
        .from(profileTable)
        .select(
            'auth_user_id, full_name, email, role, created_at, approval_status, employee_id')
        .eq('auth_user_id', authUserId)
        .maybeSingle();
    return data == null ? null : UserProfile.fromMap(data);
  }

  /// Registers a user and creates a pending `final_employees` row, then signs
  /// them out (they must wait for admin approval). Returns 'pending'.
  static Future<String> signUp(
    String email,
    String password,
    String fullName,
    String role,
  ) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': role},
    );
    final user = response.user;
    if (user == null) throw Exception('Registration failed.');

    final departmentId = await _departmentIdForRole(role);
    await client.from(profileTable).upsert({
      'auth_user_id': user.id,
      'full_name': fullName,
      'email': email,
      'role': role,
      'department_id': departmentId,
      'approval_status': 'pending',
      'status': 'active',
      'type': 'permanent',
    }, onConflict: 'auth_user_id');

    // User must wait for approval — don't leave them signed in.
    await client.auth.signOut();
    return 'pending';
  }

  /// Signs in and enforces the approval gate. Throws a friendly message and
  /// signs the user back out if they are still pending or were rejected.
  static Future<UserProfile> signIn(String email, String password) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) throw Exception('Unable to sign in.');

    final profile = await fetchProfile(user.id);
    if (profile == null) {
      await client.auth.signOut();
      throw Exception(
          'No employee profile found for this account. Contact an admin.');
    }
    if (profile.isPending) {
      await client.auth.signOut();
      throw Exception('PENDING'); // sentinel handled by AppState
    }
    if (profile.isRejected) {
      await client.auth.signOut();
      throw Exception('Your access request was rejected. Contact an admin.');
    }
    return profile;
  }

  /// Restores a profile for an already-authenticated session, applying the
  /// same approval gate.
  static Future<UserProfile?> restoreProfile() async {
    final session = client.auth.currentSession;
    final user = session?.user;
    if (user == null) return null;
    final profile = await fetchProfile(user.id);
    if (profile == null || !profile.isApproved) {
      await client.auth.signOut();
      return null;
    }
    return profile;
  }

  /// Launches the Google OAuth flow. On mobile, control returns to the app via
  /// the [oauthRedirectUrl] deep link; on web it redirects in-page. The
  /// resulting session is delivered through `auth.onAuthStateChange`, which
  /// `AppState` listens to.
  static Future<void> signInWithGoogle() async {
    await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : oauthRedirectUrl,
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  /// First-time Google users have no `final_employees` row yet. Once they pick
  /// a department this creates their pending profile and signs them out to
  /// await admin approval — mirroring the web app's `updateGoogleUserRole`.
  static Future<void> registerGoogleProfile(String role) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('No authenticated Google user.');

    final departmentId = await _departmentIdForRole(role);
    await client.from(profileTable).upsert({
      'auth_user_id': user.id,
      'full_name': user.userMetadata?['full_name'] ??
          user.userMetadata?['name'] ??
          (user.email ?? '').split('@').first,
      'email': user.email,
      'role': role,
      'department_id': departmentId,
      'approval_status': 'pending',
      'status': 'active',
      'type': 'permanent',
    }, onConflict: 'auth_user_id');

    await client.auth.signOut();
  }

  static Future<void> signOut() => client.auth.signOut();
}
