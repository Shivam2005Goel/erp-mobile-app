import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/auth_login_screen.dart';
import 'screens/auth_register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/pending_approval_screen.dart';
import 'screens/role_selection_screen.dart';
import 'supabase_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  final appState = AppState();
  appState.initAuthListener();
  await appState.loadThemePreference();
  await appState.restoreSession();
  runApp(ArgmacApp(appState: appState));
}

class ArgmacApp extends StatelessWidget {
  final AppState appState;
  const ArgmacApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: appState,
      // Rebuild MaterialApp when the theme mode changes.
      child: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Argmac ERP',
          theme: RhombusTheme.light(),
          darkTheme: RhombusTheme.dark(),
          themeMode: appState.themeMode,
          initialRoute: '/',
          routes: {
            '/': (context) => const LandingScreen(),
            '/login': (context) => const AuthLoginScreen(),
            '/register': (context) => const AuthRegisterScreen(),
            '/pending': (context) => const PendingApprovalScreen(),
            '/role-selection': (context) => const RoleSelectionScreen(),
            '/dashboard': (context) => const DashboardScreen(),
          },
        ),
      ),
    );
  }
}
