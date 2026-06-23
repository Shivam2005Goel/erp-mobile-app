import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/auth_login_screen.dart';
import 'screens/auth_register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/pending_approval_screen.dart';

void main() {
  runApp(const ArgmacApp());
}

class ArgmacApp extends StatefulWidget {
  const ArgmacApp({Key? key}) : super(key: key);

  @override
  State<ArgmacApp> createState() => _ArgmacAppState();
}

class _ArgmacAppState extends State<ArgmacApp> {
  final appState = AppState();

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: appState,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Argmac ERP',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFf37021)),
          scaffoldBackgroundColor: Colors.grey[50],
          textTheme: Typography.blackMountainView,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const LandingScreen(),
          '/login': (context) => const AuthLoginScreen(),
          '/register': (context) => const AuthRegisterScreen(),
          '/pending': (context) => const PendingApprovalScreen(),
          '/dashboard': (context) => const DashboardScreen(),
        },
      ),
    );
  }
}
