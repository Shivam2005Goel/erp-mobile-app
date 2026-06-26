import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/module.dart';
import '../widgets/app_drawer.dart';
import '../widgets/notification_bell.dart';
import 'modules/module_registry.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AppModule _currentModule = AppModule.all.first;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inherited widgets (AppStateScope) are only safe to read here, not in
    // initState(). Set the landing module once.
    if (!_initialized) {
      _initialized = true;
      final state = AppStateScope.of(context);
      _currentModule = AppModule.findByRoute(state.dashboardHomeRoute());
    }
  }

  void _navigateToModule(AppModule module) {
    setState(() {
      _currentModule = module;
    });
    Navigator.pop(context);
  }

  /// Switches the active module by route (used by notification deep-links).
  void _navigateToRoute(String route) {
    final base = route.split('?').first;
    setState(() => _currentModule = AppModule.findByRoute(base));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (state.currentUser == null) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentModule.name),
        actions: [
          NotificationBell(onNavigate: _navigateToRoute),
          IconButton(
            icon: Icon(state.themeMode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            tooltip: state.themeMode == ThemeMode.dark
                ? 'Light mode'
                : 'Dark mode',
            onPressed: state.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () {
              state.signOut();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),
      drawer: AppDrawer(
        currentModule: _currentModule,
        onModuleSelected: _navigateToModule,
        onSignOut: () {
          state.signOut();
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        },
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _ModuleView(module: _currentModule),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleView extends StatelessWidget {
  final AppModule module;
  const _ModuleView({required this.module});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final accessible = state.canAccessCurrentModule(module);
    return accessible
        ? buildModuleView(module.route)
        : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64),
                const SizedBox(height: 18),
                Text(
                  'System gating triggered',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your assigned credentials permit clearance only within your department. This module is restricted.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    final homeModule = AppModule.findByRoute(
                      state.dashboardHomeRoute(),
                    );
                    Navigator.pushReplacementNamed(
                      context,
                      '/dashboard',
                      arguments: homeModule,
                    );
                  },
                  child: const Text('Return to Home Portal'),
                ),
              ],
            ),
          );
  }
}
