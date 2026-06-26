import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/erp_repository.dart';
import '../../widgets/erp_ui.dart';

/// Attendance: daily check-in/out log grouped by date.
class AttendanceModule extends StatelessWidget {
  AttendanceModule({super.key});
  final _repo = ErpRepository();

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<Map<String, dynamic>>>(
      loader: _repo.attendance,
      isEmpty: (d) => d.isEmpty,
      emptyMessage: 'No attendance records.',
      builder: (context, list, refresh) {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final presentToday =
            list.where((a) => a['date']?.toString() == today).length;
        final lateCount = list
            .where((a) => (num.tryParse('${a['late_by_minutes'] ?? 0}') ?? 0) > 0)
            .length;

        // Group by date.
        final byDate = <String, List<Map<String, dynamic>>>{};
        for (final a in list) {
          final d = a['date']?.toString() ?? 'Unknown';
          byDate.putIfAbsent(d, () => []).add(a);
        }
        final dates = byDate.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            MetricRow(children: [
              MetricCard(
                  label: 'Present Today',
                  value: '$presentToday',
                  icon: Icons.how_to_reg,
                  color: const Color(0xFF16a34a)),
              MetricCard(
                  label: 'Records (300d)',
                  value: '${list.length}',
                  icon: Icons.event_available),
              MetricCard(
                  label: 'Late Arrivals',
                  value: '$lateCount',
                  icon: Icons.running_with_errors,
                  color: const Color(0xFFf59e0b)),
            ]),
            const SizedBox(height: 12),
            for (final d in dates) ...[
              SectionTitle(fmtDate(d),
                  subtitle: '${byDate[d]!.length} present'),
              ...byDate[d]!.map((a) {
                final late =
                    num.tryParse('${a['late_by_minutes'] ?? 0}') ?? 0;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: statusColor(a['status']?.toString())
                          .withValues(alpha: 0.15),
                      child: Icon(Icons.person,
                          size: 18,
                          color: statusColor(a['status']?.toString())),
                    ),
                    title: Text(str(a['employee_name'], a['employee_email'])),
                    subtitle: Text([
                      if (a['check_in_time'] != null)
                        'In ${_time(a['check_in_time'])}',
                      if (a['check_out_time'] != null)
                        'Out ${_time(a['check_out_time'])}',
                      if ((a['location_label']?.toString().trim() ?? '')
                          .isNotEmpty)
                        a['location_label'],
                    ].join(' • ')),
                    trailing: late > 0
                        ? StatusChip('Late ${late}m',
                            color: const Color(0xFFf59e0b))
                        : StatusChip(str(a['status'], 'present'),
                            color: statusColor(a['status']?.toString())),
                  ),
                );
              }),
              const SizedBox(height: 6),
            ],
          ],
        );
      },
    );
  }

  static String _time(dynamic v) {
    final d = DateTime.tryParse(v.toString());
    return d == null ? '' : DateFormat('HH:mm').format(d.toLocal());
  }
}
