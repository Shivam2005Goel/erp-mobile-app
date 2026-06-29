import 'package:flutter/material.dart';

import '../../data/erp_repository.dart';
import '../../widgets/crud_list.dart';
import '../../widgets/erp_ui.dart';
import '../../widgets/record_form.dart';
import 'crm_deal_detail.dart';

// ── Pipeline stages (matches web app crmEntities.PIPELINE_STAGES exactly) ────
class _Stage {
  final String value;
  final String label;
  final Color color;
  const _Stage(this.value, this.label, this.color);
}

const _stages = <_Stage>[
  _Stage('NEW',            'New',             Color(0xFF6B7280)),
  _Stage('CALL_1_DONE',   'Call 1 Done',     Color(0xFF4C8DFF)),
  _Stage('CALL_2_DONE',   'Call 2 Done',     Color(0xFF60A5FA)),
  _Stage('CALL_3_DONE',   'Call 3 Done',     Color(0xFF93C5FD)),
  _Stage('MEETING',       'Meeting',         Color(0xFFA855F7)),
  _Stage('PROPOSAL',      'Proposal',        Color(0xFF2DD4BF)),
  _Stage('DEAL_DONE',     'Deal Done',       Color(0xFF22C55E)),
  _Stage('LOW_BUDGET',    'Low Budget',      Color(0xFFF97316)),
  _Stage('GHOSTED',       'Ghosted',         Color(0xFF94A3B8)),
  _Stage('NOT_INTERESTED','Not Interested',  Color(0xFFDC2626)),
  _Stage('FUTURE_LEAD',   'Future Lead',     Color(0xFF9B8BFF)),
];

const _stageValues = [
  'NEW', 'CALL_1_DONE', 'CALL_2_DONE', 'CALL_3_DONE',
  'MEETING', 'PROPOSAL', 'DEAL_DONE',
  'LOW_BUDGET', 'GHOSTED', 'NOT_INTERESTED', 'FUTURE_LEAD',
];

// ── Options ───────────────────────────────────────────────────────────────────
const _contactedBy     = ['Angad', 'Sneha', 'Akshay'];
const _contactModes    = ['WhatsApp Text', 'Call', 'Email', 'In Person'];
const _leadTypes       = ['Website', 'Instagram', 'Google', 'Reference', 'CasinoCart', 'Old Client', 'Walk In'];
const _clientCategories= ['Architect', 'Builder', 'Personal Home'];
const _currencies      = ['INR', 'USD', 'EUR', 'GBP', 'AED'];
const _productCategories = [
  'Pool Tables', 'TT Tables', 'Air Hockey Tables', 'Accessories',
  'Carrom Tables', 'Bar Cabinets', 'Home Bars', 'Snooker Tables',
  'Foosball Tables', 'Chess Tables', 'Bar Counters', 'DJ Tables', 'Bar Stools',
];
const _finishOptions = [
  'Veneer', 'Suede', 'PU Paint', 'Leather', 'Laminate', 'Profile', 'Felt/Cloth', 'Pocket', 'Slate',
];

// ── Opportunity form fields ───────────────────────────────────────────────────
List<FieldSpec> _oppFields() => const [
  // ── Identity ──────────────────────────────────────────────────────────
  FieldSpec('name',           'Opportunity / Client',  required: true),
  FieldSpec('company_name',   'Company Name'),
  FieldSpec('stage',          'Pipeline Stage',        type: FieldType.dropdown, options: _stageValues, required: true),
  FieldSpec('client_type',    'Client Category',       type: FieldType.dropdown, options: _clientCategories),
  // ── Product ───────────────────────────────────────────────────────────
  FieldSpec('product_type',   'Product Category',      type: FieldType.dropdown, options: _productCategories),
  FieldSpec('product_name',   'Product Name'),
  FieldSpec('products',       'Products (multi)'),
  FieldSpec('finishes',       'Finishes',              type: FieldType.dropdown, options: _finishOptions),
  // ── Finance ───────────────────────────────────────────────────────────
  FieldSpec('amount',         'Budget Amount',         type: FieldType.number),
  FieldSpec('offered_price',  'Offered Price',         type: FieldType.number),
  FieldSpec('currency',       'Currency',              type: FieldType.dropdown, options: _currencies),
  // ── Source & Contact ─────────────────────────────────────────────────
  FieldSpec('lead_type',      'Lead Source',           type: FieldType.dropdown, options: _leadTypes),
  FieldSpec('contacted_by',   'Contacted By',          type: FieldType.dropdown, options: _contactedBy),
  FieldSpec('contact_mode',   'Contact Mode',          type: FieldType.dropdown, options: _contactModes),
  FieldSpec('contact_number', 'Contact Number'),
  FieldSpec('email',          'Email'),
  // ── Geography ─────────────────────────────────────────────────────────
  FieldSpec('location',       'Location'),
  FieldSpec('country',        'Country'),
  // ── Dates ─────────────────────────────────────────────────────────────
  FieldSpec('lead_date',         'Lead Date',          type: FieldType.date),
  FieldSpec('meeting_at',        'Meeting Date',       type: FieldType.date),
  FieldSpec('expected_delivery', 'Expected Delivery',  type: FieldType.date),
  FieldSpec('close_date',        'Close Date',         type: FieldType.date),
  // ── Flags & extras ────────────────────────────────────────────────────
  FieldSpec('is_hot',         'Hot Lead',              type: FieldType.boolean),
  FieldSpec('spec_sheet_url', 'Spec Sheet URL'),
  FieldSpec('remarks',        'Remarks',               type: FieldType.multiline),
];

// ── Module root ───────────────────────────────────────────────────────────────
class CrmModule extends StatelessWidget {
  CrmModule({super.key});
  final _repo = ErpRepository();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Pipeline'),
              Tab(text: 'Overview'),
              Tab(text: 'Contacts'),
              Tab(text: 'Leads'),
              Tab(text: 'Clients'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _PipelineBoard(repo: _repo),
                _CrmOverview(repo: _repo),
                _contactsTab(),
                _leadsTab(),
                _clientsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab: Contacts ────────────────────────────────────────────────────────
  Widget _contactsTab() => CrudList(
        repo: _repo,
        table: 'crm_contacts',
        idCol: 'id',
        addLabel: 'Add Contact',
        editLabel: 'Edit Contact',
        loader: _repo.contacts,
        emptyMessage: 'No contacts yet.',
        searchFields: const ['first_name', 'last_name', 'email', 'phone', 'city', 'job_title'],
        searchHint: 'Search contacts…',
        fields: () => const [
          FieldSpec('first_name', 'First name'),
          FieldSpec('last_name',  'Last name'),
          FieldSpec('email',      'Email'),
          FieldSpec('phone',      'Phone'),
          FieldSpec('job_title',  'Job title'),
          FieldSpec('city',       'City'),
        ],
        tile: (c, onEdit, onDelete) {
          final name = '${str(c['first_name'], '')} ${str(c['last_name'], '')}'.trim();
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              onTap: onEdit,
              leading: CircleAvatar(
                backgroundColor: kInfo.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: kInfo, fontWeight: FontWeight.w700),
                ),
              ),
              title: Text(name.isEmpty ? 'Unnamed contact' : name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text([
                if ((c['job_title']?.toString().trim() ?? '').isNotEmpty) c['job_title'],
                if ((c['email']?.toString().trim() ?? '').isNotEmpty) c['email'],
                if ((c['phone']?.toString().trim() ?? '').isNotEmpty) c['phone'],
              ].join(' • ')),
              trailing: RowMenu(onEdit: onEdit, onDelete: onDelete),
            ),
          );
        },
      );

  // ── Tab: Leads ───────────────────────────────────────────────────────────
  Widget _leadsTab() => CrudList(
        repo: _repo,
        table: 'leads',
        idCol: 'id',
        addLabel: 'Add Lead',
        editLabel: 'Edit Lead',
        loader: _repo.leads,
        emptyMessage: 'No leads yet.',
        searchFields: const ['client_name', 'location', 'assigned_to', 'requirement', 'phone', 'email'],
        searchHint: 'Search leads…',
        fields: () => const [
          FieldSpec('client_name',   'Client name',   required: true),
          FieldSpec('location',      'Location'),
          FieldSpec('assigned_to',   'Assigned to',   type: FieldType.dropdown, options: _contactedBy),
          FieldSpec('requirement',   'Requirement',   type: FieldType.multiline),
          FieldSpec('quote_given',   'Quote given'),
          FieldSpec('status',        'Status'),
          FieldSpec('source',        'Source',        type: FieldType.dropdown, options: _leadTypes),
          FieldSpec('buyer_type',    'Buyer type',    type: FieldType.dropdown, options: _clientCategories),
          FieldSpec('phone',         'Phone'),
          FieldSpec('email',         'Email'),
          FieldSpec('last_follow_up','Last follow-up',type: FieldType.date),
          FieldSpec('next_follow_up','Next follow-up',type: FieldType.date),
        ],
        tile: (l, onEdit, onDelete) => Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            onTap: onEdit,
            title: Text(str(l['client_name']),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text([
              if ((l['requirement']?.toString().trim() ?? '').isNotEmpty) l['requirement'],
              if ((l['assigned_to']?.toString().trim() ?? '').isNotEmpty) 'Owner: ${l['assigned_to']}',
              if ((l['location']?.toString().trim() ?? '').isNotEmpty) l['location'],
            ].join(' • ')),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              StatusChip(str(l['status'], 'new'), color: statusColor(l['status']?.toString())),
              RowMenu(onEdit: onEdit, onDelete: onDelete),
            ]),
          ),
        ),
      );

  // ── Tab: Clients ─────────────────────────────────────────────────────────
  Widget _clientsTab() => CrudList(
        repo: _repo,
        table: 'clients',
        idCol: 'id',
        addLabel: 'Add Client',
        editLabel: 'Edit Client',
        loader: _repo.clients,
        emptyMessage: 'No clients yet.',
        searchFields: const ['name', 'contact_person', 'phone', 'email', 'city'],
        searchHint: 'Search clients…',
        fields: () => const [
          FieldSpec('name',           'Company name',   required: true),
          FieldSpec('contact_person', 'Contact person'),
          FieldSpec('phone',          'Phone'),
          FieldSpec('email',          'Email'),
          FieldSpec('city',           'City'),
          FieldSpec('location',       'Location'),
          FieldSpec('notes',          'Notes',          type: FieldType.multiline),
        ],
        tile: (c, onEdit, onDelete) => Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            onTap: onEdit,
            leading: CircleAvatar(
              backgroundColor: kSuccess.withValues(alpha: 0.15),
              child: const Icon(Icons.business, color: kSuccess, size: 20),
            ),
            title: Text(str(c['name']),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text([
              if ((c['contact_person']?.toString().trim() ?? '').isNotEmpty) c['contact_person'],
              if ((c['city']?.toString().trim() ?? '').isNotEmpty) c['city'],
              if ((c['phone']?.toString().trim() ?? '').isNotEmpty) c['phone'],
            ].join(' • ')),
            trailing: RowMenu(onEdit: onEdit, onDelete: onDelete),
          ),
        ),
      );
}

// ── Pipeline Board ─────────────────────────────────────────────────────────────
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

  void _reload() { if (mounted) setState(() { _future = widget.repo.opportunities(); }); }

  Future<void> _move(Map<String, dynamic> opp, String stage) async {
    try {
      await widget.repo.updateOpportunityStage(opp['id'].toString(), stage);
      _reload();
    } catch (e) {
      if (mounted) toast(context, 'Move failed: $e');
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

  Future<void> _add() async {
    final res = await showRecordForm(context, title: 'Add Opportunity', fields: _oppFields());
    if (res == null || !mounted) return;
    res['currency'] ??= 'INR';
    res['stage'] ??= 'NEW';
    try {
      await widget.repo.create('crm_opportunities', res);
      _reload();
    } catch (e) {
      _showError('Failed to add opportunity.\n\n$e');
    }
  }

  Future<void> _edit(Map<String, dynamic> opp) async {
    final res = await showRecordForm(context,
        title: 'Edit Opportunity', fields: _oppFields(), initial: opp);
    if (res == null || !mounted) return;
    try {
      await widget.repo.updateRow('crm_opportunities', 'id', opp['id'], res);
      _reload();
    } catch (e) {
      _showError('Failed to update opportunity.\n\n$e');
    }
  }

  Future<void> _delete(Map<String, dynamic> opp) async {
    if (!await confirmDelete(context, str(opp['name'], 'this deal'))) return;
    if (!mounted) return;
    try {
      await widget.repo.deleteRow('crm_opportunities', 'id', opp['id']);
      _reload();
    } catch (e) {
      _showError('Failed to delete opportunity.\n\n$e');
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
        final byStage = {for (final s in _stages) s.value: <Map<String, dynamic>>[]};
        for (final o in opps) {
          final s = (o['stage']?.toString() ?? 'NEW').toUpperCase();
          (byStage[s] ?? byStage['NEW']!).add(o);
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
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

// ── Stage column with DragTarget ─────────────────────────────────────────────
class _StageColumn extends StatelessWidget {
  final _Stage stage;
  final List<Map<String, dynamic>> items;
  final Future<void> Function(Map<String, dynamic>, String) onMove;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;
  const _StageColumn({
    required this.stage, required this.items,
    required this.onMove, required this.onEdit, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = stage.color;
    final total = items.fold<num>(0, (s, o) => s + (num.tryParse('${o['amount'] ?? 0}') ?? 0));
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (d) =>
          (d.data['stage']?.toString().toUpperCase() ?? 'NEW') != stage.value,
      onAcceptWithDetails: (d) => onMove(d.data, stage.value),
      builder: (ctx, candidate, _) {
        final isTarget = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 260,
          margin: const EdgeInsets.only(right: 12, bottom: 12),
          decoration: BoxDecoration(
            color: isTarget
                ? color.withValues(alpha: 0.06)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isTarget ? color : color.withValues(alpha: 0.4),
              width: isTarget ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isTarget ? 0.2 : 0.12),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Row(children: [
                  Expanded(child: Text(stage.label,
                      style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13))),
                  StatusChip('${items.length}', color: color),
                ]),
              ),
              if (total > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Text(fmtInr(total),
                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                ),
              if (isTarget)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Text('Drop here →',
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  children: items.map((o) => _OppCard(
                        opp: o, stage: stage,
                        onMove: onMove,
                        onEdit: () => onEdit(o),
                        onDelete: () => onDelete(o),
                      )).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Pipeline card with LongPressDraggable ─────────────────────────────────────
class _OppCard extends StatelessWidget {
  final Map<String, dynamic> opp;
  final _Stage stage;
  final Future<void> Function(Map<String, dynamic>, String) onMove;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _OppCard({
    required this.opp, required this.stage,
    required this.onMove, required this.onEdit, required this.onDelete,
  });

  Widget _cardBody(BuildContext context, {required bool showMenu}) {
    final color = stage.color;
    final product = str(opp['product_name'], str(opp['product_type'], ''));
    final hasProduct = product != '—';
    final contact = str(opp['contact_number'], str(opp['email'], ''));
    final hasContact = contact != '—';
    final hasLocation = (opp['location']?.toString().trim() ?? '').isNotEmpty;
    final hasSource   = (opp['lead_type']?.toString().trim() ?? '').isNotEmpty;
    final hasBy       = (opp['contacted_by']?.toString().trim() ?? '').isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: hot flag + name + menu
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (opp['is_hot'] == true) const Padding(
                  padding: EdgeInsets.only(top: 2, right: 4),
                  child: Icon(Icons.local_fire_department, size: 13, color: kDanger)),
                Expanded(child: Text(str(opp['name']),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    overflow: TextOverflow.ellipsis, maxLines: 2)),
                if (showMenu) PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (v) {
                    if (v == 'edit')   onEdit();
                    if (v == 'delete') onDelete();
                    if (v.startsWith('move:')) onMove(opp, v.substring(5));
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit',   child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined, size: 16), title: Text('Edit'))),
                    const PopupMenuItem(value: 'delete', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_outline, size: 16, color: kDanger), title: Text('Delete', style: TextStyle(color: kDanger)))),
                    const PopupMenuDivider(),
                    ..._stages.where((s) => s.value != stage.value).map((s) =>
                        PopupMenuItem(value: 'move:${s.value}',
                            child: Text('→ ${s.label}', style: const TextStyle(fontSize: 13)))),
                  ],
                ),
              ]),
              // Row 2: company name
              if ((opp['company_name']?.toString().trim() ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(str(opp['company_name']),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis),
                ),
              // Row 3: product chip
              if (hasProduct) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(product,
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
              const SizedBox(height: 6),
              // Row 4: amount + location
              if (opp['amount'] != null || hasLocation)
                Row(children: [
                  if (opp['amount'] != null)
                    Text(fmtInr(opp['amount']),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: kBrand)),
                  if (opp['amount'] != null && hasLocation) const SizedBox(width: 8),
                  if (hasLocation)
                    Expanded(child: Row(children: [
                      const Icon(Icons.location_on_outlined, size: 11, color: Colors.grey),
                      const SizedBox(width: 2),
                      Expanded(child: Text(str(opp['location']),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis)),
                    ])),
                ]),
              // Row 5: source + contacted_by
              if (hasSource || hasBy) ...[
                const SizedBox(height: 4),
                Row(children: [
                  if (hasSource) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kInfo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(str(opp['lead_type']),
                          style: const TextStyle(fontSize: 10, color: kInfo)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (hasBy)
                    Expanded(child: Text('via ${str(opp['contacted_by'])}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        overflow: TextOverflow.ellipsis)),
                ]),
              ],
              // Row 6: contact number
              if (hasContact) ...[
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.phone_outlined, size: 11, color: Colors.grey),
                  const SizedBox(width: 3),
                  Flexible(child: Text(contact,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis)),
                ]),
              ],
              // Row 7: client type + lead date
              if ((opp['client_type']?.toString().trim() ?? '').isNotEmpty ||
                  opp['lead_date'] != null) ...[
                const SizedBox(height: 3),
                Row(children: [
                  if ((opp['client_type']?.toString().trim() ?? '').isNotEmpty)
                    Expanded(child: Text(str(opp['client_type']),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        overflow: TextOverflow.ellipsis)),
                  if (opp['lead_date'] != null)
                    Text(fmtDate(opp['lead_date']),
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<Map<String, dynamic>>(
      data: opp,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 240, child: _cardBody(context, showMenu: false)),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _cardBody(context, showMenu: false)),
      child: _cardBody(context, showMenu: true),
    );
  }
}

// ── Opportunity detail bottom sheet ──────────────────────────────────────────
void _showOppDetail(BuildContext context, Map<String, dynamic> opp) {
  final stageObj = _stages.firstWhere(
    (s) => s.value == (opp['stage']?.toString().toUpperCase() ?? ''),
    orElse: () => const _Stage('', 'Unknown', Color(0xFF94A3B8)),
  );
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 1.0,
      expand: false,
      builder: (_, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
          // Title row
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (opp['is_hot'] == true) const Padding(
              padding: EdgeInsets.only(right: 6, top: 3),
              child: Icon(Icons.local_fire_department, color: kDanger, size: 20)),
            Expanded(child: Text(str(opp['name']),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ]),
          if ((opp['company_name']?.toString().trim() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(str(opp['company_name']),
                  style: const TextStyle(fontSize: 13.5, color: Colors.grey)),
            ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            StatusChip(stageObj.label, color: stageObj.color),
            if (opp['is_hot'] == true)
              const StatusChip('HOT', color: kDanger),
            if ((opp['client_type']?.toString().trim() ?? '').isNotEmpty)
              StatusChip(str(opp['client_type']), color: kInfo),
          ]),
          const SizedBox(height: 16),
          const Divider(),
          // Product & Finance
          if ((opp['product_name']?.toString().trim() ?? '').isNotEmpty)
            InfoRow('Product', str(opp['product_name'])),
          if ((opp['product_type']?.toString().trim() ?? '').isNotEmpty)
            InfoRow('Category', str(opp['product_type'])),
          if (opp['amount'] != null)
            InfoRow('Budget', '${fmtInr(opp['amount'])} ${str(opp['currency'], '')}'),
          if (opp['offered_price'] != null)
            InfoRow('Offered Price', fmtInr(opp['offered_price'])),
          // Source & Contact
          const Divider(height: 24),
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
          // Remarks
          if ((opp['remarks']?.toString().trim() ?? '').isNotEmpty) ...[
            const Divider(height: 24),
            const Text('Remarks',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            Text(opp['remarks'].toString(),
                style: const TextStyle(fontSize: 13.5)),
          ],
          if ((opp['spec_sheet_url']?.toString().trim() ?? '').isNotEmpty) ...[
            const Divider(height: 24),
            InfoRow('Spec Sheet', str(opp['spec_sheet_url'])),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.notes, size: 16),
              label: const Text('Notes / Tasks / Activity'),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CrmDealDetail(opp: opp),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

// ── CRM Overview ──────────────────────────────────────────────────────────────
class _CrmOverview extends StatefulWidget {
  final ErpRepository repo;
  const _CrmOverview({required this.repo});
  @override
  State<_CrmOverview> createState() => _CrmOverviewState();
}

class _CrmOverviewState extends State<_CrmOverview> {
  bool _showClients = false;
  String _query = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<Map<String, dynamic>>>(
      loader: widget.repo.opportunities,
      isEmpty: (d) => false,
      emptyMessage: 'No CRM data.',
      builder: (context, opps, _) {
        final leads   = opps.where((o) => (o['stage']?.toString() ?? '') != 'DEAL_DONE').toList();
        final clients = opps.where((o) => (o['stage']?.toString() ?? '') == 'DEAL_DONE').toList();
        final hotLeads  = leads.where((o) => o['is_hot'] == true).length;
        final dealValue = clients.fold<num>(0, (s, o) => s + (num.tryParse('${o['amount'] ?? 0}') ?? 0));

        final active = _showClients ? clients : leads;
        final q = _query.trim().toLowerCase();
        final filtered = q.isEmpty ? active : active.where((o) {
          for (final k in ['name', 'client_type', 'location', 'product_name',
              'contact_number', 'email', 'company_name', 'lead_type', 'contacted_by']) {
            if ((o[k]?.toString().toLowerCase() ?? '').contains(q)) return true;
          }
          return false;
        }).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            // ── KPI row ────────────────────────────────────────────────
            MetricRow(children: [
              MetricCard(label: 'Active Leads',  value: '${leads.length}',  icon: Icons.people_outline),
              MetricCard(label: 'Clients',       value: '${clients.length}', icon: Icons.business,             color: kSuccess),
              MetricCard(label: 'Hot Leads',     value: '$hotLeads',         icon: Icons.local_fire_department, color: kDanger),
              MetricCard(label: 'Deal Value',    value: fmtInr(dealValue),   icon: Icons.currency_rupee,        color: kBrand),
            ]),
            const SizedBox(height: 18),

            // ── Toggle ─────────────────────────────────────────────────
            Row(children: [
              _ToggleBtn(label: 'Leads ${leads.length}',   active: !_showClients,
                  onTap: () => setState(() { _showClients = false; _query = ''; _ctrl.clear(); }),
                  leftRounded: true),
              _ToggleBtn(label: 'Clients ${clients.length}', active: _showClients,
                  onTap: () => setState(() { _showClients = true;  _query = ''; _ctrl.clear(); }),
                  leftRounded: false),
              const Spacer(),
              Text('${filtered.length} shown',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
            ]),
            const SizedBox(height: 12),

            // ── Search ─────────────────────────────────────────────────
            TextField(
              controller: _ctrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search name, location, product, contact…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() { _query = ''; _ctrl.clear(); }))
                    : null,
              ),
            ),
            const SizedBox(height: 14),

            // ── Cards ─────────────────────────────────────────────────
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: Text('No records found.')),
              )
            else
              ...filtered.map((o) => _OppOverviewCard(opp: o, isClient: _showClients)),
          ],
        );
      },
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool leftRounded;
  const _ToggleBtn({required this.label, required this.active, required this.onTap, required this.leftRounded});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kBrand : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left:  Radius.circular(leftRounded ? 8 : 0),
            right: Radius.circular(leftRounded ? 0 : 8),
          ),
          border: Border.all(color: kBrand),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : kBrand,
                fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }
}

// ── Overview card (tap to see full detail) ────────────────────────────────────
class _OppOverviewCard extends StatelessWidget {
  final Map<String, dynamic> opp;
  final bool isClient;
  const _OppOverviewCard({required this.opp, required this.isClient});

  @override
  Widget build(BuildContext context) {
    final stageObj = _stages.firstWhere(
      (s) => s.value == (opp['stage']?.toString().toUpperCase() ?? ''),
      orElse: () => const _Stage('', 'Unknown', Color(0xFF94A3B8)),
    );
    final product = str(opp['product_name'], str(opp['product_type'], ''));
    final hasProduct = product != '—';
    final contact = str(opp['contact_number'], str(opp['email'], ''));
    final hasContact = contact != '—';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showOppDetail(context, opp),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: name + hot + stage chip
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (opp['is_hot'] == true) const Padding(
                  padding: EdgeInsets.only(right: 5, top: 2),
                  child: Icon(Icons.local_fire_department, size: 14, color: kDanger)),
                Expanded(child: Text(str(opp['name']),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                StatusChip(stageObj.label, color: stageObj.color),
              ]),
              // company name
              if ((opp['company_name']?.toString().trim() ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(str(opp['company_name']),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis),
                ),
              const SizedBox(height: 8),
              // product
              if (hasProduct)
                Row(children: [
                  const Icon(Icons.inventory_2_outlined, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(child: Text(product,
                      style: const TextStyle(fontSize: 12.5),
                      overflow: TextOverflow.ellipsis)),
                ]),
              const SizedBox(height: 6),
              // amount + location
              Row(children: [
                if (opp['amount'] != null) ...[
                  const Icon(Icons.currency_rupee, size: 13, color: kBrand),
                  Text(fmtInr(opp['amount']),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: kBrand)),
                  const SizedBox(width: 10),
                ],
                if ((opp['location']?.toString().trim() ?? '').isNotEmpty)
                  Expanded(child: Row(children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                    const SizedBox(width: 3),
                    Expanded(child: Text(str(opp['location']),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis)),
                  ])),
              ]),
              // contact + source
              if (hasContact || (opp['lead_type']?.toString().trim() ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  if (hasContact) ...[
                    const Icon(Icons.phone_outlined, size: 12, color: Colors.grey),
                    const SizedBox(width: 3),
                    Text(contact, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 10),
                  ],
                  if ((opp['lead_type']?.toString().trim() ?? '').isNotEmpty)
                    StatusChip(str(opp['lead_type']), color: kInfo),
                  if ((opp['contacted_by']?.toString().trim() ?? '').isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text('via ${str(opp['contacted_by'])}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ]),
              ],
              // for clients: show amount prominently if not shown above
              if (isClient && opp['amount'] == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Deal closed', style: TextStyle(fontSize: 12, color: kSuccess)),
                ),
              // tap hint
              const SizedBox(height: 6),
              Row(children: [
                const Spacer(),
                Text('Tap for details →',
                    style: TextStyle(fontSize: 11, color: kBrand.withValues(alpha: 0.7))),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
