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
    final notesCtrl = TextEditingController();
    String status = 'Not Started';
    String? startDate;
    String? endDate;

    Future<String?> pickDate(BuildContext ctx, String? current) async {
      final picked = await showDatePicker(
        context: ctx,
        initialDate: (current != null ? DateTime.tryParse(current) : null) ??
            DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked == null) return current;
      return '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Row(children: [
            Expanded(
              child: Text(
                'ADD TASK — ${widget.person.toUpperCase()}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    letterSpacing: 0.5),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => Navigator.pop(ctx, false),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ]),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Task
                const Text('TASK *',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: taskCtrl,
                  autofocus: true,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Describe the task...',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                // Status
                const Text('STATUS',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                InputDecorator(
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                  child: DropdownButton<String>(
                    value: status,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                          value: 'Not Started', child: Text('Not Started')),
                      DropdownMenuItem(
                          value: 'In Progress', child: Text('In Progress')),
                      DropdownMenuItem(
                          value: 'Pending', child: Text('Pending')),
                      DropdownMenuItem(
                          value: 'Done', child: Text('Done')),
                      DropdownMenuItem(
                          value: 'Completed', child: Text('Completed')),
                    ],
                    onChanged: (v) {
                      if (v != null) setSt(() => status = v);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                // Start / End dates side by side
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('START DATE',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final d = await pickDate(ctx, startDate);
                            setSt(() => startDate = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10)),
                            child: Row(children: [
                              Expanded(
                                child: Text(
                                  startDate ?? 'dd-mm-yyyy',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: startDate != null
                                          ? null
                                          : Colors.grey),
                                ),
                              ),
                              const Icon(Icons.calendar_today, size: 14),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('END DATE',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final d = await pickDate(ctx, endDate);
                            setSt(() => endDate = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10)),
                            child: Row(children: [
                              Expanded(
                                child: Text(
                                  endDate ?? 'dd-mm-yyyy',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: endDate != null
                                          ? null
                                          : Colors.grey),
                                ),
                              ),
                              const Icon(Icons.calendar_today, size: 14),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                // Notes
                const Text('NOTES',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Optional notes...',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrand,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Task'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final taskText = taskCtrl.text.trim();
    if (taskText.isEmpty) {
      _showError('Task description is required.');
      return;
    }
    try {
      final data = <String, dynamic>{
        'task': taskText,
        'assigned_to': widget.person,
        'assigned_by': 'Team argmac',
        'status': status,
      };
      if (startDate != null) data['start_date'] = startDate;
      if (endDate != null) data['end_date'] = endDate;
      final notes = notesCtrl.text.trim();
      if (notes.isNotEmpty) data['notes'] = notes;

      await widget.repo.create('tasks', data);
      widget.onRefresh();
    } catch (e) {
      _showError('Failed to save task.\n\n$e');
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
