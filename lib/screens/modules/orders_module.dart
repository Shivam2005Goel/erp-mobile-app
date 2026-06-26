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
const _currencies       = ['INR', 'USD', 'EUR', 'GBP', 'AED'];
const _orderStatuses    = ['Initial Stage', 'In progress', 'Completed'];
const _productionStages = [
  'New / Initial', 'Carpentry', 'Paint Shop', 'Packaging', 'Dispatch', 'Installed / Delivered',
];
const _finishOptions = [
  'Veneer', 'Suede', 'PU Paint', 'Leather', 'Laminate',
  'Profile', 'Felt/Cloth', 'Pocket', 'Slate',
];

List<FieldSpec> _orderFields() => const [
  FieldSpec('client_name',        'Client Name',          required: true),
  FieldSpec('company_name',       'Company Name'),
  FieldSpec('location',           'Location'),
  FieldSpec('country',            'Country'),
  FieldSpec('contact_number',     'Contact Number'),
  FieldSpec('email',              'Email'),
  FieldSpec('products',           'Products'),
  FieldSpec('product_name',       'Product Name'),
  FieldSpec('table_type',         'Table Type'),
  FieldSpec('quantity',           'Quantity',             type: FieldType.number),
  FieldSpec('status',             'Status',               type: FieldType.dropdown, options: _orderStatuses),
  FieldSpec('current_stage',      'Production Stage',     type: FieldType.dropdown, options: _productionStages),
  FieldSpec('is_delivered',       'Delivered',            type: FieldType.boolean),
  FieldSpec('self_installed',     'Self Installed',       type: FieldType.boolean),
  FieldSpec('order_date',         'Order Date',           type: FieldType.date),
  FieldSpec('lead_date',          'Lead Date',            type: FieldType.date),
  FieldSpec('expected_completion','Expected Completion',  type: FieldType.date),
  FieldSpec('delivery_date',      'Delivery Date',        type: FieldType.date),
  FieldSpec('order_source',       'Order Source',         type: FieldType.dropdown, options: _leadTypes),
  FieldSpec('lead_type',          'Lead Type',            type: FieldType.dropdown, options: _leadTypes),
  FieldSpec('client_type',        'Client Category',      type: FieldType.dropdown, options: _clientCategories),
  FieldSpec('order_finalised_by', 'Finalised By'),
  FieldSpec('amount',             'Order Amount',         type: FieldType.number),
  FieldSpec('currency',           'Currency',             type: FieldType.dropdown, options: _currencies),
  FieldSpec('is_hot',             'Hot Lead',             type: FieldType.boolean),
  FieldSpec('carpentry_by',       'Carpentry By'),
  FieldSpec('paint_by',           'Paint By'),
  FieldSpec('packaging_by',       'Packaging By'),
  FieldSpec('dispatch_by',        'Dispatch By'),
  FieldSpec('installed_by',       'Installed By'),
  FieldSpec('tracking_link',      'Tracking Link'),
  FieldSpec('finishes',           'Finishes',             type: FieldType.dropdown, options: _finishOptions),
  FieldSpec('days_to_complete',   'Days to Complete',     type: FieldType.number),
  FieldSpec('on_which_day',       'On Which Day'),
  FieldSpec('reason_for_delay',   'Reason for Delay'),
  FieldSpec('spec_sheet_url',     'Spec Sheet URL'),
  FieldSpec('notes',              'Notes',                type: FieldType.multiline),
  FieldSpec('remarks',            'Remarks',              type: FieldType.multiline),
];

// ── Module root ───────────────────────────────────────────────────────────────
class OrdersModule extends StatelessWidget {
  OrdersModule({super.key});
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
              Tab(text: 'Operations'),
              Tab(text: 'Orders'),
              Tab(text: 'Priority'),
              Tab(text: 'Materials'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _OperationsBoard(repo: _repo),
                _ordersTab(),
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
            MetricCard(label: 'In Progress', value: '$inProg',        icon: Icons.timelapse,      color: kWarning),
            MetricCard(label: 'Delivered',   value: '$delivered',     icon: Icons.local_shipping,  color: kSuccess),
            MetricCard(label: 'Not Started', value: '$notStart',      icon: Icons.hourglass_empty, color: kInfo),
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
          FieldSpec('order_name',    'Order name',    required: true),
          FieldSpec('particulars',   'Particulars',   type: FieldType.multiline),
          FieldSpec('priority',      'Priority',      type: FieldType.dropdown, options: ['High', 'Medium', 'Low']),
          FieldSpec('order_date',    'Order date',    type: FieldType.date),
          FieldSpec('delivery_date', 'Delivery date', type: FieldType.date),
          FieldSpec('notes',         'Notes',         type: FieldType.multiline),
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
          FieldSpec('material_pending',    'Material pending',  required: true),
          FieldSpec('product_name',        'Product'),
          FieldSpec('client_name',         'Client'),
          FieldSpec('material_pending_by', 'Pending by'),
          FieldSpec('status',              'Status'),
          FieldSpec('resolved_date',       'Resolved date',     type: FieldType.date),
          FieldSpec('comments',            'Comments',          type: FieldType.multiline),
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

// ── Rich order tile (Orders tab) ───────────────────────────────────────────────
class _OrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _OrderTile({required this.order, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final o           = order;
    final isDelivered = o['is_delivered'] == true;
    final isHot       = o['is_hot'] == true;
    final status      = str(o['status'], 'open');

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
              Row(children: [
                if (isHot) const Icon(Icons.local_fire_department, size: 15, color: kDanger),
                if (isHot) const SizedBox(width: 4),
                Expanded(child: Text(str(o['client_name']),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
                StatusChip(isDelivered ? 'Delivered' : status,
                    color: isDelivered ? kSuccess : statusColor(status)),
                RowMenu(onEdit: onEdit, onDelete: onDelete),
              ]),
              if ((o['company_name']?.toString().trim() ?? '').isNotEmpty)
                Text(str(o['company_name']),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
              const SizedBox(height: 6),
              Wrap(spacing: 10, runSpacing: 4, children: [
                if ((o['product_name']?.toString().trim() ?? '').isNotEmpty)
                  _InfoTag(Icons.sports_esports_outlined, str(o['product_name'])),
                if ((o['location']?.toString().trim() ?? '').isNotEmpty)
                  _InfoTag(Icons.location_on_outlined, str(o['location'])),
                if ((o['current_stage']?.toString().trim() ?? '').isNotEmpty)
                  _InfoTag(Icons.build_outlined, str(o['current_stage'])),
                if (o['order_date'] != null)
                  _InfoTag(Icons.calendar_today_outlined, fmtDate(o['order_date'])),
                if (o['delivery_date'] != null)
                  _InfoTag(Icons.local_shipping_outlined, fmtDate(o['delivery_date'])),
                if (o['amount'] != null)
                  _InfoTag(Icons.currency_rupee, fmtInr(o['amount'])),
                if ((o['order_source']?.toString().trim() ?? '').isNotEmpty)
                  _InfoTag(Icons.link, str(o['order_source'])),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _InfoTag(this.icon, this.text);
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: Theme.of(context).textTheme.bodySmall?.color),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 11.5, color: Theme.of(context).textTheme.bodySmall?.color)),
    ]);
  }
}

// ── Operations Kanban ──────────────────────────────────────────────────────────

class _ProdStageConfig {
  final String label;
  final Color  color;
  final String statusValue;
  final bool   isDelivered;
  const _ProdStageConfig(this.label, this.color, this.statusValue, {this.isDelivered = false});
}

const _prodStages = <_ProdStageConfig>[
  _ProdStageConfig('New / Initial',         Color(0xFFEC4899), 'Initial Stage'),
  _ProdStageConfig('Carpentry',             Color(0xFFF97316), 'In progress'),
  _ProdStageConfig('Paint Shop',            Color(0xFFF59E0B), 'In progress'),
  _ProdStageConfig('Packaging',             Color(0xFF4C8DFF), 'In progress'),
  _ProdStageConfig('Dispatch',              Color(0xFF10B981), 'In progress'),
  _ProdStageConfig('Installed / Delivered', Color(0xFF22C55E), 'Completed', isDelivered: true),
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

  void _reload() { if (mounted) setState(() { _future = widget.repo.orders(); }); }

  Future<void> _moveStage(Map<String, dynamic> order, _ProdStageConfig stage) async {
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

  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    if (!await confirmDelete(context, str(order['client_name'], 'this order'))) return;
    try {
      await widget.repo.deleteRow('orders', 'id', order['id']);
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
        final orders = snap.data ?? [];

        final byStage = {for (final s in _prodStages) s.label: <Map<String, dynamic>>[]};
        for (final o in orders) {
          final stage = o['current_stage']?.toString().trim() ?? '';
          (byStage[stage] ?? byStage['New / Initial']!).add(o);
        }

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(10),
              child: SizedBox(
                height: constraints.maxHeight - 20,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final stage in _prodStages)
                      _ProdColumn(
                        stage: stage,
                        orders: byStage[stage.label]!,
                        onMove:   (o, s) => _moveStage(o, s),
                        onEdit:   _editOrder,
                        onDelete: _deleteOrder,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Kanban column ─────────────────────────────────────────────────────────────
class _ProdColumn extends StatelessWidget {
  final _ProdStageConfig                              stage;
  final List<Map<String, dynamic>>                    orders;
  final Future<void> Function(Map<String, dynamic>, _ProdStageConfig) onMove;
  final Future<void> Function(Map<String, dynamic>)   onEdit;
  final Future<void> Function(Map<String, dynamic>)   onDelete;

  const _ProdColumn({
    required this.stage, required this.orders,
    required this.onMove, required this.onEdit, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = stage.color;
    return Container(
      width: 270,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Column header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(stage.label.toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.w800, color: color,
                      fontSize: 12, letterSpacing: 0.5))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${orders.length}',
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          const Divider(height: 1),
          // ── Card list — DragTarget fills remaining height ──────────
          Expanded(
            child: DragTarget<Map<String, dynamic>>(
              onWillAcceptWithDetails: (d) =>
                  d.data['current_stage']?.toString() != stage.label,
              onAcceptWithDetails: (d) => onMove(d.data, stage),
              builder: (context, candidateData, _) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? color.withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(14)),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: orders.map((o) => LongPressDraggable<Map<String, dynamic>>(
                          data: o,
                          hapticFeedbackOnStart: true,
                          feedback: Material(
                            elevation: 8,
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 258,
                              child: _ProdCard(
                                order: o,
                                stageColor: color,
                                currentStage: stage,
                                onMove: (_, s) async {},
                                onEdit: () {},
                                onDelete: () {},
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: _ProdCard(
                              order: o,
                              stageColor: color,
                              currentStage: stage,
                              onMove: (_, s) async {},
                              onEdit: () {},
                              onDelete: () {},
                            ),
                          ),
                          child: _ProdCard(
                            order: o,
                            stageColor: color,
                            currentStage: stage,
                            onMove: onMove,
                            onEdit: () => onEdit(o),
                            onDelete: () => onDelete(o),
                          ),
                        )).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kanban card (matches web app style) ──────────────────────────────────────
class _ProdCard extends StatelessWidget {
  final Map<String, dynamic>    order;
  final Color                   stageColor;
  final _ProdStageConfig        currentStage;
  final Future<void> Function(Map<String, dynamic>, _ProdStageConfig) onMove;
  final VoidCallback            onEdit;
  final VoidCallback            onDelete;

  const _ProdCard({
    required this.order, required this.stageColor, required this.currentStage,
    required this.onMove, required this.onEdit, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final o           = order;
    final isHot       = o['is_hot'] == true;
    final isPriority  = o['priority'] != null || isHot;
    final status      = str(o['status'],       'Initial Stage');
    final stage       = str(o['current_stage'], currentStage.label);
    final productName = str(o['product_name'],  str(o['products'], ''));
    final tableType   = str(o['table_type'],    '');
    final companyName = str(o['company_name'],  '');
    final location    = str(o['location'],      '');
    final orderDate   = o['order_date'];
    final delivDate   = o['delivery_date'];
    final amount      = o['amount'];
    final source      = str(o['order_source'],  '');

    final productChip = tableType.isNotEmpty
        ? tableType
        : _inferProductChip(productName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: stageColor.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: Name + Priority badge ────────────────────────
              Row(children: [
                if (isHot) const Padding(
                  padding: EdgeInsets.only(right: 5),
                  child: Icon(Icons.local_fire_department, size: 14, color: kDanger),
                ),
                Expanded(
                  child: Text(str(o['client_name']),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                ),
                if (isPriority)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kDanger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: kDanger.withValues(alpha: 0.6)),
                    ),
                    child: const Text('PRIORITY',
                        style: TextStyle(color: kDanger, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  ),
              ]),

              // ── Row 2: Company + Product name ───────────────────────
              if (companyName.isNotEmpty && companyName != '—') ...[
                const SizedBox(height: 2),
                Text(companyName,
                    style: TextStyle(fontSize: 11.5,
                        color: Theme.of(context).textTheme.bodySmall?.color),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              if (productName.isNotEmpty && productName != '—') ...[
                const SizedBox(height: 2),
                Text(productName,
                    style: TextStyle(fontSize: 12.5, color: stageColor, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],

              // ── Row 3: Chips (product type, status, stage) ──────────
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (productChip.isNotEmpty)
                  _Chip(productChip, color: const Color(0xFF4C8DFF)),
                _StatusBadge(status),
                _Chip(stage, color: stageColor.withValues(alpha: 0.85)),
              ]),

              // ── Row 4: Info tags (dates, location, amount, source) ──
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 4, children: [
                if (orderDate != null)
                  _InfoTag(Icons.calendar_today_outlined,  'Order: ${fmtDate(orderDate)}'),
                if (delivDate != null)
                  _InfoTag(Icons.local_shipping_outlined,  'Deliver: ${fmtDate(delivDate)}'),
                if (location.isNotEmpty && location != '—')
                  _InfoTag(Icons.location_on_outlined, location),
                if (amount != null)
                  _InfoTag(Icons.currency_rupee, fmtInr(amount)),
                if (source.isNotEmpty && source != '—')
                  _InfoTag(Icons.link_outlined, source),
              ]),

              // ── Row 5: Action buttons ───────────────────────────────
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(children: [
                _ActionIcon(Icons.edit_outlined, color: stageColor, onTap: onEdit,    tooltip: 'Edit'),
                const SizedBox(width: 4),
                _ActionIcon(Icons.delete_outline, color: kDanger,   onTap: onDelete,  tooltip: 'Delete'),
                const Spacer(),
                // Move-stage popup
                PopupMenuButton<String>(
                  tooltip: 'Move stage',
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.swap_horiz_rounded, size: 20, color: stageColor),
                  onSelected: (v) {
                    final s = _prodStages.firstWhere((s) => s.label == v);
                    onMove(order, s);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(enabled: false,
                        child: Text('MOVE TO STAGE',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4))),
                    const PopupMenuDivider(),
                    ..._prodStages
                        .where((s) => s.label != currentStage.label)
                        .map((s) => PopupMenuItem(value: s.label, child: Text(s.label))),
                  ],
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // Infer a short product category from the product name
  String _inferProductChip(String name) {
    final n = name.toLowerCase();
    if (n.contains('pool'))       return 'Pool Table';
    if (n.contains('tt') || n.contains('table tennis')) return 'TT Table';
    if (n.contains('foosball'))   return 'Foosball';
    if (n.contains('air hockey')) return 'Air Hockey';
    if (n.contains('snooker'))    return 'Snooker';
    if (n.contains('chess'))      return 'Chess';
    if (n.contains('carrom'))     return 'Carrom';
    if (n.contains('bar'))        return 'Bar';
    if (n.contains('gaming'))     return 'Gaming Set';
    return '';
  }
}

// ── Small chip (product type / stage label) ──────────────────────────────────
class _Chip extends StatelessWidget {
  final String text;
  final Color  color;
  const _Chip(this.text, {required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Status badge (IN PROGRESS / INITIAL STAGE / COMPLETED) ───────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);
  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'in progress':
        color = kWarning; label = 'IN PROGRESS'; break;
      case 'completed':
        color = kSuccess; label = 'COMPLETED'; break;
      default:
        color = kInfo; label = 'INITIAL STAGE'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
    );
  }
}

// ── Icon action button ────────────────────────────────────────────────────────
class _ActionIcon extends StatelessWidget {
  final IconData   icon;
  final Color      color;
  final VoidCallback onTap;
  final String     tooltip;
  const _ActionIcon(this.icon, {required this.color, required this.onTap, required this.tooltip});
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
