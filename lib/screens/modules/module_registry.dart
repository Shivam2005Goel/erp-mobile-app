import 'package:flutter/material.dart';

import 'access_module.dart';
import 'attendance_module.dart';
import 'crm_module.dart';
import 'designer_module.dart';
import 'home_module.dart';
import 'hr_module.dart';
import 'inventory_module.dart';
import 'marketing_module.dart';
import 'orders_module.dart';
import 'production_module.dart';
import 'seo_module.dart';
import 'tickets_module.dart';

/// Maps a dashboard route to its live module view.
Widget buildModuleView(String route) {
  switch (route) {
    case '/dashboard/home':
      return HomeModule();
    case '/dashboard/access':
      return const AccessModule();
    case '/dashboard/hr':
      return HrModule();
    case '/dashboard/inventory':
      return InventoryModule();
    case '/dashboard/sales':
      return CrmModule();
    case '/dashboard/orders':
      return OrdersModule();
    case '/dashboard/marketing':
      return MarketingModule();
    case '/dashboard/seo':
      return SeoModule();
    case '/dashboard/attendance':
      return AttendanceModule();
    case '/dashboard/tickets':
      return TicketsModule();
    case '/dashboard/designer':
      return const DesignerModule();
    case '/dashboard/production':
      return ProductionModule();
    default:
      return const Center(
        child: Text('Select a workspace module from the menu.'),
      );
  }
}
