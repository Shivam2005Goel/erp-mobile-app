import 'package:flutter/material.dart';

import '../../data/erp_repository.dart';
import '../../widgets/crud_list.dart';
import '../../widgets/erp_ui.dart';
import '../../widgets/record_form.dart';

/// Order management: orders, priority queue and pending materials.
class OrdersModule extends StatelessWidget {
  OrdersModule({super.key});
  final _repo = ErpRepository();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Orders'),
              Tab(text: 'Priority'),
              Tab(text: 'Pending Materials'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _orders(),
                _priority(),
                _materials(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orders() => CrudList(
        repo: _repo,
        table: 'orders',
        idCol: 'id',
        addLabel: 'Add Order',
        editLabel: 'Edit Order',
        loader: _repo.orders,
        emptyMessage: 'No orders yet.',
        fields: () => const [
          FieldSpec('client_name', 'Client name', required: true),
          FieldSpec('product_name', 'Product'),
          FieldSpec('location', 'Location'),
          FieldSpec('status', 'Status',
              type: FieldType.dropdown,
              options: ['Initial Stage', 'In progress', 'Completed']),
          FieldSpec('current_stage', 'Current stage',
              type: FieldType.dropdown,
              options: [
                'New / Initial',
                'Carpentry',
                'Paint Shop',
                'Packaging',
                'Dispatch',
                'Installed / Delivered',
              ]),
          FieldSpec('order_source', 'Order source'),
          FieldSpec('order_finalised_by', 'Finalised by'),
          FieldSpec('table_type', 'Table type'),
          FieldSpec('quantity', 'Quantity', type: FieldType.number),
          FieldSpec('order_date', 'Order date', type: FieldType.date),
          FieldSpec('expected_completion', 'Expected completion',
              type: FieldType.date),
          FieldSpec('delivery_date', 'Delivery date', type: FieldType.date),
          FieldSpec('finishes', 'Finishes'),
          FieldSpec('is_delivered', 'Delivered', type: FieldType.boolean),
          FieldSpec('reason_for_delay', 'Reason for delay'),
          FieldSpec('notes', 'Notes', type: FieldType.multiline),
          FieldSpec('remarks', 'Remarks', type: FieldType.multiline),
        ],
        header: (context, list, onAdd) {
          final delivered =
              list.where((o) => o['is_delivered'] == true).length;
          return MetricRow(children: [
            MetricCard(
                label: 'Total Orders',
                value: '${list.length}',
                icon: Icons.receipt_long),
            MetricCard(
                label: 'In Progress',
                value: '${list.length - delivered}',
                icon: Icons.timelapse,
                color: kWarning),
            MetricCard(
                label: 'Delivered',
                value: '$delivered',
                icon: Icons.local_shipping,
                color: kSuccess),
          ]);
        },
        tile: (o, onEdit, onDelete) => Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            onTap: onEdit,
            title: Text(str(o['client_name'])),
            subtitle: Text([
              if ((o['product_name']?.toString().trim() ?? '').isNotEmpty)
                o['product_name'],
              if ((o['location']?.toString().trim() ?? '').isNotEmpty)
                o['location'],
              'Ordered ${fmtDate(o['order_date'])}',
              if ((o['current_stage']?.toString().trim() ?? '').isNotEmpty)
                'Stage: ${o['current_stage']}',
            ].join(' • ')),
            isThreeLine: true,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              StatusChip(
                  o['is_delivered'] == true
                      ? 'Delivered'
                      : str(o['status'], 'open'),
                  color: o['is_delivered'] == true
                      ? kSuccess
                      : statusColor(o['status']?.toString())),
              RowMenu(onEdit: onEdit, onDelete: onDelete),
            ]),
          ),
        ),
      );

  Widget _priority() => CrudList(
        repo: _repo,
        table: 'priority_orders',
        idCol: 'id',
        addLabel: 'Add Priority Order',
        editLabel: 'Edit Priority Order',
        loader: _repo.priorityOrders,
        emptyMessage: 'No priority orders.',
        fields: () => const [
          FieldSpec('order_name', 'Order name', required: true),
          FieldSpec('particulars', 'Particulars', type: FieldType.multiline),
          FieldSpec('priority', 'Priority',
              type: FieldType.dropdown,
              options: ['High', 'Medium', 'Low']),
          FieldSpec('order_date', 'Order date', type: FieldType.date),
          FieldSpec('delivery_date', 'Delivery date', type: FieldType.date),
          FieldSpec('notes', 'Notes', type: FieldType.multiline),
        ],
        tile: (p, onEdit, onDelete) => Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            onTap: onEdit,
            leading: const Icon(Icons.priority_high, color: kDanger),
            title: Text(str(p['order_name'])),
            subtitle: Text([
              if ((p['particulars']?.toString().trim() ?? '').isNotEmpty)
                p['particulars'],
              'Deliver by ${fmtDate(p['delivery_date'])}',
            ].join(' • ')),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              StatusChip(str(p['priority'], 'normal'),
                  color: statusColor(p['priority']?.toString())),
              RowMenu(onEdit: onEdit, onDelete: onDelete),
            ]),
          ),
        ),
      );

  Widget _materials() => CrudList(
        repo: _repo,
        table: 'pending_materials',
        idCol: 'id',
        addLabel: 'Add Pending Material',
        editLabel: 'Edit Pending Material',
        loader: _repo.pendingMaterials,
        emptyMessage: 'No pending materials.',
        fields: () => const [
          FieldSpec('material_pending', 'Material pending', required: true),
          FieldSpec('product_name', 'Product'),
          FieldSpec('client_name', 'Client'),
          FieldSpec('material_pending_by', 'Pending by'),
          FieldSpec('status', 'Status'),
          FieldSpec('resolved_date', 'Resolved date', type: FieldType.date),
          FieldSpec('comments', 'Comments', type: FieldType.multiline),
        ],
        tile: (m, onEdit, onDelete) => Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            onTap: onEdit,
            title: Text(str(m['material_pending'], 'Material')),
            subtitle: Text([
              if ((m['product_name']?.toString().trim() ?? '').isNotEmpty)
                m['product_name'],
              if ((m['client_name']?.toString().trim() ?? '').isNotEmpty)
                m['client_name'],
              if ((m['material_pending_by']?.toString().trim() ?? '')
                  .isNotEmpty)
                'By ${m['material_pending_by']}',
            ].join(' • ')),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              StatusChip(str(m['status'], 'pending'),
                  color: statusColor(m['status']?.toString())),
              RowMenu(onEdit: onEdit, onDelete: onDelete),
            ]),
          ),
        ),
      );
}
