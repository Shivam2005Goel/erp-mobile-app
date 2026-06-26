import 'package:flutter/material.dart';

import '../../data/erp_repository.dart';
import '../../widgets/crud_list.dart';
import '../../widgets/erp_ui.dart';
import '../../widgets/record_form.dart';
import '../employee_detail_screen.dart';

/// Team & HR: employees, factory workers, tasks and leave management.
class HrModule extends StatelessWidget {
  HrModule({super.key});
  final _repo = ErpRepository();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Employees'),
              Tab(text: 'Factory Workers'),
              Tab(text: 'Tasks'),
              Tab(text: 'Leave'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _Employees(repo: _repo),
                _factoryWorkers(),
                _tasks(),
                _leave(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _factoryWorkers() => CrudList(
        repo: _repo,
        table: 'factory_workers',
        idCol: 'phone_number',
        addLabel: 'Add Factory Worker',
        editLabel: 'Edit Factory Worker',
        loader: _repo.factoryWorkers,
        emptyMessage: 'No factory workers yet.',
        fields: () => const [
          FieldSpec('employee_name', 'Name', required: true),
          FieldSpec('phone_number', 'Phone number', required: true),
          FieldSpec('role', 'Role'),
          FieldSpec('email', 'Email'),
          FieldSpec('gender', 'Gender',
              type: FieldType.dropdown,
              options: ['Male', 'Female', 'Other', 'Prefer not to say']),
          FieldSpec('blood_group', 'Blood group',
              type: FieldType.dropdown,
              options: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']),
          FieldSpec('joining_date', 'Joining date', type: FieldType.date),
          FieldSpec('contract_end', 'Contract end', type: FieldType.date),
          FieldSpec('esi_number', 'ESI number'),
          FieldSpec('pf_number', 'PF number'),
          FieldSpec('emergency_contact_number', 'Emergency contact'),
          FieldSpec('present_address', 'Present address',
              type: FieldType.multiline),
          FieldSpec('notes', 'Notes', type: FieldType.multiline),
        ],
        tile: (w, onEdit, onDelete) => Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            onTap: onEdit,
            leading: const CircleAvatar(child: Icon(Icons.engineering)),
            title: Text(str(w['employee_name'])),
            subtitle: Text([
              str(w['role'], ''),
              if ((w['phone_number']?.toString().trim() ?? '').isNotEmpty)
                '📞 ${w['phone_number']}',
              'Joined ${fmtDate(w['joining_date'])}',
            ].where((s) => s.isNotEmpty).join(' • ')),
            trailing: RowMenu(onEdit: onEdit, onDelete: onDelete),
          ),
        ),
      );

  Widget _tasks() => CrudList(
        repo: _repo,
        table: 'tasks',
        idCol: 'id',
        addLabel: 'Add Task',
        editLabel: 'Edit Task',
        loader: _repo.tasks,
        emptyMessage: 'No tasks yet.',
        fields: () => const [
          FieldSpec('task', 'Task', required: true, type: FieldType.multiline),
          FieldSpec('assigned_to', 'Assigned to'),
          FieldSpec('assigned_by', 'Assigned by'),
          FieldSpec('status', 'Status',
              type: FieldType.dropdown,
              options: ['Pending', 'In Progress', 'Done', 'Completed']),
          FieldSpec('start_date', 'Start date', type: FieldType.date),
          FieldSpec('end_date', 'End date', type: FieldType.date),
          FieldSpec('reason_for_delay', 'Reason for delay'),
          FieldSpec('notes', 'Notes', type: FieldType.multiline),
        ],
        tile: (t, onEdit, onDelete) => Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            onTap: onEdit,
            title: Text(str(t['task'])),
            subtitle: Text([
              'To: ${str(t['assigned_to'])}',
              if ((t['end_date']?.toString().trim() ?? '').isNotEmpty)
                'Due ${fmtDate(t['end_date'])}',
              if ((t['notes']?.toString().trim() ?? '').isNotEmpty) t['notes'],
            ].join(' • ')),
            isThreeLine: (t['notes']?.toString().trim() ?? '').isNotEmpty,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              StatusChip(str(t['status'], 'n/a'),
                  color: statusColor(t['status']?.toString())),
              RowMenu(onEdit: onEdit, onDelete: onDelete),
            ]),
          ),
        ),
      );

  Widget _leave() => CrudList(
        repo: _repo,
        table: 'leave_requests',
        idCol: 'id',
        addLabel: 'Add Leave Request',
        editLabel: 'Edit Leave Request',
        loader: _repo.leaveRequests,
        emptyMessage: 'No leave requests.',
        fields: () => const [
          FieldSpec('employee_name', 'Employee', required: true),
          FieldSpec('department', 'Department'),
          FieldSpec('leave_type', 'Leave type',
              type: FieldType.dropdown,
              options: [
                'Sick Leave',
                'Casual Leave',
                'Annual Leave',
                'Emergency Leave'
              ]),
          FieldSpec('start_date', 'Start date', type: FieldType.date),
          FieldSpec('end_date', 'End date', type: FieldType.date),
          FieldSpec('total_days', 'Total days', type: FieldType.number),
          FieldSpec('status', 'Status',
              type: FieldType.dropdown,
              options: ['Pending', 'Approved', 'Rejected']),
          FieldSpec('reason', 'Reason', type: FieldType.multiline),
        ],
        tile: (l, onEdit, onDelete) => Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            onTap: onEdit,
            leading: const Icon(Icons.beach_access),
            title: Text('${str(l['employee_name'])} • ${str(l['leave_type'])}'),
            subtitle: Text(
                '${fmtDate(l['start_date'])} → ${fmtDate(l['end_date'])} • ${str(l['total_days'])} day(s)'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              StatusChip(str(l['status'], 'n/a'),
                  color: statusColor(l['status']?.toString())),
              RowMenu(onEdit: onEdit, onDelete: onDelete),
            ]),
          ),
        ),
      );
}

/// Employee Records — searchable grid. Each card shows task stats (done /
/// total / completion rate). Tap a card to open the full employee record.
class _Employees extends StatefulWidget {
  final ErpRepository repo;
  const _Employees({required this.repo});
  @override
  State<_Employees> createState() => _EmployeesState();
}

class _EmployeesState extends State<_Employees> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _allTasks = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.repo.employeeRecords(),
        widget.repo.tasks(),
      ]);
      if (mounted) {
        setState(() {
          _employees = results[0];
          _allTasks = results[1];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  ({int done, int total}) _stats(Map<String, dynamic> emp) {
    final name = (emp['full_name'] ?? '').toString().toLowerCase();
    final empIdRaw = emp['employee_id'];
    final empId = empIdRaw is num
        ? empIdRaw.toInt()
        : int.tryParse('${empIdRaw ?? ''}');
    final myTasks = _allTasks.where((t) {
      if (empId != null && t['employee_id'] != null) {
        final tid = t['employee_id'] is num
            ? (t['employee_id'] as num).toInt()
            : int.tryParse('${t['employee_id']}');
        if (tid != null) return tid == empId;
      }
      return (t['assigned_to'] ?? '').toString().toLowerCase() == name;
    }).toList();
    final total = myTasks.length;
    final done = myTasks.where((t) {
      final s = (t['status'] ?? '').toString().toLowerCase();
      return s.contains('done') || s.contains('complete');
    }).length;
    return (done: done, total: total);
  }

  Future<void> _open(Map<String, dynamic> e) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EmployeeDetailScreen(
        employee: e,
        allEmployees: _employees,
      ),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Failed: $_error'),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }

    final q = _search.trim().toLowerCase();
    final list = q.isEmpty
        ? _employees
        : _employees
            .where((e) =>
                '${e['full_name'] ?? ''} ${e['email'] ?? ''} ${e['role'] ?? ''}'
                    .toLowerCase()
                    .contains(q))
            .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Search employees…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('No employees found.'))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.78,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) => _card(ctx, list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> e) {
    final s = _stats(e);
    final name = str(e['full_name'], '?');
    final role = str(e['role'], '').toLowerCase();
    final status = (e['status'] ?? 'active').toString().toLowerCase();
    final rate = s.total > 0 ? '${(s.done * 100 ~/ s.total)}%' : '—';
    return GestureDetector(
      onTap: () => _open(e),
      child: Card(
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF757575),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        Text(role,
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              StatusChip(
                status.toUpperCase(),
                color: status == 'active' ? kSuccess : kDanger,
              ),
              const SizedBox(height: 8),
              const Divider(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat(s.done.toString(), 'DONE', kBrand),
                  _stat(s.total.toString(), 'TOTAL',
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black87),
                  _stat(rate, 'RATE', kInfo),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 15)),
          Text(label,
              style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
        ],
      );
}
