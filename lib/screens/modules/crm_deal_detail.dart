import 'package:flutter/material.dart';

import '../../data/erp_repository.dart';
import '../../widgets/erp_ui.dart';

/// Full-screen deal detail view with Notes, Tasks and Activity tabs.
/// Mirrors the RecordDrawer in the Next.js web app.
class CrmDealDetail extends StatefulWidget {
  final Map<String, dynamic> opp;
  const CrmDealDetail({super.key, required this.opp});

  @override
  State<CrmDealDetail> createState() => _CrmDealDetailState();
}

class _CrmDealDetailState extends State<CrmDealDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _repo = ErpRepository();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = str(widget.opp['name']);
    final company = str(widget.opp['company_name'], '');
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
            if (company.isNotEmpty && company != '—')
              Text(company,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.75))),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Notes'),
            Tab(text: 'Tasks'),
            Tab(text: 'Activity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _DetailsTab(opp: widget.opp),
          _NotesTab(oppId: widget.opp['id']?.toString() ?? '', repo: _repo),
          _TasksTab(oppId: widget.opp['id']?.toString() ?? '', repo: _repo),
          _ActivityTab(oppId: widget.opp['id']?.toString() ?? '', repo: _repo),
        ],
      ),
    );
  }
}

// ── Details Tab ───────────────────────────────────────────────────────────────
class _DetailsTab extends StatelessWidget {
  final Map<String, dynamic> opp;
  const _DetailsTab({required this.opp});

  @override
  Widget build(BuildContext context) {
    final stage = opp['stage']?.toString() ?? '';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status chips
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (stage.isNotEmpty) _stageChip(stage),
          if (opp['is_hot'] == true)
            StatusChip('🔥 HOT', color: kDanger),
          if ((opp['client_type']?.toString().trim() ?? '').isNotEmpty)
            StatusChip(str(opp['client_type']), color: kInfo),
        ]),
        const Divider(height: 24),
        // Product & Finance
        if ((opp['product_name']?.toString().trim() ?? '').isNotEmpty)
          InfoRow('Product', str(opp['product_name'])),
        if ((opp['product_type']?.toString().trim() ?? '').isNotEmpty)
          InfoRow('Category', str(opp['product_type'])),
        if (opp['amount'] != null)
          InfoRow('Budget', fmtInr(opp['amount'])),
        if (opp['offered_price'] != null)
          InfoRow('Offered Price', fmtInr(opp['offered_price'])),
        if ((opp['currency']?.toString().trim() ?? '').isNotEmpty &&
            opp['currency'] != 'INR')
          InfoRow('Currency', str(opp['currency'])),
        // Contact
        const Divider(height: 24),
        if ((opp['company_name']?.toString().trim() ?? '').isNotEmpty)
          InfoRow('Company', str(opp['company_name'])),
        if ((opp['lead_type']?.toString().trim() ?? '').isNotEmpty)
          InfoRow('Lead Source', str(opp['lead_type'])),
        if ((opp['contacted_by']?.toString().trim() ?? '').isNotEmpty)
          InfoRow('Contacted By', str(opp['contacted_by'])),
        if ((opp['contact_mode']?.toString().trim() ?? '').isNotEmpty)
          InfoRow('Contact Mode', str(opp['contact_mode'])),
        if ((opp['contact_number']?.toString().trim() ?? '').isNotEmpty)
          InfoRow('Phone', str(opp['contact_number'])),
        if ((opp['email']?.toString().trim() ?? '').isNotEmpty)
          InfoRow('Email', str(opp['email'])),
        // Location
        const Divider(height: 24),
        if ((opp['location']?.toString().trim() ?? '').isNotEmpty)
          InfoRow('Location', str(opp['location'])),
        if ((opp['country']?.toString().trim() ?? '').isNotEmpty)
          InfoRow('Country', str(opp['country'])),
        // Dates
        const Divider(height: 24),
        if (opp['lead_date'] != null)
          InfoRow('Lead Date', fmtDate(opp['lead_date'])),
        if (opp['meeting_at'] != null)
          InfoRow('Meeting Date', fmtDate(opp['meeting_at'])),
        if (opp['expected_delivery'] != null)
          InfoRow('Expected Delivery', fmtDate(opp['expected_delivery'])),
        if (opp['close_date'] != null)
          InfoRow('Close Date', fmtDate(opp['close_date'])),
        if ((opp['closed_by']?.toString().trim() ?? '').isNotEmpty)
          InfoRow('Closed By', str(opp['closed_by'])),
        // Remarks
        if ((opp['remarks']?.toString().trim() ?? '').isNotEmpty) ...[
          const Divider(height: 24),
          const Text('Remarks',
              style:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          Text(opp['remarks'].toString(),
              style: const TextStyle(fontSize: 13.5)),
        ],
        // Spec sheet
        if ((opp['spec_sheet_url']?.toString().trim() ?? '').isNotEmpty) ...[
          const Divider(height: 24),
          InfoRow('Spec Sheet', str(opp['spec_sheet_url'])),
        ],
        const SizedBox(height: 24),
        // Updated by
        if (opp['updated_at'] != null)
          Text('Last updated: ${fmtDate(opp['updated_at'])}${opp['updated_by'] != null ? ' by ${opp['updated_by']}' : ''}',
              style:
                  const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _stageChip(String stage) {
    const stageColors = <String, Color>{
      'NEW': Color(0xFF64748B),
      'CALL_1_DONE': Color(0xFF0EA5E9),
      'CALL_2_DONE': Color(0xFF6366F1),
      'CALL_3_DONE': Color(0xFF8B5CF6),
      'MEETING': Color(0xFFF59E0B),
      'PROPOSAL': Color(0xFFEF4444),
      'DEAL_DONE': Color(0xFF10B981),
      'LOW_BUDGET': Color(0xFF94A3B8),
      'GHOSTED': Color(0xFF6B7280),
      'NOT_INTERESTED': Color(0xFF9CA3AF),
      'FUTURE_LEAD': Color(0xFF34D399),
    };
    final color = stageColors[stage] ?? kInfo;
    final label = stage.replaceAll('_', ' ');
    return StatusChip(label, color: color);
  }
}

// ── Notes Tab ─────────────────────────────────────────────────────────────────
class _NotesTab extends StatefulWidget {
  final String oppId;
  final ErpRepository repo;
  const _NotesTab({required this.oppId, required this.repo});

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final notes = await widget.repo.crmNotesByTarget(widget.oppId);
      if (mounted) setState(() { _notes = notes; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _addNote() async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Note'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 5,
          decoration: const InputDecoration(
              hintText: 'Write a note…', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty || !mounted) return;
    try {
      await widget.repo.addCrmNote(widget.oppId, 'opportunity', text, 'Mobile App');
      await _load();
    } catch (e) {
      _showError('Failed to add note.\n\n$e');
    }
  }

  Future<void> _deleteNote(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kDanger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.repo.deleteCrmNote(id);
      await _load();
    } catch (e) {
      _showError('Failed to delete note.\n\n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Failed: $_error'),
        ElevatedButton(onPressed: _load, child: const Text('Retry')),
      ]));
    }
    return Stack(
      children: [
        _notes.isEmpty
            ? const Center(child: Text('No notes yet. Tap + to add one.'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                itemCount: _notes.length,
                itemBuilder: (_, i) {
                  final n = _notes[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(str(n['note']),
                                    style: const TextStyle(fontSize: 13.5)),
                                const SizedBox(height: 6),
                                Text(
                                  '${str(n['created_by'], 'Unknown')} · ${fmtDate(n['created_at'])}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: Colors.grey),
                            onPressed: () =>
                                _deleteNote(n['id']?.toString() ?? ''),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _addNote,
            backgroundColor: kBrand,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ── Tasks Tab ─────────────────────────────────────────────────────────────────
class _TasksTab extends StatefulWidget {
  final String oppId;
  final ErpRepository repo;
  const _TasksTab({required this.oppId, required this.repo});

  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
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
    setState(() { _loading = true; _error = null; });
    try {
      final tasks = await widget.repo.crmTasksByTarget(widget.oppId);
      if (mounted) setState(() { _tasks = tasks; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _addTask() async {
    final titleCtrl = TextEditingController();
    final assigneeCtrl = TextEditingController();
    String status = 'TODO';
    String? dueDate;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Add Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Task title *',
                    border: OutlineInputBorder()),
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
                    DropdownMenuItem(value: 'TODO', child: Text('To Do')),
                    DropdownMenuItem(
                        value: 'IN_PROGRESS', child: Text('In Progress')),
                    DropdownMenuItem(value: 'DONE', child: Text('Done')),
                  ],
                  onChanged: (v) { if (v != null) setSt(() => status = v); },
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: assigneeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Assigned to',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    if (titleCtrl.text.trim().isEmpty) {
      _showError('Task title is required.');
      return;
    }
    try {
      await widget.repo.addCrmTask(widget.oppId, 'opportunity', {
        'title': titleCtrl.text.trim(),
        'status': status,
        'assigned_to': assigneeCtrl.text.trim().isEmpty
            ? null
            : assigneeCtrl.text.trim(),
        'due_date': dueDate,
      });
      await _load();
    } catch (e) {
      _showError('Failed to add task.\n\n$e');
    }
  }

  Future<void> _updateStatus(String id, String currentStatus) async {
    const statuses = ['TODO', 'IN_PROGRESS', 'DONE'];
    final next = statuses[(statuses.indexOf(currentStatus) + 1) % statuses.length];
    try {
      await widget.repo.updateCrmTask(id, {'status': next});
      await _load();
    } catch (e) {
      _showError('Failed to update task.\n\n$e');
    }
  }

  Future<void> _deleteTask(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kDanger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.repo.deleteCrmTask(id);
      await _load();
    } catch (e) {
      _showError('Failed to delete task.\n\n$e');
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'DONE': return kSuccess;
      case 'IN_PROGRESS': return kWarning;
      default: return kInfo;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'DONE': return 'Done';
      case 'IN_PROGRESS': return 'In Progress';
      default: return 'To Do';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Failed: $_error'),
        ElevatedButton(onPressed: _load, child: const Text('Retry')),
      ]));
    }
    return Stack(
      children: [
        _tasks.isEmpty
            ? const Center(child: Text('No tasks yet. Tap + to add one.'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                itemCount: _tasks.length,
                itemBuilder: (_, i) {
                  final t = _tasks[i];
                  final id = t['id']?.toString() ?? '';
                  final status = t['status']?.toString() ?? 'TODO';
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: InkWell(
                        onTap: () => _updateStatus(id, status),
                        borderRadius: BorderRadius.circular(20),
                        child: Icon(
                          status == 'DONE'
                              ? Icons.check_circle
                              : status == 'IN_PROGRESS'
                                  ? Icons.pending
                                  : Icons.radio_button_unchecked,
                          color: _statusColor(status),
                          size: 24,
                        ),
                      ),
                      title: Text(str(t['title']),
                          style: TextStyle(
                              decoration: status == 'DONE'
                                  ? TextDecoration.lineThrough
                                  : null)),
                      subtitle: Text([
                        if ((t['assigned_to']?.toString().trim() ?? '')
                            .isNotEmpty)
                          'To: ${t['assigned_to']}',
                        if (t['due_date'] != null)
                          'Due ${fmtDate(t['due_date'])}',
                      ].join(' · ')),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        StatusChip(_statusLabel(status),
                            color: _statusColor(status)),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (v) {
                            if (v == 'delete') _deleteTask(id);
                            if (v.startsWith('status:')) {
                              _updateStatus(id, v.substring(7));
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'status:TODO',
                                child: Text('Mark To Do')),
                            const PopupMenuItem(
                                value: 'status:IN_PROGRESS',
                                child: Text('Mark In Progress')),
                            const PopupMenuItem(
                                value: 'status:DONE',
                                child: Text('Mark Done')),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete',
                                    style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ]),
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
    );
  }
}

// ── Activity Tab ──────────────────────────────────────────────────────────────
class _ActivityTab extends StatefulWidget {
  final String oppId;
  final ErpRepository repo;
  const _ActivityTab({required this.oppId, required this.repo});

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final acts = await widget.repo.crmActivitiesByTarget(widget.oppId);
      if (mounted) setState(() { _activities = acts; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Failed: $_error'),
        ElevatedButton(onPressed: _load, child: const Text('Retry')),
      ]));
    }
    if (_activities.isEmpty) {
      return const Center(child: Text('No activity recorded yet.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _activities.length,
      itemBuilder: (_, i) {
        final a = _activities[i];
        final type = str(a['type'], 'update');
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: kBrand.withValues(alpha: 0.12),
                  child: Icon(_activityIcon(type),
                      size: 14, color: kBrand),
                ),
                if (i < _activities.length - 1)
                  Container(
                    width: 2,
                    height: 40,
                    color: Colors.grey.withValues(alpha: 0.25),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          str(a['summary'] ?? a['description'],
                              type.replaceAll('_', ' ')),
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                    if ((a['description']?.toString().trim() ?? '').isNotEmpty &&
                        a['description'] != a['summary'])
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(str(a['description']),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${str(a['created_by'], 'System')} · ${fmtDate(a['created_at'])}',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static IconData _activityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'stage_change':   return Icons.swap_horiz;
      case 'note_added':     return Icons.note_add;
      case 'call':           return Icons.phone;
      case 'meeting':        return Icons.groups;
      case 'email':          return Icons.email;
      case 'deal_done':      return Icons.handshake;
      case 'created':        return Icons.fiber_new;
      default:               return Icons.history;
    }
  }
}
