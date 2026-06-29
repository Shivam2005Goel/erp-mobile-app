import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_state.dart';
import '../../data/erp_repository.dart';
import '../../widgets/crud_list.dart';
import '../../widgets/erp_ui.dart';
import '../../widgets/record_form.dart';

/// Home dashboard: Notes, My Tasks and Company Calendar.
class HomeModule extends StatelessWidget {
  HomeModule({super.key});
  final _repo = ErpRepository();

  @override
  Widget build(BuildContext context) {
    final userName =
        AppStateScope.of(context).currentUser?.fullName ?? '';
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Notes'),
              Tab(text: 'My Tasks'),
              Tab(text: 'Calendar'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _notesTab(),
                _MyTasksTab(repo: _repo, userName: userName),
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
          final firstLine =
              content.isEmpty ? null : content.split('\n').first.trim();
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
                        style: const TextStyle(
                            fontSize: 10.5, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          );
        },
      );

  static Color _noteColor(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'red':
        return const Color(0xFFef4444);
      case 'green':
        return const Color(0xFF22c55e);
      case 'blue':
        return const Color(0xFF3b82f6);
      case 'yellow':
        return const Color(0xFFf59e0b);
      case 'purple':
        return const Color(0xFFa855f7);
      default:
        return kBrand;
    }
  }
}

// ── My Tasks Tab ──────────────────────────────────────────────────────────────
class _MyTasksTab extends StatefulWidget {
  final ErpRepository repo;
  final String userName;
  const _MyTasksTab({required this.repo, required this.userName});

  @override
  State<_MyTasksTab> createState() => _MyTasksTabState();
}

class _MyTasksTabState extends State<_MyTasksTab> {
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await widget.repo.homeTasks();
      final name = widget.userName.toLowerCase().trim();
      final mine = name.isEmpty
          ? all
          : all
              .where((t) => (t['assigned_to'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(name))
              .toList();
      if (mounted) {
        setState(() {
          _tasks = mine;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

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

  Future<void> _addTask() async {
    final taskCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String status = 'Pending';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Add Task'),
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
                    DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                    DropdownMenuItem(
                        value: 'In Progress', child: Text('In Progress')),
                    DropdownMenuItem(value: 'Done', child: Text('Done')),
                    DropdownMenuItem(
                        value: 'Completed', child: Text('Completed')),
                  ],
                  onChanged: (v) {
                    if (v != null) setSt(() => status = v);
                  },
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                    labelText: 'Notes', border: OutlineInputBorder()),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    if (taskCtrl.text.trim().isEmpty) {
      _showError('Task is required.');
      return;
    }
    try {
      await widget.repo.create('tasks', {
        'task': taskCtrl.text.trim(),
        'assigned_to': widget.userName.isEmpty ? null : widget.userName,
        'assigned_by': 'Mobile App',
        'status': status,
        'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      });
      await _load();
    } catch (e) {
      _showError('Failed to add task.\n\n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Failed: $_error'),
        ElevatedButton(onPressed: _load, child: const Text('Retry')),
      ]));
    }

    final pending = _tasks
        .where((t) =>
            !['done', 'completed'].contains(
                (t['status'] ?? '').toString().toLowerCase()))
        .length;

    return RefreshIndicator(
      onRefresh: _load,
      child: Stack(
        children: [
          _tasks.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 80),
                    Center(
                        child: Text('No tasks assigned to you.',
                            style: TextStyle(color: Colors.grey))),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: _tasks.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: MetricRow(children: [
                          MetricCard(
                              label: 'My Tasks',
                              value: '${_tasks.length}',
                              icon: Icons.assignment),
                          MetricCard(
                              label: 'Pending',
                              value: '$pending',
                              icon: Icons.hourglass_empty,
                              color: pending > 0 ? kWarning : kSuccess),
                        ]),
                      );
                    }
                    final t = _tasks[i - 1];
                    final status = str(t['status'], 'Pending');
                    final overdue = _isOverdue(t['end_date'], status);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: overdue
                          ? kDanger.withValues(alpha: 0.05)
                          : null,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: Icon(_taskIcon(status),
                            color: statusColor(status), size: 22),
                        title: Text(str(t['task']),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((t['assigned_by']?.toString().trim() ?? '')
                                .isNotEmpty)
                              Text('By: ${t['assigned_by']}',
                                  style: const TextStyle(fontSize: 11)),
                            if (t['end_date'] != null)
                              Text(
                                'Due ${fmtDate(t['end_date'])}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: overdue ? kDanger : Colors.grey),
                              ),
                          ],
                        ),
                        isThreeLine: (t['assigned_by']?.toString().trim() ??
                                '')
                            .isNotEmpty,
                        trailing: StatusChip(status,
                            color: statusColor(status)),
                      ),
                    );
                  },
                ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _addTask,
              backgroundColor: kBrand,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _taskIcon(String status) {
    final s = status.toLowerCase();
    if (s.contains('done') || s.contains('complete')) {
      return Icons.check_circle;
    }
    if (s.contains('progress')) return Icons.pending;
    return Icons.radio_button_unchecked;
  }

  static bool _isOverdue(dynamic endDate, String status) {
    if (endDate == null) return false;
    final s = status.toLowerCase();
    if (s.contains('done') || s.contains('complete')) return false;
    final d = DateTime.tryParse(endDate.toString());
    return d != null && d.isBefore(DateTime.now());
  }
}

// ── Calendar Tab ──────────────────────────────────────────────────────────────
class _CalendarTab extends StatefulWidget {
  final ErpRepository repo;
  const _CalendarTab({required this.repo});

  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  late DateTime _month;
  DateTime? _selected;
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;

  static const _weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final events = await widget.repo.calendarEvents();
    if (mounted) {
      setState(() {
        _events = events;
        _loading = false;
      });
    }
  }

  // Returns events for a given day.
  List<Map<String, dynamic>> _eventsFor(DateTime day) {
    return _events.where((e) {
      final d = DateTime.tryParse(e['event_date']?.toString() ?? '');
      return d != null &&
          d.year == day.year &&
          d.month == day.month &&
          d.day == day.day;
    }).toList();
  }

  void _prevMonth() => setState(
      () => _month = DateTime(_month.year, _month.month - 1));

  void _nextMonth() => setState(
      () => _month = DateTime(_month.year, _month.month + 1));

  Future<void> _addEvent() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool allDay = true;
    DateTime selectedDate = _selected ?? DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Add event'),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Title
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Event title',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              // Date picker row
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setSt(() => selectedDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        DateFormat('dd - MM - yyyy').format(selectedDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const Icon(Icons.calendar_today, size: 16),
                  ]),
                ),
              ),
              const SizedBox(height: 4),
              // All day checkbox
              Row(children: [
                Checkbox(
                  value: allDay,
                  onChanged: (v) => setSt(() => allDay = v ?? true),
                  activeColor: kBrand,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const Text('All day', style: TextStyle(fontSize: 14)),
              ]),
              const SizedBox(height: 4),
              // Description
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Description (optional)',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 4),
            ]),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          actions: [
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, false),
              icon: const Icon(Icons.close, size: 14),
              label: const Text(''),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(40, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check, size: 14),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrand,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    if (titleCtrl.text.trim().isEmpty) return;
    try {
      await widget.repo.create('calendar_events', {
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim().isEmpty
            ? null
            : descCtrl.text.trim(),
        'event_type': 'event',
        'event_date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'all_day': allDay,
      });
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save event: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final daysInMonth =
        DateUtils.getDaysInMonth(_month.year, _month.month);
    final firstWeekday =
        DateTime(_month.year, _month.month, 1).weekday % 7; // 0=Sun
    final today = DateTime.now();
    final selectedEvents =
        _selected != null ? _eventsFor(_selected!) : <Map<String, dynamic>>[];

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: title + add button
              Row(children: [
                const Icon(Icons.calendar_month, size: 18),
                const SizedBox(width: 8),
                const Text('Company Calendar',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addEvent,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Event',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              // Row 2: month navigation centered
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _prevMonth,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMMM yyyy').format(_month),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Day-of-week headers ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: _weekdays
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: (d == 'SUN' || d == 'SAT')
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.6)
                                    : Colors.grey)),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 4),
        // ── Calendar grid ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
            ),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (_, index) {
              if (index < firstWeekday) return const SizedBox.shrink();
              final day = index - firstWeekday + 1;
              final date = DateTime(_month.year, _month.month, day);
              final events = _eventsFor(date);
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isSelected = _selected != null &&
                  _selected!.year == date.year &&
                  _selected!.month == date.month &&
                  _selected!.day == date.day;

              return GestureDetector(
                onTap: () => setState(() {
                  _selected = isSelected ? null : date;
                }),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? kBrand
                        : isToday
                            ? kBrand.withValues(alpha: 0.15)
                            : null,
                    borderRadius: BorderRadius.circular(6),
                    border: isToday && !isSelected
                        ? Border.all(
                            color: kBrand.withValues(alpha: 0.5))
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday || isSelected
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : null,
                        ),
                      ),
                      if (events.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: events
                              .take(3)
                              .map((_) => Container(
                                    width: 4,
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white
                                          : kBrand,
                                      shape: BoxShape.circle,
                                    ),
                                  ))
                              .toList(),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 16),
        // ── Selected day events ──────────────────────────────────────
        Expanded(
          child: _selected == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app,
                          color: Colors.grey.withValues(alpha: 0.4),
                          size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Tap a date to see events',
                        style: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.6),
                            fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_events.length} event${_events.length == 1 ? '' : 's'} this view',
                        style: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.5),
                            fontSize: 11),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        DateFormat('EEEE, d MMMM').format(_selected!),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    if (selectedEvents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('No events on this day.',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 13)),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: selectedEvents.length,
                          itemBuilder: (_, i) =>
                              _EventTile(event: selectedEvents[i]),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final type = str(event['event_type'], 'event');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: kBrand.withValues(alpha: 0.12),
          child: Icon(_typeIcon(type), size: 15, color: kBrand),
        ),
        title: Text(str(event['title']),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: (event['description']?.toString().trim() ?? '').isNotEmpty
            ? Text(str(event['description']),
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11))
            : null,
        trailing: StatusChip(type, color: kBrand),
      ),
    );
  }

  static IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return Icons.groups;
      case 'deadline':
        return Icons.timer;
      case 'holiday':
        return Icons.beach_access;
      case 'reminder':
        return Icons.notifications;
      default:
        return Icons.event;
    }
  }
}
