import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/module.dart';
import '../widgets/app_drawer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AppModule _currentModule = AppModule.all.first;

  @override
  void initState() {
    super.initState();
    final state = AppStateScope.of(context);
    _currentModule = AppModule.findByRoute(state.dashboardHomeRoute());
  }

  void _navigateToModule(AppModule module) {
    setState(() {
      _currentModule = module;
    });
    Navigator.pop(context);
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
          IconButton(
            icon: const Icon(Icons.logout),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Workspace',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currentModule.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    final homePath = state.dashboardHomeRoute();
                    final homeModule = AppModule.findByRoute(homePath);
                    setState(() => _currentModule = homeModule);
                  },
                  child: const Text('Home'),
                ),
              ],
            ),
          ),
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
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome to ${module.name}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                module.description,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: Text(
                    'This module is in progress. Implement the ${module.name} workflows, charts and listings here.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          )
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
