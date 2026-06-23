import 'package:flutter/material.dart';

class AppModule {
  final String name;
  final String route;
  final String? role;
  final List<String> extraRoles;
  final String description;
  final IconData icon;

  const AppModule({
    required this.name,
    required this.route,
    this.role,
    this.extraRoles = const [],
    required this.description,
    required this.icon,
  });

  bool isAccessibleFor(String? roleKey) {
    if (roleKey == 'admin') return true;
    if (roleKey == 'operations') {
      return _operationsPaths.contains(route);
    }
    if (roleKey == 'designer') {
      return _designerPaths.contains(route);
    }
    if (extraRoles.contains(roleKey)) return true;
    if (role == null) return true;
    return roleKey == role;
  }

  static const _operationsPaths = [
    '/dashboard/hr',
    '/dashboard/inventory',
    '/dashboard/sales',
    '/dashboard/orders',
    '/dashboard/production',
    '/dashboard/attendance',
    '/dashboard/designer',
  ];

  static const _designerPaths = [
    '/dashboard/designer',
    '/dashboard/inventory',
    '/dashboard/sales',
    '/dashboard/orders',
    '/dashboard/production',
    '/dashboard/attendance',
  ];

  static const all = [
    AppModule(
      name: 'Team & HR',
      route: '/dashboard/hr',
      role: 'hr',
      description: 'Employee records, attendance, and team activity.',
      icon: Icons.people,
    ),
    AppModule(
      name: 'Inventory',
      route: '/dashboard/inventory',
      role: 'inventory',
      description: 'Stock controls, categories, and supply pipeline.',
      icon: Icons.inventory_2,
    ),
    AppModule(
      name: 'Marketing',
      route: '/dashboard/marketing',
      role: 'marketing',
      description: 'Campaign analytics, ads, and audience reach.',
      icon: Icons.campaign,
    ),
    AppModule(
      name: 'SEO Analytics',
      route: '/dashboard/seo',
      role: 'marketing',
      description: 'Keyword performance, backlinks, and rankings.',
      icon: Icons.search,
    ),
    AppModule(
      name: 'Pending Tasks',
      route: '/dashboard/production',
      role: 'production',
      description: 'Cross-department task tracker and approvals.',
      icon: Icons.factory,
    ),
    AppModule(
      name: 'Attendance',
      route: '/dashboard/attendance',
      role: null,
      description: 'Daily attendance monitoring and CSV upload support.',
      icon: Icons.calendar_today,
    ),
    AppModule(
      name: 'Sales & CRM',
      route: '/dashboard/sales',
      role: 'sales',
      extraRoles: ['marketing'],
      description: 'Opportunities, contacts, and luxury pipeline management.',
      icon: Icons.trending_up,
    ),
    AppModule(
      name: 'Order Management',
      route: '/dashboard/orders',
      role: 'sales',
      description: 'Order intake, fulfillment status, and pending materials.',
      icon: Icons.receipt_long,
    ),
    AppModule(
      name: 'Support Tickets',
      route: '/dashboard/tickets',
      role: null,
      description: 'After-sales support ticket workflow and status updates.',
      icon: Icons.support_agent,
    ),
    AppModule(
      name: 'Designer',
      route: '/dashboard/designer',
      role: null,
      description: 'Design uploads, approvals, and creative assets.',
      icon: Icons.palette,
    ),
  ];

  static AppModule? findByRoute(String route) {
    return all.firstWhere(
      (module) => module.route == route,
      orElse: () => AppModule(
        name: 'Dashboard',
        route: '/dashboard',
        role: null,
        description: 'Select a workspace module from the navigation menu.',
        icon: Icons.dashboard,
      ),
    );
  }

  static String homePathForRole(String? roleKey) {
    switch (roleKey) {
      case 'admin':
      case 'hr':
        return '/dashboard/hr';
      case 'inventory':
        return '/dashboard/inventory';
      case 'marketing':
        return '/dashboard/marketing';
      case 'sales':
        return '/dashboard/sales';
      case 'production':
      case 'operations':
        return '/dashboard/production';
      case 'designer':
        return '/dashboard/designer';
      default:
        return '/dashboard/attendance';
    }
  }
}
