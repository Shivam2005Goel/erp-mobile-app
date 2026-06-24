import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';
import 'models/user_profile.dart';

class SupabaseService {
  static late final SupabaseClient client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true,
    );
    client = Supabase.instance.client;
  }

  static Future<UserProfile> signUp(
    String email,
    String password,
    String fullName,
    String role,
  ) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      options: AuthOptions(data: {'full_name': fullName, 'role': role}),
    );

    if (response.error != null) {
      throw Exception(response.error!.message);
    }

    final user = response.user;
    if (user == null) {
      throw Exception('Unable to register user.');
    }

    final profileResponse = await client.from(supabaseProfileTable).insert({
      'id': user.id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'approved': true,
      'created_at': DateTime.now().toIso8601String(),
    }).execute();

    if (profileResponse.error != null) {
      throw Exception(profileResponse.error!.message);
    }

    return UserProfile(
      id: user.id,
      fullName: fullName,
      email: email,
      role: role,
      createdAt: DateTime.now(),
      approved: true,
      password: null,
    );
  }

  static Future<UserProfile> signIn(String email, String password) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.error != null) {
      throw Exception(response.error!.message);
    }

    final user = response.user;
    if (user == null) {
      throw Exception('Unable to sign in.');
    }

    final profileResult = await client
        .from(supabaseProfileTable)
        .select('*')
        .eq('id', user.id)
        .single()
        .execute();

    if (profileResult.error != null) {
      throw Exception(profileResult.error!.message);
    }

    final data = profileResult.data as Map<String, dynamic>;
    return UserProfile(
      id: user.id,
      fullName: data['full_name'] as String? ?? '',
      email: data['email'] as String? ?? email,
      role: data['role'] as String? ?? 'operations',
      approved: data['approved'] as bool? ?? true,
      createdAt: DateTime.parse(
        data['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      password: null,
    );
  }

  static Future<UserProfile> signInWithGoogle() async {
    final response = await client.auth.signInWithProvider(
      Provider.google,
      options: AuthOptions(redirectTo: 'io.supabase.flutter://login-callback/'),
    );

    if (response.error != null) {
      throw Exception(response.error!.message);
    }

    if (response.session == null || response.session?.user == null) {
      throw Exception(
        'Google sign-in flow started. Complete the authentication in the browser.',
      );
    }

    final user = response.session!.user!;
    final profileResult = await client
        .from(supabaseProfileTable)
        .select('*')
        .eq('id', user.id)
        .single()
        .execute();

    if (profileResult.error != null) {
      throw Exception(profileResult.error!.message);
    }

    final data = profileResult.data as Map<String, dynamic>;
    return UserProfile(
      id: user.id,
      fullName:
          data['full_name'] as String? ??
          user.userMetadata?['full_name'] as String? ??
          '',
      email: data['email'] as String? ?? user.email ?? '',
      role: data['role'] as String? ?? 'operations',
      approved: data['approved'] as bool? ?? true,
      createdAt: DateTime.parse(
        data['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      password: null,
    );
  }

  static Future<UserProfile?> fetchProfile(String userId) async {
    final profileResult = await client
        .from(supabaseProfileTable)
        .select('*')
        .eq('id', userId)
        .single()
        .execute();

    if (profileResult.error != null) {
      return null;
    }

    final data = profileResult.data as Map<String, dynamic>;
    return UserProfile(
      id: data['id'] as String,
      fullName: data['full_name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'operations',
      approved: data['approved'] as bool? ?? true,
      createdAt: DateTime.parse(
        data['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      password: null,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}
