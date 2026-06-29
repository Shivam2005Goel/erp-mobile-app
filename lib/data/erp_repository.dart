import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_service.dart';

/// Central data-access layer. Each method mirrors the equivalent Next.js API
/// route, but talks to Supabase directly (RLS allows anon access on these
/// tables, exactly as the web app relies on).
class ErpRepository {
  SupabaseClient get _db => SupabaseService.client;

  static List<Map<String, dynamic>> _rows(dynamic res) =>
      (res as List).cast<Map<String, dynamic>>();

  // ── Generic CRUD ─────────────────────────────────────────────────
  /// Inserts a row; null-valued keys are stripped so DB defaults apply.
  Future<void> create(String table, Map<String, dynamic> data) async {
    final clean = Map<String, dynamic>.from(data)
      ..removeWhere((k, v) => v == null);
    await _db.from(table).insert(clean);
  }

  /// Updates a row matched by [idCol] == [id].
  /// Null-valued keys are stripped so existing DB values are preserved.
  Future<void> updateRow(
      String table, String idCol, dynamic id, Map<String, dynamic> data) async {
    final clean = Map<String, dynamic>.from(data)
      ..removeWhere((k, v) => v == null);
    if (clean.isEmpty) return;
    await _db.from(table).update(clean).eq(idCol, id);
  }

  /// Deletes a row matched by [idCol] == [id].
  Future<void> deleteRow(String table, String idCol, dynamic id) async {
    await _db.from(table).delete().eq(idCol, id);
  }

  // ── Inventory ────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> inventoryItems() async => _rows(
        await _db
            .from('inventory_items')
            .select('*')
            .order('category', ascending: true)
            .order('sno', ascending: true, nullsFirst: false),
      );

  Future<List<Map<String, dynamic>>> inventoryCategories() async => _rows(
        await _db
            .from('inventory_categories')
            .select('*')
            .order('created_at', ascending: true),
      );

  Future<List<Map<String, dynamic>>> products() async => _rows(
        await _db.from('products').select('*').order('created_at'),
      );

  Future<List<Map<String, dynamic>>> productTypes() async => _rows(
        await _db.from('product_types').select('*'),
      );

  Future<void> createProduct(String name) async =>
      await _db.from('products').insert({'product_name': name});

  Future<void> deleteProduct(String name) async =>
      await _db.from('products').delete().eq('product_name', name);

  Future<void> deleteCategory(String id) async =>
      await _db.from('inventory_categories').delete().eq('id', id);

  // ── Orders ───────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> orders() async => _rows(
        await _db
            .from('orders')
            .select('*')
            .order('created_at', ascending: false),
      );

  Future<List<Map<String, dynamic>>> priorityOrders() async => _rows(
        await _db
            .from('priority_orders')
            .select('*')
            .order('order_date', ascending: false, nullsFirst: false),
      );

  Future<List<Map<String, dynamic>>> pendingMaterials() async => _rows(
        await _db
            .from('pending_materials')
            .select('*')
            .order('created_at', ascending: false),
      );

  // ── HR ───────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> employees() async => _rows(
        await _db
            .from('final_employees')
            .select('*')
            .order('full_name', ascending: true),
      );

  /// Master employee records: every `final_employees` row merged (by email)
  /// with its supplementary `employee_details` (personal/bank/documents) —
  /// mirrors the web app's `/api/employee-details` GET.
  Future<List<Map<String, dynamic>>> employeeRecords() async {
    final results = await Future.wait([
      _db.from('final_employees').select(
          'employee_id, email, full_name, role, status, type, department, joined_on, manager_id'),
      _db.from('employee_details').select('*'),
    ]);
    final emps = _rows(results[0]);
    final details = _rows(results[1]);
    final detailByEmail = <String, Map<String, dynamic>>{};
    for (final d in details) {
      detailByEmail[(d['email'] ?? '').toString().toLowerCase()] = d;
    }
    final merged = <Map<String, dynamic>>[];
    for (final e in emps) {
      final email = (e['email'] ?? '').toString();
      if (email.isEmpty) continue;
      merged.add({...?detailByEmail[email.toLowerCase()], ...e, 'email': email});
    }
    merged.sort((a, b) => (a['full_name'] ?? '')
        .toString()
        .toLowerCase()
        .compareTo((b['full_name'] ?? '').toString().toLowerCase()));
    return merged;
  }

  /// Upserts personal / bank / document-path fields into `employee_details`
  /// (keyed by email).
  Future<void> saveEmployeeDetails(
      String email, Map<String, dynamic> fields) async {
    await _db
        .from('employee_details')
        .upsert({'email': email, ...fields}, onConflict: 'email');
  }

  /// Updates employment fields on the master `final_employees` row (HR/admin).
  Future<void> saveEmployment(
      String email, Map<String, dynamic> fields) async {
    await _db.from('final_employees').update(fields).eq('email', email);
  }

  /// Tasks for a person — matched by employee_id or assigned_to name, exactly
  /// like the web Team view.
  Future<List<Map<String, dynamic>>> employeeTasks(
      {int? employeeId, required String name}) async {
    final rows = _rows(await _db
        .from('tasks')
        .select(
            'id, employee_id, assigned_to, task, status, start_date, end_date, notes')
        .order('created_at', ascending: false));
    final lname = name.toLowerCase();
    return rows.where((t) {
      if (employeeId != null && t['employee_id'] != null) {
        return (t['employee_id'] as num).toInt() == employeeId;
      }
      return (t['assigned_to'] ?? '').toString().toLowerCase() == lname;
    }).toList();
  }

  // ── Employee documents (private 'employee-docs' storage bucket) ───
  static const String _docBucket = 'employee-docs';

  /// Uploads bytes to the employee-docs bucket and returns the stored path.
  Future<String> uploadEmployeeDoc(
      String email, String slug, String fileName, Uint8List bytes,
      {String? contentType}) async {
    final folder = email.replaceAll(RegExp(r'[^a-z0-9]', caseSensitive: false), '_').toLowerCase();
    final path = '$folder/${slug}_${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _db.storage.from(_docBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    return path;
  }

  /// Creates a short-lived signed URL to view a private document.
  Future<String> signedDocUrl(String path) =>
      _db.storage.from(_docBucket).createSignedUrl(path, 600);

  Future<void> removeEmployeeDoc(String path) async {
    await _db.storage.from(_docBucket).remove([path]);
  }

  Future<List<Map<String, dynamic>>> factoryWorkers() async => _rows(
        await _db
            .from('factory_workers')
            .select('*')
            .order('employee_name', ascending: true),
      );

  Future<List<Map<String, dynamic>>> tasks() async => _rows(
        await _db
            .from('tasks')
            .select('*')
            .order('end_date', ascending: true, nullsFirst: false),
      );

  Future<List<Map<String, dynamic>>> leaveRequests() async => _rows(
        await _db
            .from('leave_requests')
            .select('*')
            .order('start_date', ascending: false, nullsFirst: false),
      );

  // ── Sales / CRM ──────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> opportunities() async => _rows(
        await _db
            .from('crm_opportunities')
            .select('*')
            .order('position', ascending: true),
      );

  Future<List<Map<String, dynamic>>> contacts() async => _rows(
        await _db
            .from('crm_contacts')
            .select('*')
            .order('created_at', ascending: false),
      );

  Future<List<Map<String, dynamic>>> clients() async => _rows(
        await _db.from('clients').select('*').order('name', ascending: true),
      );

  Future<List<Map<String, dynamic>>> leads() async => _rows(
        await _db
            .from('leads')
            .select('*')
            .order('sno', ascending: true, nullsFirst: false),
      );

  /// Moves an opportunity to a new pipeline stage (Kanban drag/drop).
  Future<void> updateOpportunityStage(String id, String stage) async {
    await _db.from('crm_opportunities').update({'stage': stage}).eq('id', id);
  }

  // ── Marketing ────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> metaCampaigns() async => _rows(
        await _db
            .from('ads_meta_campaigns')
            .select('*')
            .order('date', ascending: false),
      );

  Future<List<Map<String, dynamic>>> adsCosting() async => _rows(
        await _db
            .from('ads_costing')
            .select('*')
            .order('date', ascending: false),
      );

  Future<List<Map<String, dynamic>>> socialCalendar() async => _rows(
        await _db
            .from('social_media_calendar')
            .select('*')
            .order('publish_date', ascending: true, nullsFirst: false),
      );

  // ── SEO ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> seoDaily() async => _rows(
        await _db
            .from('seo_analytics_daily')
            .select('*')
            .order('date', ascending: true),
      );

  Future<List<Map<String, dynamic>>> seoKeywords() async => _rows(
        await _db
            .from('seo_keywords')
            .select('*')
            .order('created_at', ascending: false)
            .limit(500),
      );

  Future<List<Map<String, dynamic>>> backlinks() async => _rows(
        await _db
            .from('backlinks')
            .select('*')
            .order('created_at', ascending: false),
      );

  Future<List<Map<String, dynamic>>> geoReach() async => _rows(
        await _db
            .from('seo_geo_reach')
            .select('*')
            .order('visitors', ascending: false),
      );

  // ── Attendance ───────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> attendance() async => _rows(
        await _db
            .from('attendance')
            .select('*')
            .order('date', ascending: false)
            .limit(300),
      );

  // ── Tickets ──────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> supportTickets() async => _rows(
        await _db
            .from('support_tickets')
            .select('*')
            .order('created_at', ascending: false),
      );

  Future<List<Map<String, dynamic>>> afterSalesTickets() async => _rows(
        await _db
            .from('after_sales_tickets')
            .select('*')
            .order('query_date', ascending: false, nullsFirst: false),
      );

  // ── Designer ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> designs() async => _rows(
        await _db
            .from('designs')
            .select('*')
            .order('created_at', ascending: false),
      );

  Future<void> reviewDesign(String id, String status, String reviewer) async {
    await _db.from('designs').update({
      'status': status,
      'reviewer_name': reviewer,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<Map<String, dynamic>?> realtimeTraffic() async {
    final rows = _rows(
      await _db
          .from('realtime_traffic_log')
          .select('active_users, page_views_30m, timestamp')
          .order('timestamp', ascending: false)
          .limit(1),
    );
    return rows.isEmpty ? null : rows.first;
  }

  // ── SEO metadata (traffic sources, top queries, summary KPIs) ────
  Future<Map<String, dynamic>> seoMetadata() async {
    final rows = _rows(
      await _db.from('seo_analytics_metadata').select('key, value'),
    );
    final out = <String, dynamic>{};
    for (final r in rows) {
      out[r['key'].toString()] = r['value'];
    }
    return out;
  }

  // ── Home ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> homeNotes() async {
    try {
      return _rows(await _db.from('home_notes').select('*').order('updated_at', ascending: false));
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> homeTasks() async => _rows(
        await _db.from('tasks').select('*').order('created_at', ascending: false).limit(100));

  Future<List<Map<String, dynamic>>> calendarEvents() async {
    try {
      return _rows(await _db.from('calendar_events').select('*').order('event_date', ascending: true));
    } catch (_) {
      return [];
    }
  }

  // ── CRM per-deal notes / activities / tasks ───────────────────────
  Future<List<Map<String, dynamic>>> crmNotesByTarget(String targetId) async {
    try {
      return _rows(await _db.from('crm_notes').select('*').eq('target_id', targetId).order('created_at', ascending: false));
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> crmActivitiesByTarget(String targetId) async {
    try {
      return _rows(await _db.from('crm_activities').select('*').eq('target_id', targetId).order('created_at', ascending: false));
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> crmTasksByTarget(String targetId) async {
    try {
      return _rows(await _db.from('crm_tasks').select('*').eq('target_id', targetId).order('created_at', ascending: false));
    } catch (_) {
      return [];
    }
  }

  Future<void> addCrmNote(
      String targetId, String targetType, String note, String author) async {
    await _db.from('crm_notes').insert({
      'target_id': targetId,
      'target_type': targetType,
      'note': note,
      'created_by': author,
    });
  }

  Future<void> deleteCrmNote(String id) async {
    await _db.from('crm_notes').delete().eq('id', id);
  }

  Future<void> addCrmTask(
      String targetId, String targetType, Map<String, dynamic> fields) async {
    final clean = Map<String, dynamic>.from(fields)
      ..removeWhere((k, v) => v == null || (v is String && v.trim().isEmpty));
    await _db.from('crm_tasks').insert({
      'target_id': targetId,
      'target_type': targetType,
      ...clean,
    });
  }

  Future<void> updateCrmTask(String id, Map<String, dynamic> fields) async {
    final clean = Map<String, dynamic>.from(fields)
      ..removeWhere((k, v) => v == null);
    if (clean.isEmpty) return;
    await _db.from('crm_tasks').update(clean).eq('id', id);
  }

  Future<void> deleteCrmTask(String id) async {
    await _db.from('crm_tasks').delete().eq('id', id);
  }

  // ── Access Admin ─────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> allUsersForAdmin() async => _rows(
        await _db
            .from('final_employees')
            .select(
                'employee_id, full_name, email, role, status, approval_status, department, joined_on')
            .order('full_name', ascending: true));

  Future<void> updateUserRole(String employeeId, String role) async {
    await _db.from('final_employees').update({'role': role}).eq('employee_id', employeeId);
  }

  Future<void> updateUserApproval(String employeeId, String approvalStatus) async {
    await _db
        .from('final_employees')
        .update({'approval_status': approvalStatus}).eq('employee_id', employeeId);
  }

  Future<void> updateUserStatus(String employeeId, String status) async {
    await _db.from('final_employees').update({'status': status}).eq('employee_id', employeeId);
  }

  // ── Notifications ────────────────────────────────────────────────
  /// Aggregates actionable items for the signed-in user, mirroring the web
  /// app's `/api/notifications` route (role-aware).
  Future<List<AppNotification>> notifications({
    required String userId,
    required String role,
    required String userName,
  }) async {
    final out = <AppNotification>[];

    // 1. Support tickets routed to this person (Open / In Progress).
    if (userId.isNotEmpty) {
      final tickets = _rows(await _db
          .from('support_tickets')
          .select('id, ticket_number, title, priority, status, created_at')
          .eq('responsible_person_id', userId)
          .inFilter('status', ['Open', 'In Progress'])
          .order('created_at', ascending: false));
      for (final t in tickets) {
        out.add(AppNotification(
          type: 'ticket',
          priority: t['priority'] == 'Urgent'
              ? 0
              : (t['priority'] == 'High' ? 1 : 2),
          title: 'Ticket #${t['ticket_number']}: ${t['title']}',
          description: 'Status: ${t['status']} — needs your attention',
          route: '/dashboard/tickets',
        ));
      }
    }

    // 2. Leave requests pending approval (admin + hr).
    if (role == 'admin' || role == 'hr') {
      final leaves = _rows(await _db
          .from('leave_requests')
          .select('id, employee_name, leave_type, start_date, end_date')
          .eq('status', 'Pending')
          .order('created_at', ascending: false));
      for (final l in leaves) {
        out.add(AppNotification(
          type: 'leave',
          priority: 1,
          title: 'Leave Request: ${l['employee_name']}',
          description: '${l['leave_type']} · ${l['start_date']} → ${l['end_date']}',
          route: '/dashboard/hr',
        ));
      }
    }

    // 3 & 4. Blocked materials / after-sales (admin + production).
    if (role == 'admin' || role == 'production') {
      final mats = _rows(await _db
          .from('pending_materials')
          .select('id, material_pending')
          .eq('status', 'blocked')
          .limit(20));
      if (mats.isNotEmpty) {
        out.add(AppNotification(
          type: 'material',
          priority: 1,
          title: '${mats.length} Blocked Material(s)',
          description: mats.take(2).map((m) => m['material_pending']).join(', '),
          route: '/dashboard/orders',
        ));
      }
      final ats = _rows(await _db
          .from('after_sales_tickets')
          .select('id, client_name, product_name')
          .eq('status', 'blocked')
          .limit(20));
      if (ats.isNotEmpty) {
        out.add(AppNotification(
          type: 'after_sales',
          priority: 1,
          title: '${ats.length} After-Sales Issue(s) Blocked',
          description: ats
              .take(2)
              .map((a) => '${a['client_name']} – ${a['product_name']}')
              .join(', '),
          route: '/dashboard/production',
        ));
      }
    }

    // 5. Overdue tasks assigned to this user (by name).
    if (userName.isNotEmpty) {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final tasks = _rows(await _db
          .from('tasks')
          .select('id, task, status, end_date')
          .ilike('assigned_to', '%$userName%')
          .not('status', 'in', '("Done","Completed","done","completed")')
          .lt('end_date', today)
          .order('end_date', ascending: true)
          .limit(20));
      if (tasks.isNotEmpty) {
        out.add(AppNotification(
          type: 'task',
          priority: 1,
          title: '${tasks.length} Overdue Task(s)',
          description: tasks.take(2).map((t) => t['task']).join(', '),
          route: '/dashboard/hr',
        ));
      }
    }

    // 6. CRM leads missing required info (admin + sales).
    if (role == 'admin' || role == 'sales') {
      final leads = _rows(await _db
          .from('crm_opportunities')
          .select(
              'id, name, stage, location, contact_number, email, product_name, contacted_by, contact_mode')
          .inFilter('stage', ['NEW', 'SCREENING']));
      final incomplete =
          leads.where((l) => _missingFields(l).isNotEmpty).toList();
      if (incomplete.isNotEmpty) {
        out.add(AppNotification(
          type: 'lead',
          priority: 2,
          title: '${incomplete.length} Lead(s) Missing Info',
          description: incomplete
              .take(2)
              .map((l) =>
                  '${l['name'] ?? 'Unnamed'} (${_missingFields(l).join(', ')})')
              .join('; '),
          route: '/dashboard/sales',
        ));
      }
    }

    out.sort((a, b) => a.priority.compareTo(b.priority));
    return out;
  }

  List<String> _missingFields(Map<String, dynamic> d) {
    bool has(dynamic v) => v != null && v.toString().trim().isNotEmpty;
    final hasContact = has(d['contact_number']) || has(d['email']);
    final stage = d['stage']?.toString();
    final out = <String>[];
    if (stage == 'NEW' || stage == 'SCREENING') {
      if (!has(d['name'])) out.add('Name');
      if (!has(d['location'])) out.add('Location');
      if (!hasContact) out.add('Phone/Email');
    }
    if (stage == 'SCREENING') {
      if (!has(d['product_name'])) out.add('Product');
      if (!has(d['contacted_by'])) out.add('Contacted by');
      if (!has(d['contact_mode'])) out.add('Mode');
    }
    return out;
  }
}

/// A single actionable notification (priority: 0=urgent … 3=low).
class AppNotification {
  final String type;
  final int priority;
  final String title;
  final String description;
  final String route;
  const AppNotification({
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.route,
  });
}
