import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/erp_repository.dart';
import 'erp_ui.dart';

/// App-bar bell that surfaces role-aware actionable notifications and lets the
/// user jump to the relevant module.
class NotificationBell extends StatefulWidget {
  final void Function(String route) onNavigate;
  const NotificationBell({super.key, required this.onNavigate});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _repo = ErpRepository();
  List<AppNotification> _items = [];
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  Future<void> _load() async {
    final user = AppStateScope.of(context).currentUser;
    if (user == null) return;
    try {
      final items = await _repo.notifications(
        userId: user.id,
        role: user.role,
        userName: user.fullName,
      );
      if (mounted) setState(() => _items = items);
    } catch (_) {/* keep silent — non-critical */}
  }

  Color _priorityColor(int p) =>
      p == 0 ? kDanger : (p == 1 ? kWarning : kInfo);

  IconData _typeIcon(String type) {
    switch (type) {
      case 'ticket':
        return Icons.confirmation_number;
      case 'leave':
        return Icons.beach_access;
      case 'material':
        return Icons.inventory_2;
      case 'after_sales':
        return Icons.build;
      case 'task':
        return Icons.task_alt;
      case 'lead':
        return Icons.trending_up;
      default:
        return Icons.notifications;
    }
  }

  void _openPanel() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  const Text('Notifications',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  if (_items.isNotEmpty)
                    StatusChip('${_items.length}', color: kBrand),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () async {
                      await _load();
                      if (ctx.mounted) Navigator.pop(ctx);
                      _openPanel();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_off_outlined, size: 40),
                            SizedBox(height: 12),
                            Text("You're all caught up."),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final n = _items[i];
                        final c = _priorityColor(n.priority);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: c.withValues(alpha: 0.15),
                            child: Icon(_typeIcon(n.type), color: c, size: 20),
                          ),
                          title: Text(n.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(n.description),
                          isThreeLine: n.description.length > 40,
                          onTap: () {
                            Navigator.pop(ctx);
                            widget.onNavigate(n.route);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Notifications',
          onPressed: _openPanel,
        ),
        if (_items.isNotEmpty)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: kDanger, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '${_items.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
