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
  late Future<List<Map<String, dynamic>>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  void _reload() {
    if (!mounted) return;
    setState(() { _future = widget.loader(); });
  }

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

  void _showError(String msg) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _add() async {
    if (_busy) return;
    final res = await showRecordForm(context,
        title: widget.addLabel, fields: widget.fields());
    if (res == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repo
          .create(widget.table, widget.prepareCreate?.call(res) ?? res);
      _reload();
    } catch (e) {
      _showError('Failed to add record.\n\n$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    if (_busy) return;
    final res = await showRecordForm(context,
        title: widget.editLabel, fields: widget.fields(), initial: row);
    if (res == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repo
          .updateRow(widget.table, widget.idCol, row[widget.idCol], res);
      _reload();
    } catch (e) {
      _showError('Failed to update record.\n\n$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _del(Map<String, dynamic> row) async {
    if (_busy) return;
    if (!await confirmDelete(context, 'this record')) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repo
          .deleteRow(widget.table, widget.idCol, row[widget.idCol]);
      _reload();
    } catch (e) {
      _showError('Failed to delete record.\n\n$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                snap.data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError && snap.data == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline,
                        size: 40, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text('Failed to load data',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text('${snap.error}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                    ),
                  ]),
                ),
              );
            }

            final list = snap.data ?? [];
            final visible = _filter(list);

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  if (widget.header != null) ...[
                    widget.header!(context, list, _add),
                    const SizedBox(height: 4),
                  ],
                  if (widget.showAddBar)
                    AddBar(label: widget.addLabel, onTap: _add),
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
                                  onPressed: () =>
                                      setState(() => _query = ''),
                                )
                              : null,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_query.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          '${visible.length} of ${list.length} results',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
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
                  ...visible.map((row) => widget.tile(
                        row,
                        () => _edit(row),
                        () => _del(row),
                      )),
                ],
              ),
            );
          },
        ),
        // Loading overlay while a mutation is in flight
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black12,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
