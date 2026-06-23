import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/module.dart';

class AppDrawer extends StatelessWidget {
  final AppModule currentModule;
  final void Function(AppModule module) onModuleSelected;
  final VoidCallback onSignOut;

  const AppDrawer({
    Key? key,
    required this.currentModule,
    required this.onModuleSelected,
    required this.onSignOut,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final visibleModules = AppModule.all
        .where((module) => module.isAccessibleFor(state.currentUser?.role))
        .toList();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Argmac ERP',
                    style: Theme.of(context).textTheme.headline6?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.currentUser?.fullName ?? 'Guest',
                    style: Theme.of(context).textTheme.bodyText2,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.currentUser?.role.toUpperCase() ?? 'GUEST',
                    style: Theme.of(context).textTheme.caption,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: visibleModules.length,
                itemBuilder: (context, index) {
                  final module = visibleModules[index];
                  final active = module.route == currentModule.route;
                  return ListTile(
                    leading: Icon(
                      module.icon,
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(module.name),
                    subtitle: Text(
                      module.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: active,
                    onTap: () => onModuleSelected(module),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ElevatedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
