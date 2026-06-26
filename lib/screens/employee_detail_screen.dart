import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../data/erp_repository.dart';
import '../widgets/erp_ui.dart';
import '../widgets/record_form.dart';

const _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
const _roles = [
  'admin', 'hr', 'inventory', 'marketing', 'production', 'sales',
  'operations', 'it', 'designer'
];
const _statuses = ['active', 'inactive'];
const _types = ['permanent', 'intern'];
const _accountTypes = ['Savings', 'Current'];

class _Doc {
  final String key;
  final String label;
  final String slug;
  final IconData icon;
  const _Doc(this.key, this.label, this.slug, this.icon);
}

const _docTypes = <_Doc>[
  _Doc('photo_path', 'Personal Photo', 'photo', Icons.image_outlined),
  _Doc('aadhar_path', 'Aadhar Card', 'aadhar', Icons.badge_outlined),
  _Doc('pan_path', 'PAN Card', 'pan', Icons.credit_card),
  _Doc('offer_letter_path', 'Offer Letter', 'offer_letter',
      Icons.description_outlined),
  _Doc('cert_10th_path', '10th Certificate', 'cert_10th', Icons.school_outlined),
  _Doc('cert_12th_path', '12th Certificate', 'cert_12th', Icons.school_outlined),
  _Doc('ug_degree_path', 'UG Degree', 'ug_degree', Icons.workspace_premium_outlined),
  _Doc('pg_degree_path', 'PG Degree', 'pg_degree', Icons.workspace_premium_outlined),
];

/// Full employee record editor — personal, employment & bank details, document
/// uploads and the person's tasks. Mirrors the web "Employee Records" view.
class EmployeeDetailScreen extends StatefulWidget {
  /// Merged final_employees + employee_details row.
  final Map<String, dynamic> employee;
  final List<Map<String, dynamic>> allEmployees;
  const EmployeeDetailScreen(
      {super.key, required this.employee, required this.allEmployees});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  final _repo = ErpRepository();
  late Map<String, dynamic> _form;
  final _controllers = <String, TextEditingController>{};
  bool _saving = false;
  String? _uploadingDoc;

  late final String _email;
  bool _isHrAdmin = false;
  bool _isSelf = false;

  bool get _canEdit => _isHrAdmin || _isSelf;

  static const _textKeys = [
    'full_name',
    'phone_number',
    'emergency_contact_number',
    'present_address',
    'permanent_address',
    'bank_account_holder_name',
    'bank_name',
    'bank_account_number',
    'bank_ifsc_code',
    'bank_branch',
    'upi_id',
  ];

  @override
  void initState() {
    super.initState();
    _form = Map<String, dynamic>.from(widget.employee);
    _email = (_form['email'] ?? '').toString();
    for (final k in _textKeys) {
      _controllers[k] = TextEditingController(text: _form[k]?.toString() ?? '');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = AppStateScope.of(context).currentUser;
    _isHrAdmin = user?.role == 'admin' || user?.role == 'hr';
    _isSelf =
        (user?.email ?? '').toLowerCase() == _email.toLowerCase();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Pull current text values into the form.
    for (final k in _textKeys) {
      final t = _controllers[k]!.text.trim();
      _form[k] = t.isEmpty ? null : t;
    }
    try {
      // Personal + bank details (+ full_name) → employee_details (by email).
      final detailFields = {
        for (final k in [
          'full_name', 'dob', 'gender', 'phone_number',
          'emergency_contact_number', 'blood_group', 'present_address',
          'permanent_address', 'bank_account_holder_name', 'bank_name',
          'bank_account_number', 'bank_ifsc_code', 'bank_branch',
          'bank_account_type', 'upi_id',
        ])
          k: _form[k],
      };
      await _repo.saveEmployeeDetails(_email, detailFields);

      // Employment fields → final_employees (HR/admin only).
      if (_isHrAdmin) {
        await _repo.saveEmployment(_email, {
          'full_name': _form['full_name'],
          'role': _form['role'],
          'status': _form['status'],
          'type': _form['type'],
          'manager_id': _form['manager_id'],
          'joined_on': _form['joined_on'],
        });
      }
      if (mounted) toast(context, 'Details saved');
    } catch (e) {
      if (mounted) toast(context, 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadDoc(_Doc doc) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final XFile? file = await ImagePicker()
        .pickImage(source: source, imageQuality: 85, maxWidth: 2400);
    if (file == null) return;
    final bytes = await file.readAsBytes();

    setState(() => _uploadingDoc = doc.key);
    try {
      final oldPath = _form[doc.key]?.toString();
      final ext = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : 'jpg';
      final contentType = 'image/${ext == 'jpg' ? 'jpeg' : ext}';
      final path = await _repo.uploadEmployeeDoc(
          _email, doc.slug, file.name, bytes,
          contentType: contentType);
      await _repo.saveEmployeeDetails(_email, {doc.key: path});
      // Best-effort cleanup of the previous file.
      if (oldPath != null && oldPath.isNotEmpty && oldPath != path) {
        _repo.removeEmployeeDoc(oldPath).ignore();
      }
      setState(() => _form[doc.key] = path);
      if (mounted) toast(context, '${doc.label} uploaded');
    } catch (e) {
      if (mounted) toast(context, 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploadingDoc = null);
    }
  }

  Future<void> _viewDoc(String path) async {
    try {
      final url = await _repo.signedDocUrl(path);
      final ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!ok && mounted) toast(context, 'Could not open document');
    } catch (e) {
      if (mounted) toast(context, 'Could not open: $e');
    }
  }

  Future<void> _deleteDoc(_Doc doc, String path) async {
    if (!await confirmDelete(context, doc.label)) return;
    try {
      await _repo.saveEmployeeDetails(_email, {doc.key: null});
      _repo.removeEmployeeDoc(path).ignore();
      setState(() => _form[doc.key] = null);
    } catch (e) {
      if (mounted) toast(context, 'Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = str(_form['full_name'], _email);
    final empId = _form['employee_id'] is num
        ? (_form['employee_id'] as num).toInt()
        : int.tryParse('${_form['employee_id'] ?? ''}');
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 16)),
              Text(str(_form['role'], '').toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w400)),
            ],
          ),
          actions: [
            if (_canEdit)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save'),
                ),
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                  icon: Icon(Icons.person_outline, size: 17),
                  text: 'Personal Details'),
              Tab(
                  icon: Icon(Icons.checklist_rounded, size: 17),
                  text: 'Tasks'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ── Tab 1: Personal Details ──────────────────────────────
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(name),
                const SizedBox(height: 16),
                if (!_canEdit)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: _Banner(
                        'You have read-only access to this employee record.'),
                  ),
                if (_isSelf && !_isHrAdmin)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: _Banner(
                        'You can update your personal, bank & document details. Employment info is managed by HR.'),
                  ),
                _section('Personal Details', Icons.person_outline, [
                  _text('full_name', 'Full Name'),
                  _date('dob', 'Date of Birth'),
                  _dropdown('gender', 'Gender', _genders),
                  _dropdown('blood_group', 'Blood Group', _bloodGroups),
                  _text('phone_number', 'Phone Number'),
                  _text('emergency_contact_number', 'Emergency Contact'),
                  _text('present_address', 'Present Address', multiline: true),
                  _text('permanent_address', 'Permanent Address',
                      multiline: true),
                ]),
                _section('Employment', Icons.work_outline, [
                  _dropdown('role', 'Role', _roles, employmentField: true),
                  _dropdown('status', 'Status', _statuses,
                      employmentField: true),
                  _dropdown('type', 'Employment Type', _types,
                      employmentField: true),
                  _managerDropdown(),
                  _date('joined_on', 'Joined On', employmentField: true),
                ]),
                _section('Bank Details', Icons.account_balance_outlined, [
                  _text('bank_account_holder_name', 'Account Holder Name'),
                  _text('bank_name', 'Bank Name'),
                  _text('bank_account_number', 'Account Number'),
                  _text('bank_ifsc_code', 'IFSC Code'),
                  _text('bank_branch', 'Branch'),
                  _dropdown('bank_account_type', 'Account Type', _accountTypes),
                  _text('upi_id', 'UPI ID'),
                ]),
                _documents(),
              ],
            ),
            // ── Tab 2: Tasks ─────────────────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _TasksSection(
                repo: _repo,
                employeeId: empId,
                name: str(_form['full_name'], ''),
                email: _email,
                role: str(_form['role'], ''),
                isHrAdmin: _isHrAdmin,
                allEmployees: widget.allEmployees,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String name) {
    final docCount = _docTypes
        .where((d) => (_form[d.key]?.toString() ?? '').isNotEmpty)
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: kBrand.withValues(alpha: 0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: kBrand, fontWeight: FontWeight.bold, fontSize: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(_email,
                      style: TextStyle(
                          fontSize: 12.5,
                          color:
                              Theme.of(context).textTheme.bodySmall?.color)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    StatusChip(str(_form['role'], 'role').toUpperCase()),
                    StatusChip(str(_form['status'], 'active'),
                        color: statusColor(_form['status']?.toString())),
                    StatusChip('$docCount/${_docTypes.length} docs',
                        color: docCount == _docTypes.length
                            ? kSuccess
                            : kInfo),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> fields) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: kBrand),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 14),
            ...fields,
          ],
        ),
      ),
    );
  }

  bool _enabled(bool employmentField) =>
      employmentField ? _isHrAdmin : _canEdit;

  Widget _text(String key, String label, {bool multiline = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _controllers[key],
        enabled: _canEdit,
        maxLines: multiline ? 3 : 1,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _dropdown(String key, String label, List<String> options,
      {bool employmentField = false}) {
    final current = _form[key]?.toString();
    final value = options.contains(current) ? current : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: _enabled(employmentField)
            ? (v) => setState(() => _form[key] = v)
            : null,
      ),
    );
  }

  Widget _managerDropdown() {
    final managers = widget.allEmployees
        .where((m) =>
            m['employee_id'] != null &&
            (m['email'] ?? '').toString().toLowerCase() != _email.toLowerCase())
        .toList();
    final current = _form['manager_id'];
    final currentStr = current?.toString();
    final hasMatch =
        managers.any((m) => m['employee_id'].toString() == currentStr);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: hasMatch ? currentStr : null,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Manager'),
        items: [
          const DropdownMenuItem(value: null, child: Text('— None —')),
          ...managers.map((m) => DropdownMenuItem(
                value: m['employee_id'].toString(),
                child: Text(str(m['full_name'], m['email'])),
              )),
        ],
        onChanged: _isHrAdmin
            ? (v) => setState(() =>
                _form['manager_id'] = v == null ? null : int.tryParse(v))
            : null,
      ),
    );
  }

  Widget _date(String key, String label, {bool employmentField = false}) {
    final raw = _form[key]?.toString();
    final d = raw == null ? null : DateTime.tryParse(raw);
    final enabled = _enabled(employmentField);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: enabled
            ? () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: d ?? DateTime(2000),
                  firstDate: DateTime(1950),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() =>
                      _form[key] = DateFormat('yyyy-MM-dd').format(picked));
                }
              }
            : null,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today, size: 18),
            enabled: enabled,
          ),
          child: Text(
            d == null ? 'Select date' : DateFormat('dd MMM yyyy').format(d),
            style: TextStyle(
                color: d == null
                    ? Theme.of(context).hintColor
                    : Theme.of(context).textTheme.bodyLarge?.color),
          ),
        ),
      ),
    );
  }

  Widget _documents() {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.folder_outlined, size: 18, color: kBrand),
              const SizedBox(width: 8),
              const Text('Documents',
                  style: TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            Text('Private bucket • images & PDF up to 10 MB',
                style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(context).textTheme.bodySmall?.color)),
            const SizedBox(height: 12),
            ..._docTypes.map(_docTile),
          ],
        ),
      ),
    );
  }

  Widget _docTile(_Doc doc) {
    final path = _form[doc.key]?.toString();
    final hasFile = path != null && path.isNotEmpty;
    final uploading = _uploadingDoc == doc.key;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: hasFile
                ? kSuccess.withValues(alpha: 0.4)
                : Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Icon(doc.icon, size: 20, color: hasFile ? kSuccess : kBrand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13.5)),
                Text(hasFile ? 'Uploaded' : 'Missing',
                    style: TextStyle(
                        fontSize: 11,
                        color: hasFile ? kSuccess : Theme.of(context).hintColor)),
              ],
            ),
          ),
          if (uploading)
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            if (hasFile)
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 20),
                tooltip: 'View',
                color: kInfo,
                onPressed: () => _viewDoc(path),
              ),
            if (_canEdit)
              IconButton(
                icon: Icon(hasFile ? Icons.refresh : Icons.upload_outlined,
                    size: 20),
                tooltip: hasFile ? 'Replace' : 'Upload',
                color: kBrand,
                onPressed: () => _uploadDoc(doc),
              ),
            if (_canEdit && hasFile)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Delete',
                color: kDanger,
                onPressed: () => _deleteDoc(doc, path),
              ),
          ],
        ],
      ),
    );
  }

}

// ── Tasks section ────────────────────────────────────────────────────────────

class _TasksSection extends StatefulWidget {
  final ErpRepository repo;
  final int? employeeId;
  final String name;
  final String email;
  final String role;
  final bool isHrAdmin;
  final List<Map<String, dynamic>> allEmployees;

  const _TasksSection({
    required this.repo,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.role,
    required this.isHrAdmin,
    required this.allEmployees,
  });

  @override
  State<_TasksSection> createState() => _TasksSectionState();
}

class _TasksSectionState extends State<_TasksSection> {
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  String _filter = 'All';

  static const _allFilters = ['All', 'Done', 'In Progress', 'Pending', 'Blocked'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final t = await widget.repo.employeeTasks(
        employeeId: widget.employeeId,
        name: widget.name,
      );
      if (mounted) setState(() { _tasks = t; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _match(Map<String, dynamic> t, String f) {
    final s = (t['status'] ?? '').toString().toLowerCase();
    switch (f) {
      case 'Done': return s.contains('done') || s.contains('complete');
      case 'In Progress': return s.contains('progress');
      case 'Pending': return s.contains('pending');
      case 'Blocked': return s.contains('block');
      default: return true;
    }
  }

  int _count(String f) =>
      f == 'All' ? _tasks.length : _tasks.where((t) => _match(t, f)).length;

  List<Map<String, dynamic>> get _filtered =>
      _filter == 'All' ? _tasks : _tasks.where((t) => _match(t, _filter)).toList();

  List<String> get _employeeNames {
    final names = widget.allEmployees
        .map((e) => (e['full_name'] ?? '').toString().trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return names;
  }

  Future<void> _addTask() async {
    final names = _employeeNames;
    final result = await showRecordForm(
      context,
      title: 'Add Task for ${widget.name}',
      fields: [
        const FieldSpec('task', 'Task', required: true, type: FieldType.multiline),
        FieldSpec('assigned_to', 'Assigned to',
            type: FieldType.dropdown, options: names),
        FieldSpec('assigned_by', 'Assigned by',
            type: FieldType.dropdown, options: names),
        const FieldSpec('status', 'Status',
            type: FieldType.dropdown,
            options: ['Pending', 'In Progress', 'Done', 'Completed', 'Blocked']),
        const FieldSpec('start_date', 'Start date', type: FieldType.date),
        const FieldSpec('end_date', 'End date', type: FieldType.date),
        const FieldSpec('notes', 'Notes', type: FieldType.multiline),
      ],
      initial: {'assigned_to': widget.name, 'status': 'Pending'},
    );
    if (result == null) return;
    final data = <String, dynamic>{...result, 'assigned_to': widget.name};
    if (widget.employeeId != null) data['employee_id'] = widget.employeeId;
    try {
      await widget.repo.create('tasks', data);
      _load();
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
  }

  Future<void> _editTask(Map<String, dynamic> task) async {
    final names = _employeeNames;
    final result = await showRecordForm(
      context,
      title: 'Edit Task',
      fields: [
        const FieldSpec('task', 'Task', required: true, type: FieldType.multiline),
        FieldSpec('assigned_to', 'Assigned to',
            type: FieldType.dropdown, options: names),
        FieldSpec('assigned_by', 'Assigned by',
            type: FieldType.dropdown, options: names),
        const FieldSpec('status', 'Status',
            type: FieldType.dropdown,
            options: ['Pending', 'In Progress', 'Done', 'Completed', 'Blocked']),
        const FieldSpec('start_date', 'Start date', type: FieldType.date),
        const FieldSpec('end_date', 'End date', type: FieldType.date),
        const FieldSpec('reason_for_delay', 'Reason for delay'),
        const FieldSpec('notes', 'Notes', type: FieldType.multiline),
      ],
      initial: task,
    );
    if (result == null) return;
    try {
      await widget.repo.updateRow('tasks', 'id', task['id'], result);
      _load();
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    if (!await confirmDelete(context, 'this task')) return;
    try {
      await widget.repo.deleteRow('tasks', 'id', task['id']);
      _load();
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
  }

  Future<void> _applyLeave() async {
    final result = await showRecordForm(
      context,
      title: 'Apply Leave',
      fields: const [
        FieldSpec('employee_name', 'Employee', required: true),
        FieldSpec('department', 'Department'),
        FieldSpec('leave_type', 'Leave type',
            type: FieldType.dropdown,
            options: ['Sick Leave', 'Casual Leave', 'Annual Leave', 'Emergency Leave']),
        FieldSpec('start_date', 'Start date', type: FieldType.date),
        FieldSpec('end_date', 'End date', type: FieldType.date),
        FieldSpec('total_days', 'Total days', type: FieldType.number),
        FieldSpec('reason', 'Reason', type: FieldType.multiline),
      ],
      initial: {'employee_name': widget.name, 'department': widget.role, 'status': 'Pending'},
    );
    if (result == null) return;
    try {
      await widget.repo.create('leave_requests', {...result, 'status': 'Pending'});
      if (mounted) toast(context, 'Leave request submitted');
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _tasks.length;
    final doneCount = _count('Done');
    final inProgressCount = _count('In Progress');
    final pendingCount = _count('Pending');
    final blockedCount = _count('Blocked');

    return Card(
      margin: const EdgeInsets.only(top: 12, bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header + action buttons
            Row(children: [
              const Icon(Icons.checklist_rounded, size: 18, color: kBrand),
              const SizedBox(width: 8),
              Text('Tasks · $total',
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w800)),
              const Spacer(),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  textStyle: const TextStyle(fontSize: 11),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _applyLeave,
                icon: const Icon(Icons.event_available_outlined, size: 13),
                label: const Text('Apply Leave'),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: kBrand,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  textStyle: const TextStyle(fontSize: 11),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _addTask,
                icon: const Icon(Icons.add, size: 13),
                label: const Text('Add Task'),
              ),
            ]),
            const SizedBox(height: 14),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              // Donut chart
              if (total > 0) ...[
                _buildChart(doneCount, inProgressCount, pendingCount, blockedCount),
                const SizedBox(height: 14),
              ],

              // Filter pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _allFilters.map((f) {
                    final selected = _filter == f;
                    final cnt = _count(f);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? kBrand.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: selected
                                    ? kBrand
                                    : Theme.of(context).dividerColor),
                          ),
                          child: Text(
                            f == 'All' ? 'All' : '$f ($cnt)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? kBrand
                                  : Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              // Task cards
              if (_filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No tasks in "$_filter"',
                        style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 13)),
                  ),
                )
              else
                ..._filtered.map(_taskCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChart(int done, int inProgress, int pending, int blocked) {
    final sections = <PieChartSectionData>[];
    void add(int n, Color c) {
      if (n > 0) {
        sections.add(PieChartSectionData(
            value: n.toDouble(), color: c, radius: 38, showTitle: false));
      }
    }
    add(done, kBrand);
    add(inProgress, kInfo);
    add(pending, kWarning);
    add(blocked, kDanger);
    if (sections.isEmpty) return const SizedBox.shrink();

    return Row(children: [
      SizedBox(
        width: 110,
        height: 110,
        child: PieChart(PieChartData(
          sections: sections,
          centerSpaceRadius: 28,
          sectionsSpace: 2,
        )),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TASK DISTRIBUTION',
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey,
                    letterSpacing: 0.8)),
            const SizedBox(height: 8),
            if (done > 0) _legendRow(kBrand, 'Done', done),
            if (inProgress > 0) _legendRow(kInfo, 'In Progress', inProgress),
            if (pending > 0) _legendRow(kWarning, 'Pending', pending),
            if (blocked > 0) _legendRow(kDanger, 'Blocked', blocked),
          ],
        ),
      ),
    ]);
  }

  Widget _legendRow(Color color, String label, int count) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Container(
              width: 9, height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
          const Spacer(),
          Text('$count',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _taskCard(Map<String, dynamic> t) {
    final status = t['status']?.toString() ?? '';
    final color = statusColor(status);
    final start = fmtDate(t['start_date']);
    final end = fmtDate(t['end_date']);
    final hasDate = t['start_date'] != null || t['end_date'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(str(t['task']),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13.5)),
              const SizedBox(height: 5),
              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                StatusChip(
                  status.isEmpty ? 'N/A' : status.toUpperCase(),
                  color: color,
                ),
                if (hasDate)
                  Text('$start → $end',
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color)),
              ]),
            ],
          ),
        ),
        if (widget.isHrAdmin) ...[
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 17),
            color: Colors.grey,
            visualDensity: VisualDensity.compact,
            tooltip: 'Edit',
            onPressed: () => _editTask(t),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 17),
            color: kDanger,
            visualDensity: VisualDensity.compact,
            tooltip: 'Delete',
            onPressed: () => _deleteTask(t),
          ),
        ],
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  const _Banner(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kInfo.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kInfo.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline, size: 18, color: kInfo),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12.5, color: kInfo))),
      ]),
    );
  }
}
