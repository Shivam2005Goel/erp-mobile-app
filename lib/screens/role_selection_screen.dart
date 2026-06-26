import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/user_profile.dart';

/// Shown the first time a Google user signs in (no `final_employees` row yet).
/// Collects the workspace department, then creates a pending profile.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;
  String? _error;
  bool _loading = false;
  List<Department> _departments = [];
  bool _loadingDepartments = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDepartments());
  }

  Future<void> _loadDepartments() async {
    final depts = await AppStateScope.of(context).loadDepartments();
    if (!mounted) return;
    setState(() {
      _departments = depts.where((d) => d.roleKey != 'admin').toList();
      _loadingDepartments = false;
    });
  }

  Future<void> _submit() async {
    if (_selectedRole == null || _selectedRole!.isEmpty) {
      setState(() => _error = 'Please select a workspace department.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AppStateScope.of(context).completeGoogleRegistration(_selectedRole!);
      if (mounted) Navigator.pushReplacementNamed(context, '/pending');
    } catch (err) {
      setState(() => _error = err.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AppStateScope.of(context).googleEmail;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.badge_outlined,
                      size: 48, color: Color(0xFFf37021)),
                  const SizedBox(height: 16),
                  Text('One last step',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Text(
                    'Welcome${email != null ? ', $email' : ''}! Choose your workspace department to finish setting up your account.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(_error!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onErrorContainer)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Workspace Role / Department'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedRole,
                        hint: Text(_loadingDepartments
                            ? 'Loading departments…'
                            : 'Select Workspace Department'),
                        onChanged: _loadingDepartments
                            ? null
                            : (value) => setState(() => _selectedRole = value),
                        items: _departments
                            .map((d) => DropdownMenuItem(
                                value: d.roleKey, child: Text(d.name)))
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Submit for Approval'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            await AppStateScope.of(context).signOut();
                            if (context.mounted) {
                              Navigator.pushNamedAndRemoveUntil(
                                  context, '/login', (r) => false);
                            }
                          },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
