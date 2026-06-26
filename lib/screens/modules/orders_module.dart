import 'package:flutter/material.dart';

import '../../data/erp_repository.dart';
import '../../widgets/crud_list.dart';
import '../../widgets/erp_ui.dart';
import '../../widgets/record_form.dart';

// ── Options ───────────────────────────────────────────────────────────────────
const _leadTypes = [
  'Website', 'Instagram', 'Google', 'Reference', 'CasinoCart', 'Old Client', 'Walk In',
];
const _clientCategories = ['Architect', 'Builder', 'Personal Home'];
const _currencies = ['INR', 'USD', 'EUR', 'GBP', 'AED'];
const _orderStatuses = ['Initial Stage', 'In progress', 'Completed'];
const _productionStages = [
  'New / Initial', 'Carpentry', 'Paint Shop', 'Packaging', 'Dispatch', 'Installed / Delivered',
];
const _finishOptions = [
  'Veneer', 'Suede', 'PU Paint', 'Leather', 'Laminate', 'Profile', 'Felt/Cloth', 'Pocket', 'Slate',
];

List<FieldSpec> _orderFields() => const [
  // ── Client / Contact ──────────────────────────────────────────────────
  FieldSpec('client_name',       'Client Name',       required: true),
  FieldSpec('company_name',      'Company Name'),
  FieldSpec('location',          'Location'),
  FieldSpec('country',           'Country'),
  FieldSpec('contact_number',    'Contact Number'),
  FieldSpec('email',             'Email'),
  // ── Product ───────────────────────────────────────────────────────────
  FieldSpec('products',          'Products'),
  FieldSpec('product_name',      'Product Name'),
  FieldSpec('table_type',        'Table Type'),
  FieldSpec('quantity',          'Quantity',           type: FieldType.number),
  // ── Stage & Status ────────────────────────────────────────────────────
  FieldSpec('status',            'Status',             type: FieldType.dropdown, options: _orderStatuses),
  FieldSpec('current_stage',     'Production Stage',   type: FieldType.dropdown, options: _productionStages),
  FieldSpec('is_delivered',      'Delivered',          type: FieldType.boolean),
  FieldSpec('self_installed',    'Self Installed',     type: FieldType.boolean),
  // ── Dates ─────────────────────────────────────────────────────────────
  FieldSpec('order_date',        'Order Date',         type: FieldType.date),
  FieldSpec('lead_date',         'Lead Date',          type: FieldType.date),
  FieldSpec('expected_completion','Expected Completion',type: FieldType.date),
  FieldSpec('delivery_date',     'Delivery Date',      type: FieldType.date),
  // ── Source & Finance ──────────────────────────────────────────────────
  FieldSpec('order_source',      'Order Source',       type: FieldType.dropdown, options: _leadTypes),
  FieldSpec('lead_type',         'Lead Type',          type: FieldType.dropdown, options: _leadTypes),
  FieldSpec('client_type',       'Client Category',    type: FieldType.dropdown, options: _clientCategories),
  FieldSpec('order_finalised_by','Finalised By'),
  FieldSpec('amount',            'Order Amount',       type: FieldType.number),
  FieldSpec('currency',          'Currency',           type: FieldType.dropdown, options: _currencies),
  FieldSpec('is_hot',            'Hot Lead',           type: FieldType.boolean),
  // ── Production workers ────────────────────────────────────────────────
  FieldSpec('carpentry_by',      'Carpentry By'),
  FieldSpec('paint_by',          'Paint By'),
  FieldSpec('packaging_by',      'Packaging By'),
  FieldSpec('dispatch_by',       'Dispatch By'),
  FieldSpec('installed_by',      'Installed By'),
  FieldSpec('tracking_link',     'Tracking Link'),
  // ── Production details ────────────────────────────────────────────────
  FieldSpec('finishes',          'Finishes',           type: FieldType.dropdown, options: _finishOptions),
  FieldSpec('days_to_complete',  'Days to Complete',   type: FieldType.number),
  FieldSpec('on_which_day',      'On Which Day'),
  FieldSpec('reason_for_delay',  'Reason for Delay'),
  FieldSpec('spec_sheet_url',    'Spec Sheet URL'),
  // ── Notes ─────────────────────────────────────────────────────────────
  FieldSpec('notes',             'Notes',              type: FieldType.multiline),
  FieldSpec('remarks',           'Remarks',            type: FieldType.multiline),
];

// ── Module root ───────────────────────────────────────────────────────────────
class OrdersModule extends StatelessWidget {
  OrdersModule({super.key});
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
              Tab(text: 'Orders'),
              Tab(text: 'Overview'),
              Tab(text: 'Operations'),
              Tab(text: 'Priority'),
              Tab(text: 'Materials'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ordersTab(),
                _OrdersOverview(repo: _repo),
                _OperationsBoard(repo: _repo),
                _priorityTab(),
                _materialsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab: Orders list ────────────────────────────────────────────────────
  Widget _ordersTab() => CrudList(
        repo: _repo,
        table: 'orders',
        idCol: 'id',
        addLabel: 'Add Order',
        editLabel: 'Edit Order',
        loader: _repo.orders,
        emptyMessage: 'No orders yet.',
        searchFields: const ['client_name', 'product_name', 'location', 'current_stage', 'status'],
        searchHint: 'Search orders…',
        fields: _orderFields,
        header: (context, list, _) {
          final delivered = list.where((o) => o['is_delivered'] == true).length;
          final inProg    = list.where((o) => o['status'] == 'In progress').length;
          final notStart  = list.where((o) => o['status'] == 'Initial Stage').length;
          return MetricRow(children: [
            MetricCard(label: 'Total',       value: '${list.length}', icon: Icons.receipt_long),
            MetricCard(label: 'In Progress', value: '$inProg',        icon: Icons.timelapse,       color: kWarning),
            MetricCard(label: 'Delivered',   value: '$delivered',     icon: Icons.local_shipping,   color: kSuccess),
            MetricCard(label: 'Not Started', value: '$notStart',      icon: Icons.hourglass_empty,  color: kInfo),
          ]);
        },
        tile: (o, onEdit, onDelete) => _OrderTile(order: o, onEdit: onEdit, onDelete: onDelete),
      );

  // ── Tab: Priority orders ────────────────────────────────────────────────
  Widget _priorityTab() => CrudList(
        repo: _repo,
        table: 'priority_orders',
        idCol: 'id',
        addLabel: 'Add Priority Order',
        editLabel: 'Edit Priority Order',
        loader: _repo.priorityOrders,
        emptyMessage: 'No priority orders.',
        searchFields: const ['order_name', 'particulars'],
        searchHint: 'Search priority orders…',
        fields: () => const [
          FieldSpec('order_name',    'Order name',   required: true),
          FieldSpec('particulars',   'Particulars',  type: FieldType.multiline),
          FieldSpec('priority',      'Priority',     type: FieldType.dropdown, options: ['High', 'Medium', 'Low']),
          FieldSpec('order_date',    'Order date',   type: FieldType.date),
          FieldSpec('delivery_date', 'Delivery date',type: FieldType.date),
          FieldSpec('notes',         'Notes',        type: FieldType.multiline),
        ],
        tile: (p, onEdit, onDelete) => Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            onTap: onEdit,
            leading: const Icon(Icons.priority_high, color: kDanger),
            title: Text(str(p['order_name'])),
            subtitle: Text([
              if ((p['particulars']?.toString().trim() ?? '').isNotEmpty) p['particulars'],
              'Deliver by ${fmtDate(p['delivery_date'])}',
            ].join(' • ')),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              StatusChip(str(p['priority'], 'normal'), color: statusColor(p['priority']?.toString())),
              RowMenu(onEdit: onEdit, onDelete: onDelete),
            ]),
          ),
        ),
      );

  // ── Tab: Pending materials ───────────────────────────────────────────────
  Widget _materialsTab() => CrudList(
        repo: _repo,
        table: 'pending_materials',
        idCol: 'id',
        addLabel: 'Add Pending Material',
        editLabel: 'Edit Pending Material',
        loader: _repo.pendingMaterials,
        emptyMessage: 'No pending materials.',
        searchFields: const ['material_pending', 'product_name', 'client_name'],
        searchHint: 'Search materials…',
        fields: () => const [
          FieldSpec('material_pending',    'Material pending',   required: true),
          FieldSpec('product_name',        'Product'),
          FieldSpec('client_name',         'Client'),
          FieldSpec('material_pending_by', 'Pending by'),
          FieldSpec('status',              'Status'),
          FieldSpec('resolved_date',       'Resolved date',      type: FieldType.date),
          FieldSpec('comments',            'Comments',           type: FieldType.multiline),
        ],
        tile: (m, onEdit, onDelete) => Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            onTap: onEdit,
            title: Text(str(m['material_pending'], 'Material')),
            subtitle: Text([
              if ((m['product_name']?.toString().trim() ?? '').isNotEmpty) m['product_name'],
              if ((m['client_name']?.toString().trim() ?? '').isNotEmpty) m['client_name'],
              if ((m['material_pending_by']?.toString().trim() ?? '').isNotEmpty)
                'By ${m['material_pending_by']}',
            ].join(' • ')),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              StatusChip(str(m['status'], 'pending'), color: statusColor(m['status']?.toString())),
              RowMenu(onEdit: onEdit, onDelete: onDelete),
            ]),
          ),
        ),
      );
}

// ── Rich order tile ────────────────────────────────────────────────────────────
class _OrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _OrderTile({required this.order, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final isDelivered = o['is_delivered'] == true;
    final isHot = o['is_hot'] == true;
    final status = str(o['status'], 'open');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(children: [
                if (isHot) const Icon(Icons.local_fire_department, size: 15, color: kDanger),
                if (isHot) const SizedBox(width: 4),
                Expanded(
                  child: Text(str(o['client_name']),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                ),
                StatusChip(
                  isDelivered ? 'Delivered' : status,
                  color: isDelivered ? kSuccess : statusColor(status),
                ),
                RowMenu(onEdit: onEdit, onDelete: onDelete),
              ]),
              // Company / product
              if ((o['company_name']?.toString().trim() ?? '').isNotEmpty)
                Text(str(o['company_name']),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
              const SizedBox(height: 6),
              // Detail tags
              Wrap(spacing: 10, runSpacing: 4, children: [
                if ((o['product_name']?.toString().trim() ?? '').isNotEmpty)
                  _Tag(Icons.sports_esports_outlined, str(o['product_name'])),
                if ((o['location']?.toString().trim() ?? '').isNotEmpty)
                  _Tag(Icons.location_on_outlined, str(o['location'])),
                if ((o['current_stage']?.toString().trim() ?? '').isNotEmpty)
                  _Tag(Icons.build_outlined, str(o['current_stage'])),
                if (o['order_date'] != null)
                  _Tag(Icons.calendar_today_outlined, fmtDate(o['order_date'])),
                if (o['delivery_date'] != null)
                  _Tag(Icons.local_shipping_outlined, fmtDate(o['delivery_date'])),
                if (o['amount'] != null)
                  _Tag(Icons.currency_rupee, fmtInr(o['amount'])),
                if ((o['order_source']?.toString().trim() ?? '').isNotEmpty)
                  _Tag(Icons.link, str(o['order_source'])),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tag(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: Theme.of(context).textTheme.bodySmall?.color),
      const SizedBox(width: 3),
      Text(text,
          style: TextStyle(fontSize: 11.5, color: Theme.of(context).textTheme.bodySmall?.color)),
    ]);
  }
}

// ── Orders Overview tab ────────────────────────────────────────────────────────
class _OrdersOverview extends StatelessWidget {
  final ErpRepository repo;
  const _OrdersOverview({required this.repo});

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<Map<String, dynamic>>>(
      loader: repo.orders,
      isEmpty: (d) => false,
      emptyMessage: 'No orders.',
      builder: (context, orders, _) {
        final delivered = orders.where((o) => o['is_delivered'] == true).length;
        final inProg    = orders.where((o) => o['status'] == 'In progress').length;
        final notStart  = orders.where((o) => o['status'] == 'Initial Stage').length;
        final hot       = orders.where((o) => o['is_hot'] == true).length;

        // Stage breakdown
        final stageCount = <String, int>{};
        for (final o in orders) {
          final s = str(o['current_stage'], 'Unknown');
          stageCount[s] = (stageCount[s] ?? 0) + 1;
        }
        // Source breakdown
        final sourceCount = <String, int>{};
        for (final o in orders) {
          final raw = str(o['order_source'], str(o['lead_type'], ''));
          final s = raw == '—' ? 'Direct' : raw;
          sourceCount[s] = (sourceCount[s] ?? 0) + 1;
        }
        // Finaliser breakdown
        final finaliserCount = <String, int>{};
        for (final o in orders) {
          final s = o['order_finalised_by']?.toString().trim() ?? '';
          if (s.isNotEmpty) finaliserCount[s] = (finaliserCount[s] ?? 0) + 1;
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            MetricRow(children: [
              MetricCard(label: 'Total Orders', value: '${orders.length}', icon: Icons.receipt_long),
              MetricCard(label: 'In Progress',  value: '$inProg',          icon: Icons.timelapse,            color: kWarning),
              MetricCard(label: 'Delivered',    value: '$delivered',        icon: Icons.local_shipping,       color: kSuccess),
              MetricCard(label: 'Not Started',  value: '$notStart',         icon: Icons.hourglass_empty,      color: kInfo),
              MetricCard(label: 'Hot Leads',    value: '$hot',              icon: Icons.local_fire_department, color: kDanger),
            ]),
            const SizedBox(height: 18),
            _BreakdownCard(title: 'Production Stage', data: stageCount, total: orders.length),
            const SizedBox(height: 12),
            _BreakdownCard(title: 'Order Source',     data: sourceCount, total: orders.length),
            if (finaliserCount.isNotEmpty) ...[
              const SizedBox(height: 12),
              _BreakdownCard(title: 'Finalised By', data: finaliserCount, total: orders.length),
            ],
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Text('All Orders', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(width: 8),
                StatusChip('${orders.length}', color: kBrand),
              ]),
            ),
            // Column headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(children: [
                const Expanded(flex: 3, child: Text('Client', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                const Expanded(flex: 2, child: Text('Location', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                const Expanded(flex: 2, child: Text('Stage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                const Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
            const Divider(height: 1),
            ...orders.map((o) => _OverviewRow(order: o)),
          ],
        );
      },
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final Map<String, int> data;
  final int total;
  const _BreakdownCard({required this.title, required this.data, required this.total});

  @override
  Widget build(BuildContext context) {
    final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            for (final e in sorted) ...[
              Row(children: [
                SizedBox(
                  width: 130,
                  child: Text(e.key, style: const TextStyle(fontSize: 12.5),
                      overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : e.value / total,
                      backgroundColor: Theme.of(context).dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(kBrand),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 28,
                  child: Text('${e.value}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OverviewRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final isDelivered = o['is_delivered'] == true;
    final status = str(o['status'], 'open');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(str(o['client_name']),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis),
            if ((o['product_name']?.toString().trim() ?? '').isNotEmpty)
              Text(str(o['product_name']),
                  style: TextStyle(fontSize: 11.5, color: Theme.of(context).textTheme.bodySmall?.color),
                  overflow: TextOverflow.ellipsis),
          ]),
        ),
        Expanded(
          flex: 2,
          child: Text(str(o['location'], '—'),
              style: TextStyle(fontSize: 11.5, color: Theme.of(context).textTheme.bodySmall?.color),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          flex: 2,
          child: Text(str(o['current_stage'], '—'),
              style: const TextStyle(fontSize: 11.5),
              overflow: TextOverflow.ellipsis),
        ),
        StatusChip(
          isDelivered ? 'Delivered' : status,
          color: isDelivered ? kSuccess : statusColor(status),
        ),
      ]),
    );
  }
}

// ── Operations Kanban ──────────────────────────────────────────────────────────
class _ProdStage {
  final String label;
  final Color color;
  final String statusValue;
  final bool isDelivered;
  const _ProdStage(this.label, this.color, this.statusValue, {this.isDelivered = false});
}

const _prodStages = <_ProdStage>[
  _ProdStage('New / Initial',         Color(0xFF6B7280), 'Initial Stage'),
  _ProdStage('Carpentry',             Color(0xFFC5A059), 'In progress'),
  _ProdStage('Paint Shop',            Color(0xFF4C8DFF), 'In progress'),
  _ProdStage('Packaging',             Color(0xFFA855F7), 'In progress'),
  _ProdStage('Dispatch',              Color(0xFFE29A2B), 'In progress'),
  _ProdStage('Installed / Delivered', Color(0xFF1FB89B), 'Completed', isDelivered: true),
];

class _OperationsBoard extends StatefulWidget {
  final ErpRepository repo;
  const _OperationsBoard({required this.repo});
  @override
  State<_OperationsBoard> createState() => _OperationsBoardState();
}

class _OperationsBoardState extends State<_OperationsBoard> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.orders();
  }

  void _reload() => setState(() => _future = widget.repo.orders());

  Future<void> _moveStage(Map<String, dynamic> order, _ProdStage stage) async {
    try {
      await widget.repo.updateRow('orders', 'id', order['id'], {
        'current_stage': stage.label,
        'status':        stage.statusValue,
        'is_delivered':  stage.isDelivered,
      });
      _reload();
    } catch (e) {
      if (mounted) toast(context, 'Move failed: $e');
    }
  }

  Future<void> _editOrder(Map<String, dynamic> order) async {
    final res = await showRecordForm(context,
        title: 'Edit Order', fields: _orderFields(), initial: order);
    if (res == null) return;
    try {
      await widget.repo.updateRow('orders', 'id', order['id'], res);
      _reload();
    } catch (e) {
      if (mounted) toast(context, 'Update failed: $e');
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
        final orders = snap.data ?? [];
        final byStage = {for (final s in _prodStages) s.label: <Map<String, dynamic>>[]};
        for (final o in orders) {
          final stage = str(o['current_stage'], 'New / Initial');
          (byStage[stage] ?? byStage['New / Initial']!).add(o);
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final stage in _prodStages)
                  _ProdColumn(
                    stage: stage,
                    orders: byStage[stage.label]!,
                    onMove: (o, s) => _moveStage(o, s),
                    onEdit: _editOrder,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProdColumn extends StatelessWidget {
  final _ProdStage stage;
  final List<Map<String, dynamic>> orders;
  final Future<void> Function(Map<String, dynamic>, _ProdStage) onMove;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  const _ProdColumn({
    required this.stage, required this.orders,
    required this.onMove, required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final color = stage.color;
    return Container(
      width: 230,
      margin: const EdgeInsets.only(right: 10, bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Column header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(children: [
              Expanded(child: Text(stage.label,
                  style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 12.5))),
              StatusChip('${orders.length}', color: color),
            ]),
          ),
          // Cards
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              children: orders.map((o) => _ProdCard(
                    order: o,
                    currentStage: stage,
                    onMove: onMove,
                    onEdit: () => onEdit(o),
                  )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProdCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final _ProdStage currentStage;
  final Future<void> Function(Map<String, dynamic>, _ProdStage) onMove;
  final VoidCallback onEdit;
  const _ProdCard({
    required this.order, required this.currentStage,
    required this.onMove, required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (o['is_hot'] == true) ...[
                  const Icon(Icons.local_fire_department, size: 14, color: kDanger),
                  const SizedBox(width: 4),
                ],
                Expanded(child: Text(str(o['client_name']),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 17),
                  padding: EdgeInsets.zero,
                  onSelected: (v) {
                    if (v == 'edit') {
                      onEdit();
                    } else {
                      final s = _prodStages.firstWhere((s) => s.label == v);
                      onMove(o, s);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit order')),
                    const PopupMenuDivider(),
                    ..._prodStages
                        .where((s) => s.label != currentStage.label)
                        .map((s) => PopupMenuItem(value: s.label, child: Text('→ ${s.label}'))),
                  ],
                ),
              ]),
              if ((o['product_name']?.toString().trim() ?? '').isNotEmpty)
                Text(str(o['product_name']),
                    style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
              const SizedBox(height: 5),
              Wrap(spacing: 8, runSpacing: 3, children: [
                if ((o['location']?.toString().trim() ?? '').isNotEmpty)
                  _Tag(Icons.location_on_outlined, str(o['location'])),
                if (o['delivery_date'] != null)
                  _Tag(Icons.calendar_today_outlined, fmtDate(o['delivery_date'])),
                if (o['amount'] != null)
                  _Tag(Icons.currency_rupee, fmtInr(o['amount'])),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
