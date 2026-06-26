import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'erp_ui.dart';

enum FieldType { text, multiline, number, date, dropdown, boolean }

/// Declarative description of one form field.
class FieldSpec {
  final String key;
  final String label;
  final FieldType type;
  final bool required;
  final List<String>? options; // for dropdown
  const FieldSpec(
    this.key,
    this.label, {
    this.type = FieldType.text,
    this.required = false,
    this.options,
  });
}

/// Opens a modal form for creating/editing a record. Returns the edited field
/// map (only the declared keys) on save, or null if cancelled. Dates are
/// returned as `yyyy-MM-dd` strings, numbers as [num], booleans as [bool].
Future<Map<String, dynamic>?> showRecordForm(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  Map<String, dynamic>? initial,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 1.0,
      expand: false,
      builder: (ctx2, scrollController) => _RecordForm(
        title: title,
        fields: fields,
        initial: initial ?? {},
        scrollController: scrollController,
      ),
    ),
  );
}

class _RecordForm extends StatefulWidget {
  final String title;
  final List<FieldSpec> fields;
  final Map<String, dynamic> initial;
  final ScrollController scrollController;
  const _RecordForm({
    required this.title,
    required this.fields,
    required this.initial,
    required this.scrollController,
  });

  @override
  State<_RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<_RecordForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _dropdowns = {};
  final Map<String, DateTime?> _dates = {};
  final Map<String, bool> _bools = {};

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      final v = widget.initial[f.key];
      switch (f.type) {
        case FieldType.dropdown:
          final raw = v?.toString();
          _dropdowns[f.key] =
              (f.options != null && f.options!.contains(raw)) ? raw : null;
          break;
        case FieldType.date:
          _dates[f.key] = v == null ? null : DateTime.tryParse(v.toString());
          break;
        case FieldType.boolean:
          _bools[f.key] = v == true;
          break;
        default:
          _controllers[f.key] =
              TextEditingController(text: v == null ? '' : v.toString());
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final out = <String, dynamic>{};
    for (final f in widget.fields) {
      switch (f.type) {
        case FieldType.dropdown:
          out[f.key] = _dropdowns[f.key];
          break;
        case FieldType.date:
          final d = _dates[f.key];
          out[f.key] = d == null ? null : DateFormat('yyyy-MM-dd').format(d);
          break;
        case FieldType.boolean:
          out[f.key] = _bools[f.key] ?? false;
          break;
        case FieldType.number:
          final t = _controllers[f.key]!.text.trim();
          out[f.key] = t.isEmpty ? null : num.tryParse(t);
          break;
        default:
          final t = _controllers[f.key]!.text.trim();
          out[f.key] = t.isEmpty ? null : t;
      }
    }
    Navigator.pop(context, out);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      // Push content above keyboard
      padding: EdgeInsets.only(bottom: bottom),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Title row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
              child: Row(children: [
                Expanded(
                  child: Text(widget.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            const Divider(height: 1),
            // ── Scrollable fields ──────────────────────────────────────
            Expanded(
              child: ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                children: [
                  for (final f in widget.fields) ...[
                    _buildField(f),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
            // ── Sticky Save / Cancel buttons ──────────────────────────
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kBrand),
                    onPressed: _submit,
                    child: const Text('Save'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(FieldSpec f) {
    switch (f.type) {
      case FieldType.dropdown:
        return DropdownButtonFormField<String>(
          initialValue: _dropdowns[f.key],
          isExpanded: true,
          decoration: InputDecoration(labelText: f.label),
          items: (f.options ?? [])
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          validator: (v) =>
              f.required && (v == null || v.isEmpty) ? 'Required' : null,
          onChanged: (v) => setState(() => _dropdowns[f.key] = v),
        );
      case FieldType.date:
        final d = _dates[f.key];
        return InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: d ?? DateTime.now(),
              firstDate: DateTime(2015),
              lastDate: DateTime(2100),
            );
            if (picked != null && mounted) {
              setState(() => _dates[f.key] = picked);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: f.label,
              suffixIcon: d != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () =>
                          setState(() => _dates[f.key] = null),
                    )
                  : const Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(
              d == null ? 'Select date' : DateFormat('dd MMM yyyy').format(d),
              style: TextStyle(
                  color: d == null
                      ? Theme.of(context).hintColor
                      : Theme.of(context).textTheme.bodyLarge?.color),
            ),
          ),
        );
      case FieldType.boolean:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          activeThumbColor: kBrand,
          value: _bools[f.key] ?? false,
          onChanged: (v) => setState(() => _bools[f.key] = v),
        );
      case FieldType.number:
        return TextFormField(
          controller: _controllers[f.key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
          decoration: InputDecoration(labelText: f.label),
          validator: (v) =>
              f.required && (v == null || v.trim().isEmpty) ? 'Required' : null,
        );
      case FieldType.multiline:
        return TextFormField(
          controller: _controllers[f.key],
          maxLines: 3,
          decoration: InputDecoration(labelText: f.label),
          validator: (v) =>
              f.required && (v == null || v.trim().isEmpty) ? 'Required' : null,
        );
      case FieldType.text:
        return TextFormField(
          controller: _controllers[f.key],
          decoration: InputDecoration(labelText: f.label),
          validator: (v) =>
              f.required && (v == null || v.trim().isEmpty) ? 'Required' : null,
        );
    }
  }
}
