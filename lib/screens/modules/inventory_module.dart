import 'package:flutter/material.dart';

import '../../data/erp_repository.dart';
import '../../widgets/erp_ui.dart';
import '../../widgets/record_form.dart';

// ── Colour swatches for the type picker (mirrors web app) ─────────────────
const _kSwatches = <Color>[
  Color(0xFFc5a059),
  Color(0xFF4c8dff),
  Color(0xFFa855f7),
  Color(0xFF1fb89b),
  Color(0xFFf37021),
  Color(0xFFe5544b),
  Color(0xFFec4899),
  Color(0xFF6b7280),
];

// ── Helper: parse "#rrggbb" → Color ───────────────────────────────────────
Color _hex(String? s) {
  if (s == null || s.isEmpty) return kBrand;
  final h = s.replaceAll('#', '');
  if (h.length == 6) {
    return Color(int.tryParse('FF$h', radix: 16) ?? 0xFFf37021);
  }
  return kBrand;
}

// ── Helper: Color → "#rrggbb" ──────────────────────────────────────────────
String _toHex(Color c) {
  final v = c.toARGB32();
  final r = ((v >> 16) & 0xFF).toRadixString(16).padLeft(2, '0');
  final g = ((v >> 8) & 0xFF).toRadixString(16).padLeft(2, '0');
  final b = (v & 0xFF).toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}

// ── Bundled data loaded in one round-trip ─────────────────────────────────
class _InvData {
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> productTypes; // {product_name, category_value}
  final List<Map<String, dynamic>> categories;   // {id, value, label, color}
  final List<Map<String, dynamic>> items;         // {id, color, category, qty_till_date, …}

  const _InvData(this.products, this.productTypes, this.categories, this.items);

  /// Categories linked to [productName] via product_types.
  List<Map<String, dynamic>> catsFor(String productName) {
    final vals = productTypes
        .where((pt) => pt['product_name'] == productName)
        .map((pt) => pt['category_value'].toString())
        .toSet();
    return categories.where((c) => vals.contains(c['value'])).toList();
  }

  List<Map<String, dynamic>> itemsFor(String catValue) =>
      items.where((i) => i['category'] == catValue).toList();

  int unitsFor(String catValue) => itemsFor(catValue)
      .fold(0, (s, i) => s + ((i['qty_till_date'] as num?)?.toInt() ?? 0));
}

// ── Main widget ────────────────────────────────────────────────────────────
class InventoryModule extends StatefulWidget {
  const InventoryModule({super.key});

  @override
  State<InventoryModule> createState() => _InventoryModuleState();
}

class _InventoryModuleState extends State<InventoryModule> {
  final _repo = ErpRepository();
  _InvData? _data;
  bool _loading = true;
  String? _error;
  String? _sel; // selected product name

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait([
        _repo.products(),
        _repo.productTypes(),
        _repo.inventoryCategories(),
        _repo.inventoryItems(),
      ]);
      final data = _InvData(r[0], r[1], r[2], r[3]);
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
          if (_sel == null ||
              !data.products.any((p) => p['product_name'] == _sel)) {
            _sel = data.products.isNotEmpty
                ? data.products.first['product_name'].toString()
                : null;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── ADD PRODUCT ──────────────────────────────────────────────────────────
  Future<void> _addProduct() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => _SimpleInputDialog(
        title: 'ADD PRODUCT',
        titleIcon: Icons.tag,
        fieldLabel: 'PRODUCT NAME *',
        hint: 'e.g. Pool Table Cloth',
        ctrl: ctrl,
        submitLabel: '+ ADD PRODUCT',
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    try {
      await _repo.createProduct(name);
      await _load();
      if (mounted) setState(() => _sel = name);
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
  }

  // ── DELETE PRODUCT ───────────────────────────────────────────────────────
  Future<void> _deleteProduct(String name) async {
    if (!await confirmDelete(context, '"$name"')) return;
    try {
      await _repo.deleteProduct(name);
      await _load();
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
  }

  // ── ADD TYPE (manage types dialog) ───────────────────────────────────────
  Future<void> _manageTypes() async {
    await showDialog(
      context: context,
      builder: (ctx) => _ManageTypesDialog(
        repo: _repo,
        data: _data!,
        selectedProduct: _sel,
      ),
    );
    await _load();
  }

  // ── ADD ITEM ─────────────────────────────────────────────────────────────
  Future<void> _addItem() async {
    final data = _data;
    if (data == null) return;
    final typeLabels = data.categories.map((c) => c['label'].toString()).toList();
    final res = await showRecordForm(context,
        title: 'ADD INVENTORY ITEM',
        fields: [
          const FieldSpec('color', 'COLOUR / ITEM NAME', required: true),
          FieldSpec('category', 'TYPE',
              type: FieldType.dropdown,
              options: typeLabels,
              required: true),
          const FieldSpec('qty_till_date', 'QTY IN STOCK', type: FieldType.number),
          const FieldSpec('qty_from_china', 'QTY FROM CHINA'),
          const FieldSpec('used_at', 'USED AT (ORDERS / PROJECTS)'),
          const FieldSpec('notes', 'NOTES', type: FieldType.multiline),
        ],
        initial: {
          'qty_till_date': 0,
          if (_sel != null)
            'category': data.catsFor(_sel!).isNotEmpty
                ? data.catsFor(_sel!).first['label']
                : null,
        });
    if (res == null) return;
    // Map label → value slug
    final lbl = res['category']?.toString();
    if (lbl != null) {
      final cat = data.categories.firstWhere(
        (c) => c['label'] == lbl,
        orElse: () => {'value': lbl.toLowerCase()},
      );
      res['category'] = cat['value'];
    }
    try {
      await _repo.create('inventory_items', res);
      await _load();
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
  }

  // ── VIEW ITEMS ───────────────────────────────────────────────────────────
  void _viewItems(Map<String, dynamic> cat) {
    final data = _data;
    if (data == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ItemsScreen(
        catLabel: cat['label'].toString(),
        catValue: cat['value'].toString(),
        catColor: _hex(cat['color']?.toString()),
        repo: _repo,
        allCategories: data.categories,
        onChanged: _load,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Error: $_error'),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: _load, child: const Text('Retry')),
      ]));
    }

    final data = _data!;
    final cats = _sel != null ? data.catsFor(_sel!) : <Map<String, dynamic>>[];

    return Column(children: [
      // ── Action buttons ────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(children: [
          // Row 1: ADD PRODUCT (full width)
          _ActionBtn(
            label: '+ ADD PRODUCT',
            icon: Icons.inventory_2_outlined,
            subtitle: 'Create a new product category',
            onPressed: _addProduct,
          ),
          const SizedBox(height: 8),
          // Row 2: ADD TYPE + ADD ITEM side by side
          Row(children: [
            Expanded(
              child: _ActionBtn(
                label: '+ ADD TYPE',
                icon: Icons.category_outlined,
                subtitle: 'Manage item types',
                onPressed: _manageTypes,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionBtn(
                label: '+ ADD ITEM',
                icon: Icons.add_box_outlined,
                subtitle: 'Add inventory item',
                onPressed: _addItem,
              ),
            ),
            const SizedBox(width: 8),
            // Refresh icon
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _load,
              ),
            ),
          ]),
        ]),
      ),

      // ── Product tabs ──────────────────────────────────────────────────
      if (data.products.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.info_outline, color: kInfo),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('No products yet. Tap + ADD PRODUCT.')),
              ]),
            ),
          ),
        )
      else
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: data.products.map((p) {
              final name = p['product_name'].toString();
              final active = name == _sel;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _ProductTab(
                  name: name,
                  active: active,
                  onTap: () => setState(() => _sel = name),
                  onDelete: () => _deleteProduct(name),
                ),
              );
            }).toList(),
          ),
        ),

      const SizedBox(height: 10),

      // ── Category cards ────────────────────────────────────────────────
      Expanded(
        child: cats.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _sel == null
                        ? 'Select a product above.'
                        : 'No types linked to "$_sel" yet.\n\nUse "+ ADD TYPE" to manage types,\nthen link them to this product.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.95,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: cats.length,
                itemBuilder: (_, i) {
                  final cat = cats[i];
                  final val = cat['value'].toString();
                  return _CategoryCard(
                    label: cat['label'].toString(),
                    color: _hex(cat['color']?.toString()),
                    totalUnits: data.unitsFor(val),
                    itemCount: data.itemsFor(val).length,
                    onViewItems: () => _viewItems(cat),
                  );
                },
              ),
      ),
    ]);
  }
}

// ── Reusable action button ─────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? subtitle;
  final VoidCallback onPressed;

  const _ActionBtn({
    required this.label,
    required this.icon,
    this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: kBrand,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        letterSpacing: 0.4)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w400,
                          color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Product tab chip ──────────────────────────────────────────────────────
class _ProductTab extends StatelessWidget {
  final String name;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _ProductTab(
      {required this.name,
      required this.active,
      required this.onTap,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kBrand : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? kBrand : Theme.of(context).dividerColor),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.grid_view_rounded,
              size: 14,
              color: active
                  ? Colors.white
                  : Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(width: 6),
          Text(name.toUpperCase(),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyMedium?.color)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.delete_outline,
                size: 14,
                color: active
                    ? Colors.white70
                    : kDanger.withValues(alpha: 0.6)),
          ),
        ]),
      ),
    );
  }
}

// ── Category summary card ─────────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final String label;
  final Color color;
  final int totalUnits;
  final int itemCount;
  final VoidCallback onViewItems;
  const _CategoryCard({
    required this.label,
    required this.color,
    required this.totalUnits,
    required this.itemCount,
    required this.onViewItems,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color dot + label
            Row(children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 6),
            // View items link
            GestureDetector(
              onTap: onViewItems,
              child: Text('View items →',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: kBrand,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 16),
            // Big unit count
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$totalUnits',
                  style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.w900, height: 1)),
              const SizedBox(width: 5),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('units',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ),
            ]),
            const SizedBox(height: 6),
            Text('$itemCount item${itemCount == 1 ? '' : 's'} tracked',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ── Simple text-input dialog (for ADD PRODUCT) ────────────────────────────
class _SimpleInputDialog extends StatelessWidget {
  final String title;
  final IconData titleIcon;
  final String fieldLabel;
  final String hint;
  final TextEditingController ctrl;
  final String submitLabel;
  const _SimpleInputDialog({
    required this.title,
    required this.titleIcon,
    required this.fieldLabel,
    required this.hint,
    required this.ctrl,
    required this.submitLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      title: Row(children: [
        Icon(titleIcon, color: kBrand, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 14, letterSpacing: 0.5)),
        const Spacer(),
        IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(fieldLabel,
              style: const TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 0.8,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint, isDense: true),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kBrand),
          onPressed: () => Navigator.pop(context, ctrl.text.trim()),
          child: Text(submitLabel),
        ),
      ],
    );
  }
}

// ── Manage Types dialog ────────────────────────────────────────────────────
class _ManageTypesDialog extends StatefulWidget {
  final ErpRepository repo;
  final _InvData data;
  final String? selectedProduct;
  const _ManageTypesDialog(
      {required this.repo, required this.data, required this.selectedProduct});

  @override
  State<_ManageTypesDialog> createState() => _ManageTypesDialogState();
}

class _ManageTypesDialogState extends State<_ManageTypesDialog> {
  late List<Map<String, dynamic>> _types;
  final _nameCtrl = TextEditingController();
  Color _pickedColor = _kSwatches[0];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _types = List.from(widget.data.categories);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete(Map<String, dynamic> t) async {
    setState(() => _busy = true);
    try {
      await widget.repo.deleteCategory(t['id'].toString());
      setState(() => _types.removeWhere((x) => x['id'] == t['id']));
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      final slug = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final hex = _toHex(_pickedColor);
      await widget.repo.create('inventory_categories', {
        'label': name,
        'value': slug,
        'color': hex,
      });
      // If a product is selected, also link this type to it
      if (widget.selectedProduct != null) {
        try {
          await widget.repo
              .create('product_types', {
            'product_name': widget.selectedProduct,
            'category_value': slug,
          });
        } catch (_) {} // ignore duplicate key
      }
      setState(() {
        _types.add({'label': name, 'value': slug, 'color': hex});
        _nameCtrl.clear();
        _pickedColor = _kSwatches[0];
      });
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Row(children: [
              const Icon(Icons.settings_outlined, color: kBrand, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('MANAGE ITEM TYPES',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ),
              IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ]),
            const Divider(height: 20),

            // Current types list
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('CURRENT TYPES',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                      letterSpacing: 0.8)),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: _types.map((t) {
                    final c = _hex(t['color']?.toString());
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: c, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(t['label'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5)),
                        ),
                        Text(t['value'] ?? '',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: kDanger, size: 18),
                          visualDensity: VisualDensity.compact,
                          onPressed: _busy ? null : () => _delete(t),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ),

            const Divider(height: 20),

            // Add new type form
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('ADD NEW TYPE',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                      letterSpacing: 0.8)),
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('NAME *',
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey,
                      letterSpacing: 0.8)),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  hintText: 'e.g. Zipper', isDense: true),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('COLOUR',
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey,
                      letterSpacing: 0.8)),
            ),
            const SizedBox(height: 8),
            Row(
              children: _kSwatches
                  .map((c) => GestureDetector(
                        onTap: () =>
                            setState(() => _pickedColor = c),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _pickedColor == c
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: _pickedColor == c
                                ? [
                                    BoxShadow(
                                        color: c.withValues(alpha: 0.5),
                                        blurRadius: 6)
                                  ]
                                : null,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style:
                      FilledButton.styleFrom(backgroundColor: kBrand),
                  onPressed: _busy ? null : _add,
                  child: const Text('+ ADD TYPE'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Items screen (navigated to via "View items →") ────────────────────────
class _ItemsScreen extends StatefulWidget {
  final String catLabel;
  final String catValue;
  final Color catColor;
  final ErpRepository repo;
  final List<Map<String, dynamic>> allCategories;
  final Future<void> Function() onChanged;
  const _ItemsScreen({
    required this.catLabel,
    required this.catValue,
    required this.catColor,
    required this.repo,
    required this.allCategories,
    required this.onChanged,
  });

  @override
  State<_ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<_ItemsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      final all = await widget.repo.inventoryItems();
      if (mounted) {
        setState(() {
          _items = all
              .where((i) => i['category'] == widget.catValue)
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
    await widget.onChanged();
  }

  List<FieldSpec> get _fields {
    final labels =
        widget.allCategories.map((c) => c['label'].toString()).toList();
    return [
      const FieldSpec('color', 'COLOUR / ITEM NAME', required: true),
      FieldSpec('category', 'TYPE',
          type: FieldType.dropdown, options: labels),
      const FieldSpec('qty_till_date', 'QTY IN STOCK',
          type: FieldType.number),
      const FieldSpec('qty_from_china', 'QTY FROM CHINA'),
      const FieldSpec('used_at', 'USED AT (ORDERS / PROJECTS)'),
      const FieldSpec('notes', 'NOTES', type: FieldType.multiline),
    ];
  }

  Map<String, dynamic> _toForm(Map<String, dynamic> item) {
    final val = item['category']?.toString();
    final cat = widget.allCategories.firstWhere(
      (c) => c['value'] == val,
      orElse: () => {'label': val ?? ''},
    );
    return {...item, 'category': cat['label']};
  }

  Map<String, dynamic> _fromForm(
      Map<String, dynamic> res, String fallbackVal) {
    final lbl = res['category']?.toString();
    if (lbl != null) {
      final cat = widget.allCategories.firstWhere(
        (c) => c['label'] == lbl,
        orElse: () => {'value': fallbackVal},
      );
      res['category'] = cat['value'];
    }
    return res;
  }

  Future<void> _add() async {
    final res = await showRecordForm(context,
        title: 'ADD INVENTORY ITEM',
        fields: _fields,
        initial: {
          'category': widget.catLabel,
          'qty_till_date': 0,
        });
    if (res == null) return;
    try {
      await widget.repo
          .create('inventory_items', _fromForm(res, widget.catValue));
      await _loadItems();
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final res = await showRecordForm(context,
        title: 'EDIT ITEM', fields: _fields, initial: _toForm(item));
    if (res == null) return;
    try {
      await widget.repo.updateRow('inventory_items', 'id', item['id'],
          _fromForm(res, item['category'] ?? widget.catValue));
      await _loadItems();
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    if (!await confirmDelete(context, str(item['color'], 'this item'))) {
      return;
    }
    try {
      await widget.repo.deleteRow('inventory_items', 'id', item['id']);
      await _loadItems();
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    num qty(Map m) => num.tryParse('${m['qty_till_date'] ?? 0}') ?? 0;
    final total = _items.fold<num>(0, (s, i) => s + qty(i));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: widget.catColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.catLabel.toUpperCase(),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            Text(
                '$total units · ${_items.length} item${_items.length == 1 ? '' : 's'} tracked',
                style: const TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w400)),
          ]),
        ]),
        actions: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: kBrand,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: _add,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Add Item'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 48,
                        color: Theme.of(context).disabledColor),
                    const SizedBox(height: 12),
                    const Text('No items for this type yet.'),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: kBrand),
                      onPressed: _add,
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Add First Item'),
                    ),
                  ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    final q = qty(item);
                    final statusColor = q == 0
                        ? kDanger
                        : (q <= 2 ? kWarning : kSuccess);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              statusColor.withValues(alpha: 0.15),
                          child: Text('$q',
                              style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(str(item['color']),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          [
                            if ((item['qty_from_china']
                                        ?.toString()
                                        .trim() ??
                                    '')
                                .isNotEmpty)
                              'From China: ${item['qty_from_china']}',
                            if ((item['used_at']?.toString().trim() ??
                                    '')
                                .isNotEmpty)
                              'In use: ${item['used_at']}',
                            if ((item['notes']?.toString().trim() ?? '')
                                .isNotEmpty)
                              item['notes'],
                          ].where((s) => s.isNotEmpty).join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: RowMenu(
                          onEdit: () => _edit(item),
                          onDelete: () => _delete(item),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
