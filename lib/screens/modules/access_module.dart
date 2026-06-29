import 'package:flutter/material.dart';

import '../../data/erp_repository.dart';
import '../../widgets/erp_ui.dart';

const _roles = [
  'admin', 'hr', 'finance', 'inventory', 'marketing',
  'production', 'sales', 'operations', 'it', 'designer',
];

/// Access Admin: manage user roles and approval status.
/// Mirrors the Next.js /dashboard/access page.
class AccessModule extends StatelessWidget {
  const AccessModule({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [Tab(text: 'Users'), Tab(text: 'Pending Approvals')],
          ),
          const Expanded(
            child: TabBarView(
              children: [_UsersTab(), _PendingTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Users Tab ─────────────────────────────────────────────────────────────────
class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _repo = ErpRepository();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final users = await _repo.allUsersForAdmin();
      if (mounted) setState(() { _users = users; _loading = false; });
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

  Future<void> _editUser(Map<String, dynamic> u) async {
    String role = u['role']?.toString() ?? 'sales';
    String status = u['status']?.toString() ?? 'active';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Edit ${u['full_name'] ?? u['email']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Role', isDense: true),
                child: DropdownButton<String>(
                  value: _roles.contains(role) ? role : null,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) { if (v != null) setSt(() => role = v); },
                ),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Status', isDense: true),
                child: DropdownButton<String>(
                  value: ['active', 'inactive'].contains(status) ? status : 'active',
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (v) { if (v != null) setSt(() => status = v); },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repo.updateUserRole(u['id'].toString(), role);
      await _repo.updateUserStatus(u['id'].toString(), status);
      await _load();
    } catch (e) {
      _showError('Failed to update user.\n\n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Failed: $_error'),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _load, child: const Text('Retry')),
      ]));
    }

    final q = _search.trim().toLowerCase();
    final list = q.isEmpty
        ? _users
        : _users.where((u) =>
            '${u['full_name'] ?? ''} ${u['email'] ?? ''} ${u['role'] ?? ''} ${u['department'] ?? ''}'
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
                  hintText: 'Search users…',
                  prefixIcon: Icon(Icons.search),
                  isDense: true),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              MetricCard(label: 'Total Users', value: '${_users.length}', icon: Icons.people),
              const SizedBox(width: 10),
              MetricCard(
                label: 'Active',
                value: '${_users.where((u) => u['status'] == 'active').length}',
                icon: Icons.check_circle,
                color: kSuccess,
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('No users found.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _UserCard(
                      user: list[i],
                      onEdit: () => _editUser(list[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  const _UserCard({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final name = str(user['full_name'], user['email']?.toString() ?? '?');
    final role = str(user['role'], 'n/a');
    final status = str(user['status'], 'active');
    final approval = str(user['approval_status'], 'approved');
    final initials =
        name.split(' ').map((p) => p.isEmpty ? '' : p[0].toUpperCase()).take(2).join();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kBrand.withValues(alpha: 0.15),
          child: Text(initials,
              style: TextStyle(
                  color: kBrand, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(str(user['email'], ''),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if ((user['department']?.toString().trim() ?? '').isNotEmpty)
              Text(str(user['department']),
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        isThreeLine: (user['department']?.toString().trim() ?? '').isNotEmpty,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            StatusChip(role, color: kBrand),
            const SizedBox(height: 4),
            StatusChip(
              status,
              color: status == 'active' ? kSuccess : kDanger,
            ),
            if (approval == 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: StatusChip('PENDING', color: kWarning),
              ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

// ── Pending Approvals Tab ─────────────────────────────────────────────────────
class _PendingTab extends StatefulWidget {
  const _PendingTab();
  @override
  State<_PendingTab> createState() => _PendingTabState();
}

class _PendingTabState extends State<_PendingTab> {
  final _repo = ErpRepository();
  List<Map<String, dynamic>> _all = [];
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
      final users = await _repo.allUsersForAdmin();
      if (mounted) {
        setState(() {
          _all = users.where((u) => u['approval_status'] == 'pending').toList();
          _loading = false;
        });
      }
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

  Future<void> _approve(Map<String, dynamic> u) async {
    try {
      await _repo.updateUserApproval(u['id'].toString(), 'approved');
      await _repo.updateUserStatus(u['id'].toString(), 'active');
      await _load();
    } catch (e) {
      _showError('Failed to approve user.\n\n$e');
    }
  }

  Future<void> _reject(Map<String, dynamic> u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject User?'),
        content: Text('Reject ${u['full_name'] ?? u['email']}? They will not be able to log in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kDanger),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.updateUserApproval(u['id'].toString(), 'rejected');
      await _load();
    } catch (e) {
      _showError('Failed to reject user.\n\n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Failed: $_error'),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _load, child: const Text('Retry')),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          MetricCard(
            label: 'Awaiting Approval',
            value: '${_all.length}',
            icon: Icons.hourglass_empty,
            color: kWarning,
          ),
          const SizedBox(height: 16),
          if (_all.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: Text('No pending approvals.'),
            ))
          else
            ..._all.map((u) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          CircleAvatar(
                            backgroundColor: kWarning.withValues(alpha: 0.15),
                            child: Icon(Icons.person, color: kWarning, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(str(u['full_name'], '—'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                Text(str(u['email'], '—'),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          if ((u['role']?.toString().trim() ?? '').isNotEmpty)
                            StatusChip(str(u['role']), color: kBrand),
                          if ((u['department']?.toString().trim() ?? '').isNotEmpty)
                            StatusChip(str(u['department']), color: kInfo),
                          if (u['joined_on'] != null)
                            StatusChip('Joined ${fmtDate(u['joined_on'])}',
                                color: Colors.grey),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _reject(u),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kDanger,
                                side: BorderSide(color: kDanger),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _approve(u),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kSuccess,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
