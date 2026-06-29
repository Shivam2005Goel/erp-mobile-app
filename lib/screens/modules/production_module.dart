import 'package:flutter/material.dart';

import '../../data/erp_repository.dart';
import '../../widgets/erp_ui.dart';

class _Pending {
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> materials;
  final List<Map<String, dynamic>> afterSales;
  const _Pending(this.tasks, this.materials, this.afterSales);
}

/// Pending Tasks: a cross-department tracker of all unfinished work,
/// tasks grouped by person with expand/collapse — mirrors the Next.js view.
class ProductionModule extends StatelessWidget {
  ProductionModule({super.key});
  final _repo = ErpRepository();

  bool _isOpen(dynamic status, List<String> closed) {
    final s = (status?.toString() ?? '').toLowerCase();
    return !closed.any((c) => s == c);
  }

  Future<_Pending> _load() async {
    final results = await Future.wait([
      _repo.tasks(),
      _repo.pendingMaterials(),
      _repo.afterSalesTickets(),
    ]);
    final tasks = results[0]
        .where((t) => _isOpen(t['status'], ['done', 'completed']))
        .toList();
    final materials = results[1]
        .where((m) => _isOpen(m['status'], ['completed', 'resolved', 'done']))
        .toList();
    final after = results[2]
        .where((a) => _isOpen(a['status'], ['resolved', 'completed', 'closed']))
        .toList();
    return _Pending(tasks, materials, after);
  }

  @override
  Widget build(BuildContext context) {
    return AsyncSection<_Pending>(
      loader: _load,
      isEmpty: (p) =>
          p.tasks.isEmpty && p.materials.isEmpty && p.afterSales.isEmpty,
      emptyMessage: 'Nothing pending — all caught up!',
      builder: (context, p, refresh) {
        // Group tasks by assigned_to person.
        final byPerson = <String, List<Map<String, dynamic>>>{};
        for (final t in p.tasks) {
          final person =
              (t['assigned_to']?.toString().trim().isNotEmpty ?? false)
                  ? t['assigned_to'].toString().trim()
                  : 'Unassigned';
          byPerson.putIfAbsent(person, () => []).add(t);
        }
        final people = byPerson.keys.toList()..sort();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            // ── KPI row ─────────────────────────────────────────────
            MetricRow(children: [
              MetricCard(
                  label: 'Open Tasks',
                  value: '${p.tasks.length}',
                  icon: Icons.checklist,
                  color: const Color(0xFFf59e0b)),
              MetricCard(
                  label: 'Pending Materials',
                  value: '${p.materials.length}',
                  icon: Icons.inventory,
                  color: const Color(0xFF8b5cf6)),
              MetricCard(
                  label: 'After-Sales',
                  value: '${p.afterSales.length}',
                  icon: Icons.support_agent,
                  color: const Color(0xFFdc2626)),
            ]),
            const SizedBox(height: 12),

            // ── Tasks grouped by person ──────────────────────────────
            if (p.tasks.isNotEmpty) ...[
              const SectionTitle('Open Tasks'),
              ...people.map((person) => _PersonTaskCard(
                    person: person,
                    tasks: byPerson[person]!,
                    repo: _repo,
                    onRefresh: refresh,
                  )),
              const SizedBox(height: 8),
            ],

            // ── Pending Materials ────────────────────────────────────
            if (p.materials.isNotEmpty) ...[
              const SectionTitle('Pending Materials'),
              ...p.materials.map((m) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(str(m['material_pending'], 'Material')),
                      subtitle: Text(
                          '${str(m['product_name'], '')} • By ${str(m['material_pending_by'])}'),
                      trailing: StatusChip(str(m['status'], 'pending'),
                          color: statusColor(m['status']?.toString())),
                    ),
                  )),
              const SizedBox(height: 8),
            ],

            // ── After-Sales Tickets ──────────────────────────────────
            if (p.afterSales.isNotEmpty) ...[
              const SectionTitle('After-Sales Tickets'),
              ...p.afterSales.map((a) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.build_outlined),
                      title: Text(str(a['work_required'], 'Work required')),
                      subtitle: Text(
                          '${str(a['client_name'], '')} • ${str(a['product_name'], '')}'),
                      trailing: StatusChip(str(a['status'], 'open'),
                          color: statusColor(a['status']?.toString())),
                    ),
                  )),
            ],
          ],
        );
      },
    );
  }
}

// ── Person task card with expand/collapse ─────────────────────────────────────
class _PersonTaskCard extends StatefulWidget {
  final String person;
  final List<Map<String, dynamic>> tasks;
  final ErpRepository repo;
  final VoidCallback onRefresh;

  const _PersonTaskCard({
    required this.person,
    required this.tasks,
    required this.repo,
    required this.onRefresh,
  });

  @override
  State<_PersonTaskCard> createState() => _PersonTaskCardState();
}

class _PersonTaskCardState extends State<_PersonTaskCard> {
  bool _expanded = false;

  String get _initials {
    final parts = widget.person.split(' ');
    return parts
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
  }

  int get _pendingCount => widget.tasks
      .where((t) => !['done', 'completed']
          .contains((t['status'] ?? '').toString().toLowerCase()))
      .length;

  void _showError(String msg) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'))
        ],
      ),
    );
  }

  Future<void> _assignTask() async {
    final taskCtrl = TextEditingController();
    String status = 'Not Started';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Assign Task to ${widget.person}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: taskCtrl,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Task *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Status', border: OutlineInputBorder()),
                child: DropdownButton<String>(
                  value: status,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                        value: 'Not Started', child: Text('Not Started')),
                    DropdownMenuItem(
                        value: 'In Progress', child: Text('In Progress')),
                    DropdownMenuItem(value: 'Done', child: Text('Done')),
                  ],
                  onChanged: (v) {
                    if (v != null) setSt(() => status = v);
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Assign')),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    if (taskCtrl.text.trim().isEmpty) return;
    try {
      await widget.repo.create('tasks', {
        'task': taskCtrl.text.trim(),
        'assigned_to': widget.person,
        'assigned_by': 'Team argmac',
        'status': status,
      });
      widget.onRefresh();
    } catch (e) {
      _showError('Failed to assign task.\n\n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pendingCount;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Person header ──────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: kBrand.withValues(alpha: 0.15),
                  child: Text(_initials,
                      style: TextStyle(
                          color: kBrand,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.person,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(
                          '${widget.tasks.length} task${widget.tasks.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                if (pending > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: kBrand,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$pending pending',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.chevron_right,
                  color: Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: _assignTask,
                  icon: const Icon(Icons.add, size: 13),
                  label: const Text('Assign Task',
                      style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: kBrand,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
              ]),
            ),
          ),

          // ── Task list (when expanded) ──────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1),
            // Column headers
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Row(children: const [
                Expanded(
                    flex: 5,
                    child: Text('TASK',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey,
                            letterSpacing: 0.5))),
                SizedBox(width: 8),
                SizedBox(
                    width: 72,
                    child: Text('STATUS',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey,
                            letterSpacing: 0.5))),
                SizedBox(width: 8),
                SizedBox(
                    width: 60,
                    child: Text('DUE',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey,
                            letterSpacing: 0.5))),
              ]),
            ),
            ...widget.tasks.map((t) {
              final status = str(t['status'], 'Pending');
              final overdue = _isOverdue(t['end_date'], status);
              return Container(
                decoration: BoxDecoration(
                  color: overdue
                      ? kDanger.withValues(alpha: 0.04)
                      : null,
                  border: Border(
                      top: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.1))),
                ),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(str(t['task']),
                              style: const TextStyle(fontSize: 13)),
                          if ((t['assigned_by']?.toString().trim() ?? '')
                              .isNotEmpty)
                            Text('By: ${t['assigned_by']}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          if ((t['notes']?.toString().trim() ?? '')
                              .isNotEmpty)
                            Text(str(t['notes']),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 72,
                      child: StatusChip(status,
                          color: statusColor(status)),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: Text(
                        t['end_date'] != null
                            ? fmtDate(t['end_date'])
                            : '—',
                        style: TextStyle(
                            fontSize: 11,
                            color: overdue ? kDanger : Colors.grey),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  static bool _isOverdue(dynamic endDate, String status) {
    if (endDate == null) return false;
    final s = status.toLowerCase();
    if (s.contains('done') || s.contains('complete')) return false;
    final d = DateTime.tryParse(endDate.toString());
    return d != null && d.isBefore(DateTime.now());
  }
}
