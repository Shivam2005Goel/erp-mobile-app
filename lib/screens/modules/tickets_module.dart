import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../data/erp_repository.dart';
import '../../widgets/crud_list.dart';
import '../../widgets/erp_ui.dart';
import '../../widgets/record_form.dart';

const _categories = [
  'Order Issue',
  'Inventory Issue',
  'HR / Team',
  'Production / Operations',
  'Sales / CRM',
  'Marketing',
  'Technical / System',
  'Other',
];
const _priorities = ['Low', 'Medium', 'High', 'Urgent'];
const _statuses = ['Open', 'In Progress', 'Resolved', 'Closed'];

/// Support Tickets: raise, route, update and resolve internal/after-sales tickets.
class TicketsModule extends StatelessWidget {
  TicketsModule({super.key});
  final _repo = ErpRepository();

  @override
  Widget build(BuildContext context) {
    final user = AppStateScope.of(context).currentUser;

    return CrudList(
      repo: _repo,
      table: 'support_tickets',
      idCol: 'id',
      addLabel: 'Raise Ticket',
      editLabel: 'Update Ticket',
      loader: _repo.supportTickets,
      emptyMessage: 'No support tickets.',
      prepareCreate: (data) {
        // Stamp the reporter from the signed-in profile, matching the web app.
        data['raised_by_id'] = user?.id;
        data['raised_by_name'] = user?.fullName;
        data['raised_by_email'] = user?.email;
        data['raised_by_role'] = user?.role;
        data['status'] ??= 'Open';
        return data;
      },
      fields: () => const [
        FieldSpec('title', 'Title', required: true),
        FieldSpec('description', 'Description',
            required: true, type: FieldType.multiline),
        FieldSpec('category', 'Category',
            type: FieldType.dropdown, options: _categories, required: true),
        FieldSpec('priority', 'Priority',
            type: FieldType.dropdown, options: _priorities),
        FieldSpec('status', 'Status',
            type: FieldType.dropdown, options: _statuses),
        FieldSpec('assigned_to', 'Assigned to'),
        FieldSpec('resolution', 'Resolution', type: FieldType.multiline),
      ],
      header: (context, list, onAdd) {
        final open = list
            .where((t) =>
                (t['status']?.toString() ?? '').toLowerCase() != 'closed' &&
                (t['status']?.toString() ?? '').toLowerCase() != 'resolved')
            .length;
        return MetricRow(children: [
          MetricCard(
              label: 'Total Tickets',
              value: '${list.length}',
              icon: Icons.confirmation_number),
          MetricCard(
              label: 'Open',
              value: '$open',
              icon: Icons.mark_email_unread,
              color: kWarning),
          MetricCard(
              label: 'Resolved',
              value: '${list.length - open}',
              icon: Icons.task_alt,
              color: kSuccess),
        ]);
      },
      tile: (t, onEdit, onDelete) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          onTap: onEdit,
          leading: CircleAvatar(
            backgroundColor:
                statusColor(t['priority']?.toString()).withValues(alpha: 0.15),
            child: Text('#${str(t['ticket_number'], '?')}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor(t['priority']?.toString()))),
          ),
          title: Text(str(t['title'])),
          subtitle: Text([
            str(t['category'], ''),
            'By ${str(t['raised_by_name'])}',
            if ((t['assigned_to']?.toString().trim() ?? '').isNotEmpty)
              '→ ${t['assigned_to']}',
          ].where((s) => s.isNotEmpty).join(' • ')),
          isThreeLine: true,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            StatusChip(str(t['status'], 'open'),
                color: statusColor(t['status']?.toString())),
            RowMenu(onEdit: onEdit, onDelete: onDelete),
          ]),
        ),
      ),
    );
  }
}
