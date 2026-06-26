import 'package:flutter/material.dart';

import '../data/erp_repository.dart';
import 'erp_ui.dart';
import 'record_form.dart';

/// A reusable list with built-in Add / Edit / Delete wired to a Supabase table
/// via [ErpRepository]. Renders an optional metrics header above the list.
class CrudList extends StatefulWidget {
  final ErpRepository repo;
  final String table;
  final String idCol;
  final String addLabel;
  final String editLabel;
  final Future<List<Map<String, dynamic>>> Function() loader;
  final List<FieldSpec> Function() fields;
  final Widget Function(
          Map<String, dynamic> row, VoidCallback onEdit, VoidCallback onDelete)
      tile;

  /// Called with (context, rows, onAdd) — onAdd triggers the built-in add form.
  /// Put AddBar(label: ..., onTap: onAdd) wherever you want the button.
  final Widget Function(
      BuildContext, List<Map<String, dynamic>>, VoidCallback onAdd)? header;

  /// Set false when the header already renders the add button via onAdd.
  final bool showAddBar;

  final String emptyMessage;

  /// When non-empty, a search bar is shown. Rows are matched if ANY of these
  /// field keys contain the query string (case-insensitive).
  final List<String> searchFields;

  /// Optional placeholder text for the search field.
  final String searchHint;

  /// Optional transform applied to the form result before insert/update.
  final Map<String, dynamic> Function(Map<String, dynamic>)? prepareCreate;

  const CrudList({
    super.key,
    required this.repo,
    required this.table,
    required this.idCol,
    required this.addLabel,
    required this.editLabel,
    required this.loader,
    required this.fields,
    required this.tile,
    this.header,
    this.showAddBar = true,
    this.emptyMessage = 'No records found.',
    this.searchFields = const [],
    this.searchHint = 'Search…',
    this.prepareCreate,
  });

  @override
  State<CrudList> createState() => _CrudListState();
}

class _CrudListState extends State<CrudList> {
  String _query = '';

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> list) {
    if (widget.searchFields.isEmpty) return list;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((row) {
      return widget.searchFields.any((f) {
        return (row[f]?.toString().toLowerCase() ?? '').contains(q);
      });
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<Map<String, dynamic>>>(
      loader: widget.loader,
      isEmpty: (d) => false,
      emptyMessage: widget.emptyMessage,
      builder: (context, list, refresh) {
        Future<void> add() async {
          final res = await showRecordForm(context,
              title: widget.addLabel, fields: widget.fields());
          if (res == null) return;
          try {
            await widget.repo
                .create(widget.table, widget.prepareCreate?.call(res) ?? res);
            await refresh();
          } catch (e) {
            if (context.mounted) toast(context, 'Add failed: $e');
          }
        }

        Future<void> edit(Map<String, dynamic> row) async {
          final res = await showRecordForm(context,
              title: widget.editLabel, fields: widget.fields(), initial: row);
          if (res == null) return;
          try {
            await widget.repo
                .updateRow(widget.table, widget.idCol, row[widget.idCol], res);
            await refresh();
          } catch (e) {
            if (context.mounted) toast(context, 'Update failed: $e');
          }
        }

        Future<void> del(Map<String, dynamic> row) async {
          if (!await confirmDelete(context, 'this record')) return;
          try {
            await widget.repo
                .deleteRow(widget.table, widget.idCol, row[widget.idCol]);
            await refresh();
          } catch (e) {
            if (context.mounted) toast(context, 'Delete failed: $e');
          }
        }

        final visible = _filter(list);

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            if (widget.header != null) ...[
              widget.header!(context, list, add),
              const SizedBox(height: 4),
            ],
            if (widget.showAddBar) AddBar(label: widget.addLabel, onTap: add),
            if (widget.searchFields.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _query = ''),
                          )
                        : null,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (_query.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '${visible.length} of ${list.length} results',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
            ],
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(
                  child: Text(_query.isNotEmpty
                      ? 'No results for "$_query"'
                      : widget.emptyMessage),
                ),
              ),
            ...visible.map((row) =>
                widget.tile(row, () => edit(row), () => del(row))),
          ],
        );
      },
    );
  }
}
