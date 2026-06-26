const String supabaseUrl = 'https://ejufkodfjynwtaqlrswv.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVqdWZrb2Rmanlud3RhcWxyc3d2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyNTQ1MjEsImV4cCI6MjA5NDgzMDUyMX0.aKSm9lFpYEBGqKpnZui0TUnOdKDhpk4Y3ZYZDDubSXc';

/// The table that holds employee profiles (keyed by `auth_user_id`).
const String supabaseProfileTable = 'final_employees';

/// Deep-link scheme used for the Supabase Google OAuth redirect on mobile.
/// This exact value must also be added to the Supabase dashboard under
/// Authentication → URL Configuration → Redirect URLs, and is registered as a
/// URL scheme in AndroidManifest.xml and ios/Runner/Info.plist.
const String oauthRedirectUrl = 'argmacerp://login-callback';
