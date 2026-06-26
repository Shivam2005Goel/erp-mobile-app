import 'package:flutter/material.dart';

import '../../data/erp_repository.dart';
import '../../widgets/erp_ui.dart';
import '../../widgets/record_form.dart';

/// Pipeline stages mirror the web app's `crmEntities.PIPELINE_STAGES` and the
/// DB stage CHECK constraint (NEW … NOT_INTERESTED).
class _Stage {
  final String value;
  final String label;
  final Color color;
  const _Stage(this.value, this.label, this.color);
}

const _stages = <_Stage>[
  _Stage('NEW', 'New', Color(0xFFEF4444)),
  _Stage('SCREENING', 'Screening', Color(0xFFA855F7)),
  _Stage('MEETING', 'Meeting', Color(0xFF60A5FA)),
  _Stage('PROPOSAL', 'Proposal', Color(0xFF2DD4BF)),
  _Stage('DEAL_DONE', 'Deal Done', Color(0xFF22C55E)),
  _Stage('LOW_BUDGET', 'Low Budget', Color(0xFFF97316)),
  _Stage('FUTURE_LEAD', 'Future Leads', Color(0xFF9B8BFF)),
  _Stage('GHOSTED', 'Ghosted', Color(0xFF94A3B8)),
  _Stage('NOT_INTERESTED', 'Not Interested', Color(0xFFDC2626)),
];

const _stageValues = [
  'NEW',
  'SCREENING',
  'MEETING',
  'PROPOSAL',
  'DEAL_DONE',
  'LOW_BUDGET',
  'FUTURE_LEAD',
  'GHOSTED',
  'NOT_INTERESTED',
];

const _contactedBy = ['Angad', 'Sneha', 'Akshay'];
const _contactModes = ['WhatsApp Text', 'Call'];
const _leadTypes = [
  'Website',
  'Instagram',
  'Google',
  'Reference',
  'CasinoCart',
  'Old Client',
  'Walk In',
];
const _currencies = ['INR', 'USD', 'EUR', 'GBP', 'AED'];
const _productCategories = [
  'Pool Tables',
  'TT Tables',
  'Air Hockey Tables',
  'Accessories',
  'Carrom Tables',
  'Bar Cabinets',
  'Home Bars',
  'Snooker Tables',
  'Foosball Tables',
  'Chess Tables',
  'Bar Counters',
  'DJ Tables',
  'Bar Stools',
];

List<FieldSpec> _oppFields() => const [
      FieldSpec('name', 'Opportunity / Client', required: true),
      FieldSpec('company_name', 'Company'),
      FieldSpec('stage', 'Stage',
          type: FieldType.dropdown, options: _stageValues, required: true),
      FieldSpec('lead_type', 'Lead source',
          type: FieldType.dropdown, options: _leadTypes),
      FieldSpec('product_type', 'Product type',
          type: FieldType.dropdown, options: _productCategories),
      FieldSpec('product_name', 'Product'),
      FieldSpec('amount', 'Budget amount', type: FieldType.number),
      FieldSpec('offered_price', 'Offered price', type: FieldType.number),
      FieldSpec('currency', 'Currency',
          type: FieldType.dropdown, options: _currencies),
      FieldSpec('contacted_by', 'Contacted by',
          type: FieldType.dropdown, options: _contactedBy),
      FieldSpec('contact_mode', 'Contact mode',
          type: FieldType.dropdown, options: _contactModes),
      FieldSpec('contact_number', 'Contact number'),
      FieldSpec('email', 'Email'),
      FieldSpec('location', 'Location'),
      FieldSpec('country', 'Country'),
      FieldSpec('lead_date', 'Lead date', type: FieldType.date),
      FieldSpec('meeting_at', 'Meeting date', type: FieldType.date),
      FieldSpec('close_date', 'Close date', type: FieldType.date),
      FieldSpec('expected_delivery', 'Expected delivery',
          type: FieldType.date),
      FieldSpec('is_hot', 'Hot lead', type: FieldType.boolean),
      FieldSpec('remarks', 'Remarks', type: FieldType.multiline),
    ];

/// Sales & CRM: a Twenty-style pipeline board plus contacts, leads & clients.
class CrmModule extends StatelessWidget {
  CrmModule({super.key});
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
              Tab(text: 'Pipeline'),
              Tab(text: 'Contacts'),
              Tab(text: 'Leads'),
              Tab(text: 'Clients'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _PipelineBoard(repo: _repo),
                _Contacts(repo: _repo),
                _Leads(repo: _repo),
                _Clients(repo: _repo),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineBoard extends StatefulWidget {
  final ErpRepository repo;
  const _PipelineBoard({required this.repo});
  @override
  State<_PipelineBoard> createState() => _PipelineBoardState();
}

class _PipelineBoardState extends State<_PipelineBoard> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.opportunities();
  }

  void _reload() => setState(() => _future = widget.repo.opportunities());

  Future<void> _move(Map<String, dynamic> opp, String stage) async {
    try {
      await widget.repo.updateOpportunityStage(opp['id'].toString(), stage);
      _reload();
    } catch (e) {
      if (mounted) toast(context, 'Move failed: $e');
    }
  }

  Future<void> _add() async {
    final res = await showRecordForm(context,
        title: 'Add Opportunity', fields: _oppFields());
    if (res == null) return;
    res['currency'] ??= 'INR';
    try {
      await widget.repo.create('crm_opportunities', res);
      _reload();
    } catch (e) {
      if (mounted) toast(context, 'Add failed: $e');
    }
  }

  Future<void> _edit(Map<String, dynamic> opp) async {
    final res = await showRecordForm(context,
        title: 'Edit Opportunity', fields: _oppFields(), initial: opp);
    if (res == null) return;
    try {
      await widget.repo
          .updateRow('crm_opportunities', 'id', opp['id'], res);
      _reload();
    } catch (e) {
      if (mounted) toast(context, 'Update failed: $e');
    }
  }

  Future<void> _delete(Map<String, dynamic> opp) async {
    if (!await confirmDelete(context, str(opp['name'], 'this deal'))) return;
    try {
      await widget.repo.deleteRow('crm_opportunities', 'id', opp['id']);
      _reload();
    } catch (e) {
      if (mounted) toast(context, 'Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text('Failed: ${snap.error}'));
        final opps = snap.data ?? [];
        final byStage = {
          for (final s in _stages) s.value: <Map<String, dynamic>>[]
        };
        for (final o in opps) {
          final s = (o['stage']?.toString() ?? 'NEW').toUpperCase();
          (byStage[s] ?? byStage['NEW']!).add(o);
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: AddBar(label: 'Add Opportunity', onTap: _add),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final stage in _stages)
                      _StageColumn(
                        stage: stage,
                        items: byStage[stage.value]!,
                        onMove: _move,
                        onEdit: _edit,
                        onDelete: _delete,
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
}

class _StageColumn extends StatelessWidget {
  final _Stage stage;
  final List<Map<String, dynamic>> items;
  final Future<void> Function(Map<String, dynamic>, String) onMove;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;
  const _StageColumn({
    required this.stage,
    required this.items,
    required this.onMove,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = stage.color;
    final total = items.fold<num>(
        0, (s, o) => s + (num.tryParse('${o['amount'] ?? 0}') ?? 0));
    return Container(
      width: 264,
      margin: const EdgeInsets.only(right: 12, bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(stage.label,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                          fontSize: 13)),
                ),
                const SizedBox(width: 6),
                StatusChip('${items.length}', color: color),
              ],
            ),
          ),
          if (total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(fmtInr(total),
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color)),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 480),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              children: items
                  .map((o) => _OppCard(
                        opp: o,
                        stage: stage,
                        onMove: onMove,
                        onEdit: () => onEdit(o),
                        onDelete: () => onDelete(o),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _OppCard extends StatelessWidget {
  final Map<String, dynamic> opp;
  final _Stage stage;
  final Future<void> Function(Map<String, dynamic>, String) onMove;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _OppCard({
    required this.opp,
    required this.stage,
    required this.onMove,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (opp['is_hot'] == true)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.local_fire_department,
                          size: 15, color: kDanger),
                    ),
                  Expanded(
                    child: Text(str(opp['name']),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    padding: EdgeInsets.zero,
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                      if (v.startsWith('move:')) onMove(opp, v.substring(5));
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete')),
                      const PopupMenuDivider(),
                      ..._stages.where((s) => s.value != stage.value).map((s) =>
                          PopupMenuItem(
                              value: 'move:${s.value}',
                              child: Text('Move to ${s.label}'))),
                    ],
                  ),
                ],
              ),
              if ((opp['company_name']?.toString().trim() ?? '').isNotEmpty)
                Text(str(opp['company_name']),
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color)),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (opp['amount'] != null)
                    Text(fmtInr(opp['amount']),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12.5)),
                  const Spacer(),
                  if ((opp['contacted_by']?.toString().trim() ?? '').isNotEmpty)
                    Text(str(opp['contacted_by']),
                        style: const TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Generic CRUD-enabled list used by Contacts / Leads / Clients tabs.
class _CrudList extends StatelessWidget {
  final ErpRepository repo;
  final String table;
  final String idCol;
  final String addLabel;
  final String editLabel;
  final Future<List<Map<String, dynamic>>> Function() loader;
  final List<FieldSpec> Function() fields;
  final Widget Function(Map<String, dynamic> row, VoidCallback onEdit,
      VoidCallback onDelete) tile;
  final String emptyMessage;
  const _CrudList({
    required this.repo,
    required this.table,
    required this.idCol,
    required this.addLabel,
    required this.editLabel,
    required this.loader,
    required this.fields,
    required this.tile,
    this.emptyMessage = 'No records found.',
  });

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<Map<String, dynamic>>>(
      loader: loader,
      isEmpty: (d) => false,
      emptyMessage: emptyMessage,
      builder: (context, list, refresh) {
        Future<void> add() async {
          final res = await showRecordForm(context,
              title: addLabel, fields: fields());
          if (res == null) return;
          try {
            await repo.create(table, res);
            await refresh();
          } catch (e) {
            if (context.mounted) toast(context, 'Add failed: $e');
          }
        }

        Future<void> edit(Map<String, dynamic> row) async {
          final res = await showRecordForm(context,
              title: editLabel, fields: fields(), initial: row);
          if (res == null) return;
          try {
            await repo.updateRow(table, idCol, row[idCol], res);
            await refresh();
          } catch (e) {
            if (context.mounted) toast(context, 'Update failed: $e');
          }
        }

        Future<void> del(Map<String, dynamic> row, String what) async {
          if (!await confirmDelete(context, what)) return;
          try {
            await repo.deleteRow(table, idCol, row[idCol]);
            await refresh();
          } catch (e) {
            if (context.mounted) toast(context, 'Delete failed: $e');
          }
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            AddBar(label: addLabel, onTap: add),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: Text(emptyMessage)),
              ),
            ...list.map((row) => tile(
                  row,
                  () => edit(row),
                  () => del(row, 'this record'),
                )),
          ],
        );
      },
    );
  }
}

class _Contacts extends StatelessWidget {
  final ErpRepository repo;
  const _Contacts({required this.repo});
  @override
  Widget build(BuildContext context) {
    return _CrudList(
      repo: repo,
      table: 'crm_contacts',
      idCol: 'id',
      addLabel: 'Add Contact',
      editLabel: 'Edit Contact',
      loader: repo.contacts,
      emptyMessage: 'No contacts yet.',
      fields: () => const [
        FieldSpec('first_name', 'First name'),
        FieldSpec('last_name', 'Last name'),
        FieldSpec('email', 'Email'),
        FieldSpec('phone', 'Phone'),
        FieldSpec('job_title', 'Job title'),
        FieldSpec('city', 'City'),
      ],
      tile: (c, onEdit, onDelete) {
        final name =
            '${str(c['first_name'], '')} ${str(c['last_name'], '')}'.trim();
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            onTap: onEdit,
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(name.isEmpty ? 'Unnamed contact' : name),
            subtitle: Text([
              if ((c['job_title']?.toString().trim() ?? '').isNotEmpty)
                c['job_title'],
              if ((c['email']?.toString().trim() ?? '').isNotEmpty) c['email'],
              if ((c['phone']?.toString().trim() ?? '').isNotEmpty) c['phone'],
            ].join(' • ')),
            trailing: RowMenu(onEdit: onEdit, onDelete: onDelete),
          ),
        );
      },
    );
  }
}

class _Leads extends StatelessWidget {
  final ErpRepository repo;
  const _Leads({required this.repo});
  @override
  Widget build(BuildContext context) {
    return _CrudList(
      repo: repo,
      table: 'leads',
      idCol: 'id',
      addLabel: 'Add Lead',
      editLabel: 'Edit Lead',
      loader: repo.leads,
      emptyMessage: 'No leads yet.',
      fields: () => const [
        FieldSpec('client_name', 'Client name', required: true),
        FieldSpec('location', 'Location'),
        FieldSpec('assigned_to', 'Assigned to'),
        FieldSpec('requirement', 'Requirement', type: FieldType.multiline),
        FieldSpec('quote_given', 'Quote given'),
        FieldSpec('status', 'Status'),
        FieldSpec('source', 'Source',
            type: FieldType.dropdown, options: _leadTypes),
        FieldSpec('buyer_type', 'Buyer type'),
        FieldSpec('phone', 'Phone'),
        FieldSpec('email', 'Email'),
        FieldSpec('last_follow_up', 'Last follow-up', type: FieldType.date),
        FieldSpec('next_follow_up', 'Next follow-up', type: FieldType.date),
      ],
      tile: (l, onEdit, onDelete) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          onTap: onEdit,
          title: Text(str(l['client_name'])),
          subtitle: Text([
            if ((l['requirement']?.toString().trim() ?? '').isNotEmpty)
              l['requirement'],
            if ((l['assigned_to']?.toString().trim() ?? '').isNotEmpty)
              'Owner: ${l['assigned_to']}',
            if ((l['location']?.toString().trim() ?? '').isNotEmpty)
              l['location'],
          ].join(' • ')),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            StatusChip(str(l['status'], 'new'),
                color: statusColor(l['status']?.toString())),
            RowMenu(onEdit: onEdit, onDelete: onDelete),
          ]),
        ),
      ),
    );
  }
}

class _Clients extends StatelessWidget {
  final ErpRepository repo;
  const _Clients({required this.repo});
  @override
  Widget build(BuildContext context) {
    return _CrudList(
      repo: repo,
      table: 'clients',
      idCol: 'id',
      addLabel: 'Add Client',
      editLabel: 'Edit Client',
      loader: repo.clients,
      emptyMessage: 'No clients yet.',
      fields: () => const [
        FieldSpec('name', 'Company name', required: true),
        FieldSpec('contact_person', 'Contact person'),
        FieldSpec('phone', 'Phone'),
        FieldSpec('email', 'Email'),
        FieldSpec('city', 'City'),
        FieldSpec('location', 'Location'),
        FieldSpec('notes', 'Notes', type: FieldType.multiline),
      ],
      tile: (c, onEdit, onDelete) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          onTap: onEdit,
          leading: const CircleAvatar(child: Icon(Icons.business)),
          title: Text(str(c['name'])),
          subtitle: Text([
            if ((c['contact_person']?.toString().trim() ?? '').isNotEmpty)
              c['contact_person'],
            if ((c['city']?.toString().trim() ?? '').isNotEmpty) c['city'],
            if ((c['phone']?.toString().trim() ?? '').isNotEmpty) c['phone'],
          ].join(' • ')),
          trailing: RowMenu(onEdit: onEdit, onDelete: onDelete),
        ),
      ),
    );
  }
}
