import 'package:flutter/material.dart';

import '../../data/erp_repository.dart';
import '../../widgets/erp_ui.dart';

class _Pending {
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> materials;
  final List<Map<String, dynamic>> afterSales;
  const _Pending(this.tasks, this.materials, this.afterSales);
}

/// Pending Tasks: a cross-department tracker of all unfinished work.
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
        .where((m) =>
            _isOpen(m['status'], ['completed', 'resolved', 'done']))
        .toList();
    final after = results[2]
        .where((a) =>
            _isOpen(a['status'], ['resolved', 'completed', 'closed']))
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
      builder: (context, p, refresh) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
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
          if (p.tasks.isNotEmpty) ...[
            const SectionTitle('Open Tasks'),
            ...p.tasks.map((t) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.task_outlined),
                    title: Text(str(t['task'])),
                    subtitle: Text(
                        'To: ${str(t['assigned_to'])} • Due ${fmtDate(t['end_date'])}'),
                    trailing: StatusChip(str(t['status'], 'open'),
                        color: statusColor(t['status']?.toString())),
                  ),
                )),
          ],
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
          ],
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
      ),
    );
  }
}
