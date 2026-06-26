import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../data/erp_repository.dart';
import '../../widgets/erp_ui.dart';

/// Designer: design uploads with an admin approval flow.
class DesignerModule extends StatefulWidget {
  const DesignerModule({super.key});
  @override
  State<DesignerModule> createState() => _DesignerModuleState();
}

class _DesignerModuleState extends State<DesignerModule> {
  final _repo = ErpRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.designs();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repo.designs());
    await _future;
  }

  Future<void> _review(Map<String, dynamic> d, String status) async {
    final reviewer =
        AppStateScope.of(context).currentUser?.fullName ?? 'Reviewer';
    try {
      await _repo.reviewDesign(d['id'].toString(), status, reviewer);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = AppStateScope.of(context).currentUser?.role;
    final canReview = role == 'admin' || role == 'designer';

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('Failed: ${snap.error}')),
              ),
            ]);
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return ListView(children: const [
              Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: Text('No designs uploaded yet.')),
              ),
            ]);
          }
          final pending =
              list.where((d) => d['status'] == 'pending').length;
          final approved =
              list.where((d) => d['status'] == 'approved').length;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              MetricRow(children: [
                MetricCard(
                    label: 'Designs',
                    value: '${list.length}',
                    icon: Icons.palette),
                MetricCard(
                    label: 'Pending Review',
                    value: '$pending',
                    icon: Icons.pending_actions,
                    color: const Color(0xFFf59e0b)),
                MetricCard(
                    label: 'Approved',
                    value: '$approved',
                    icon: Icons.verified,
                    color: const Color(0xFF16a34a)),
              ]),
              const SizedBox(height: 12),
              ...list.map((d) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.image_outlined),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(str(d['title']),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                              ),
                              StatusChip(str(d['status'], 'pending'),
                                  color: statusColor(d['status']?.toString())),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'By ${str(d['designer_name'])} • ${fmtDate(d['created_at'])}',
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    Theme.of(context).textTheme.bodySmall?.color),
                          ),
                          if ((d['description']?.toString().trim() ?? '')
                              .isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(str(d['description']),
                                  style: const TextStyle(fontSize: 13)),
                            ),
                          if (canReview && d['status'] == 'pending') ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _review(d, 'rejected'),
                                  icon: const Icon(Icons.close, size: 18),
                                  label: const Text('Reject'),
                                  style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFdc2626)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _review(d, 'approved'),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('Approve'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}
