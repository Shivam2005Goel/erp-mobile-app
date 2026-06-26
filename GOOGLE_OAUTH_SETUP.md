# Google OAuth — Setup & How It Works

Google sign-in is fully implemented in the app. The **only** remaining step is one
configuration entry in the Supabase dashboard (it cannot be set from code).

## 1. Required: whitelist the mobile redirect URL

The app sends users back from Google via this deep link:

```
argmacerp://login-callback
```

In the Supabase dashboard for project **ERP-Argmac** (`ejufkodfjynwtaqlrswv`):

1. **Authentication → URL Configuration → Redirect URLs** → **Add URL**
2. Add exactly: `argmacerp://login-callback`
3. Save.

> The web app already enables the Google provider on this project, so
> **Authentication → Providers → Google** should already be ON. If it is not,
> enable it and paste the Google OAuth **Client ID** and **Client Secret** from
> the [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
> (Authorized redirect URI there must be
> `https://ejufkodfjynwtaqlrswv.supabase.co/auth/v1/callback`).

## 2. Already configured in this repo (no action needed)

| Platform | Where | Scheme |
| --- | --- | --- |
| Android | `android/app/src/main/AndroidManifest.xml` (intent-filter) | `argmacerp` / host `login-callback` |
| iOS | `ios/Runner/Info.plist` (`CFBundleURLTypes`) | `argmacerp` |
| Dart | `lib/supabase_config.dart` (`oauthRedirectUrl`) | `argmacerp://login-callback` |

For **web** builds, no scheme is needed — add your web origin (e.g.
`http://localhost:PORT`) to the same Supabase Redirect URLs list instead.

## 3. The flow (matches the Next.js web app)

1. User taps **Continue with Google** on the login screen.
2. `SupabaseService.signInWithGoogle()` opens the Google consent page in the
   external browser.
3. Google redirects to `argmacerp://login-callback#access_token=…`; the OS hands
   the deep link back to the app and `supabase_flutter` completes the session.
4. `AppState.initAuthListener()` (a `auth.onAuthStateChange` subscription) fires:
   - **Existing approved employee** → goes straight to the dashboard.
   - **Pending / rejected** → signed out, routed to the approval-waiting screen.
   - **First-time Google user** (no `final_employees` row) → routed to the
     **role-selection screen** to pick a department, which creates a `pending`
     profile and signs them out to await admin approval.

## 4. Run

```bash
flutter run            # Android emulator / device or iOS simulator
```
