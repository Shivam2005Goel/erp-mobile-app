import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Brand accent used across the ERP (Argmac orange).
const Color kBrand = Color(0xFFf37021);

final _dateFmt = DateFormat('dd MMM yyyy');
final _numFmt = NumberFormat.decimalPattern('en_IN');
final _inrFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

String fmtDate(dynamic v) {
  if (v == null) return '—';
  final d = DateTime.tryParse(v.toString());
  return d == null ? v.toString() : _dateFmt.format(d.toLocal());
}

String fmtNum(dynamic v) {
  final n = v is num ? v : num.tryParse('${v ?? ''}');
  return n == null ? '—' : _numFmt.format(n);
}

String fmtInr(dynamic v) {
  final n = v is num ? v : num.tryParse('${v ?? ''}');
  return n == null ? '—' : _inrFmt.format(n);
}

String str(dynamic v, [String fallback = '—']) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? fallback : s;
}

/// A compact KPI card.
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? kBrand;
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: c, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color)),
        ],
      ),
    );
  }
}

/// Wraps a metric row in a horizontally scrollable strip.
class MetricRow extends StatelessWidget {
  final List<Widget> children;
  const MetricRow({super.key, required this.children});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final w in children) ...[w, const SizedBox(width: 12)],
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionTitle(this.title, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color)),
            ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  const StatusChip(this.text, {super.key, this.color = kBrand});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// Status palette mirrors the web app's Rhombus tokens.
const Color kSuccess = Color(0xFF1FB89B);
const Color kWarning = Color(0xFFE29A2B);
const Color kDanger = Color(0xFFE5544B);
const Color kInfo = Color(0xFF4C8DFF);

/// Maps a free-text status to a colour for chips.
Color statusColor(String? status) {
  final s = (status ?? '').toLowerCase();
  if (s.contains('done') ||
      s.contains('complete') ||
      s.contains('approved') ||
      s.contains('resolved') ||
      s.contains('delivered') ||
      s.contains('present')) {
    return kSuccess;
  }
  if (s.contains('progress') ||
      s.contains('pending') ||
      s.contains('open') ||
      s.contains('hot') ||
      s.contains('follow')) {
    return kWarning;
  }
  if (s.contains('reject') ||
      s.contains('lost') ||
      s.contains('delay') ||
      s.contains('absent') ||
      s.contains('cancel')) {
    return kDanger;
  }
  return kInfo;
}

/// A FutureBuilder wrapper with consistent loading / error / empty states and
/// pull-to-refresh.
class AsyncSection<T> extends StatefulWidget {
  final Future<T> Function() loader;
  final Widget Function(BuildContext, T, Future<void> Function()) builder;
  final bool Function(T)? isEmpty;
  final String emptyMessage;
  const AsyncSection({
    super.key,
    required this.loader,
    required this.builder,
    this.isEmpty,
    this.emptyMessage = 'No records found.',
  });

  @override
  State<AsyncSection<T>> createState() => _AsyncSectionState<T>();
}

class _AsyncSectionState<T> extends State<AsyncSection<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  Future<void> _refresh() async {
    setState(() => _future = widget.loader());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<T>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(
              padding: EdgeInsets.only(top: 80),
              child: CircularProgressIndicator(),
            ));
          }
          if (snap.hasError) {
            return ListView(children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text('Failed to load data',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('${snap.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ]),
              ),
            ]);
          }
          final data = snap.data as T;
          final empty = widget.isEmpty?.call(data) ?? false;
          if (empty) {
            return ListView(children: [
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Center(
                  child: Column(children: [
                    Icon(Icons.inbox_outlined,
                        size: 44,
                        color: Theme.of(context).disabledColor),
                    const SizedBox(height: 10),
                    Text(widget.emptyMessage,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ]),
                ),
              ),
            ]);
          }
          return widget.builder(context, data, _refresh);
        },
      ),
    );
  }
}

/// Full-width "Add" button placed at the top of a list.
class AddBar extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const AddBar({super.key, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: kBrand,
            side: const BorderSide(color: kBrand),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

/// Compact Edit / Delete overflow menu for a list row.
class RowMenu extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const RowMenu({super.key, this.onEdit, this.onDelete});
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      tooltip: 'Actions',
      onSelected: (v) {
        if (v == 'edit') onEdit?.call();
        if (v == 'delete') onDelete?.call();
      },
      itemBuilder: (_) => [
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined, size: 18),
              title: Text('Edit'),
            ),
          ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, size: 18, color: kDanger),
              title: Text('Delete', style: TextStyle(color: kDanger)),
            ),
          ),
      ],
    );
  }
}

/// Confirms a destructive delete. Returns true if the user confirmed.
Future<bool> confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete?'),
      content: Text('Delete $what? This cannot be undone.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: kDanger),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Shows a snackbar message.
void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// A simple labelled key/value card used in detail sheets.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).textTheme.bodySmall?.color)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
