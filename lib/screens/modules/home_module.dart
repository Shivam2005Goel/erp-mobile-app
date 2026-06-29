import 'package:flutter/material.dart';

import '../../data/erp_repository.dart';
import '../../widgets/crud_list.dart';
import '../../widgets/erp_ui.dart';
import '../../widgets/record_form.dart';

/// Home dashboard: Notes, Tasks and Calendar — mirrors the Next.js /dashboard/home page.
class HomeModule extends StatelessWidget {
  HomeModule({super.key});
  final _repo = ErpRepository();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Notes'),
              Tab(text: 'Tasks'),
              Tab(text: 'Calendar'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _notesTab(),
                _tasksTab(),
                _CalendarTab(repo: _repo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _notesTab() => CrudList(
        repo: _repo,
        table: 'home_notes',
        idCol: 'id',
        addLabel: 'Add Note',
        editLabel: 'Edit Note',
        loader: _repo.homeNotes,
        emptyMessage: 'No notes yet. Add your first note.',
        searchFields: const ['title', 'content'],
        searchHint: 'Search notes…',
        fields: () => const [
          FieldSpec('title', 'Title', required: true),
          FieldSpec('content', 'Content', type: FieldType.multiline),
          FieldSpec('color', 'Label colour (e.g. blue, yellow)'),
        ],
        tile: (n, onEdit, onDelete) {
          final color = _noteColor(n['color']?.toString());
          final content = (n['content'] ?? '').toString().trim();
          final firstLine = content.isEmpty
              ? null
              : content.split('\n').first.trim();
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (n['color'] != null)
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                      Expanded(
                        child: Text(str(n['title']),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      RowMenu(onEdit: onEdit, onDelete: onDelete),
                    ]),
                    if (firstLine != null) ...[
                      const SizedBox(height: 4),
                      Text(firstLine,
                          style: const TextStyle(
                              fontSize: 12.5, color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 6),
                    Text(fmtDate(n['updated_at'] ?? n['created_at']),
                        style:
                            const TextStyle(fontSize: 10.5, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          );
        },
      );

  Widget _tasksTab() => CrudList(
        repo: _repo,
        table: 'tasks',
        idCol: 'id',
        addLabel: 'Add Task',
        editLabel: 'Edit Task',
        loader: _repo.homeTasks,
        emptyMessage: 'No tasks yet.',
        searchFields: const ['task', 'assigned_to'],
        searchHint: 'Search tasks…',
        fields: () => const [
          FieldSpec('task', 'Task', required: true, type: FieldType.multiline),
          FieldSpec('assigned_to', 'Assigned to'),
          FieldSpec('assigned_by', 'Assigned by'),
          FieldSpec('status', 'Status',
              type: FieldType.dropdown,
              options: ['Pending', 'In Progress', 'Done', 'Completed']),
          FieldSpec('start_date', 'Start date', type: FieldType.date),
          FieldSpec('end_date', 'Due date', type: FieldType.date),
          FieldSpec('notes', 'Notes', type: FieldType.multiline),
        ],
        tile: (t, onEdit, onDelete) {
          final status = str(t['status'], 'Pending');
          final overdue = _isOverdue(t['end_date'], status);
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: overdue
                ? kDanger.withValues(alpha: 0.05)
                : null,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              onTap: onEdit,
              leading: Icon(
                _taskIcon(status),
                color: statusColor(status),
                size: 22,
              ),
              title: Text(str(t['task']),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text([
                if ((t['assigned_to']?.toString().trim() ?? '').isNotEmpty)
                  'To: ${t['assigned_to']}',
                if (t['end_date'] != null) 'Due ${fmtDate(t['end_date'])}',
              ].join(' • ')),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                StatusChip(status, color: statusColor(status)),
                const SizedBox(width: 4),
                RowMenu(onEdit: onEdit, onDelete: onDelete),
              ]),
            ),
          );
        },
      );

  static Color _noteColor(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'red':    return const Color(0xFFef4444);
      case 'green':  return const Color(0xFF22c55e);
      case 'blue':   return const Color(0xFF3b82f6);
      case 'yellow': return const Color(0xFFf59e0b);
      case 'purple': return const Color(0xFFa855f7);
      default:       return kBrand;
    }
  }

  static IconData _taskIcon(String status) {
    final s = status.toLowerCase();
    if (s.contains('done') || s.contains('complete')) return Icons.check_circle;
    if (s.contains('progress')) return Icons.pending;
    return Icons.radio_button_unchecked;
  }

  static bool _isOverdue(dynamic endDate, String status) {
    if (endDate == null) return false;
    final s = status.toLowerCase();
    if (s.contains('done') || s.contains('complete')) return false;
    final d = DateTime.tryParse(endDate.toString());
    if (d == null) return false;
    return d.isBefore(DateTime.now());
  }
}

// ── Calendar Tab ─────────────────────────────────────────────────────────────
class _CalendarTab extends StatelessWidget {
  final ErpRepository repo;
  const _CalendarTab({required this.repo});

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<Map<String, dynamic>>>(
      loader: repo.calendarEvents,
      isEmpty: (d) => d.isEmpty,
      emptyMessage: 'No calendar events.',
      builder: (context, events, refresh) {
        // Group by month.
        final byMonth = <String, List<Map<String, dynamic>>>{};
        for (final e in events) {
          final raw = e['event_date']?.toString() ?? '';
          final d = DateTime.tryParse(raw);
          final key = d != null
              ? '${d.year}-${d.month.toString().padLeft(2, '0')}'
              : 'Unknown';
          byMonth.putIfAbsent(key, () => []).add(e);
        }
        final months = byMonth.keys.toList()..sort();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            MetricRow(children: [
              MetricCard(
                  label: 'Total Events',
                  value: '${events.length}',
                  icon: Icons.event),
              MetricCard(
                  label: 'Upcoming',
                  value: '${events.where((e) => _isUpcoming(e['event_date'])).length}',
                  icon: Icons.upcoming,
                  color: kSuccess),
            ]),
            const SizedBox(height: 12),
            for (final month in months) ...[
              SectionTitle(_monthLabel(month)),
              ...byMonth[month]!.map((e) => _EventCard(event: e)),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  static bool _isUpcoming(dynamic v) {
    final d = DateTime.tryParse((v ?? '').toString());
    return d != null && d.isAfter(DateTime.now());
  }

  static String _monthLabel(String key) {
    if (key == 'Unknown') return 'Unknown';
    final parts = key.split('-');
    if (parts.length < 2) return key;
    final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = int.tryParse(parts[1]) ?? 0;
    return '${m < months.length ? months[m] : parts[1]} ${parts[0]}';
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final type = str(event['event_type'], 'event');
    final upcoming = _CalendarTab._isUpcoming(event['event_date']);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (upcoming ? kBrand : Colors.grey)
              .withValues(alpha: 0.12),
          child: Icon(
            _typeIcon(type),
            size: 18,
            color: upcoming ? kBrand : Colors.grey,
          ),
        ),
        title: Text(str(event['title']),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((event['description']?.toString().trim() ?? '').isNotEmpty)
              Text(str(event['description']),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
            Text(fmtDate(event['event_date']),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        isThreeLine: (event['description']?.toString().trim() ?? '').isNotEmpty,
        trailing: StatusChip(type,
            color: upcoming ? kBrand : Colors.grey),
      ),
    );
  }

  static IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':   return Icons.groups;
      case 'deadline':  return Icons.timer;
      case 'holiday':   return Icons.beach_access;
      case 'reminder':  return Icons.notifications;
      default:          return Icons.event;
    }
  }
}
