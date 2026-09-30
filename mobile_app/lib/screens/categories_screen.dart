import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../state/bootstrap.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/common/design.dart';
import '../utils/contrast.dart';
import '../utils/errors.dart';
import '../utils/mdi.dart';
import '../widgets/common/picker_field.dart';

// ── Preset swatch data ──────────────────────────────────────────────────────

// Hand-spaced around the hue wheel (min ~17° apart) so no two read as the
// same color at a glance — the old Teal/Emerald pair were only ~10° apart.
const _kPresetColors = [
  Color(0xFF6C5CE7), // Calm Iris
  Color(0xFF1F8A3F), // Income Green
  Color(0xFFD9304B), // Expense Rose
  Color(0xFF0984E3), // Sky Blue
  Color(0xFF00B894), // Emerald
  Color(0xFFE17055), // Salmon
  Color(0xFFFDAA00), // Amber
  Color(0xFF6D4C41), // Warm Brown
  Color(0xFF546E7A), // Blue Grey
  Color(0xFF8E44AD), // Purple
  Color(0xFF2D3436), // Charcoal
  Color(0xFF00838F), // Deep Teal (was too close to Emerald)
  Color(0xFFB1BD28), // Citrus
  Color(0xFF7CB342), // Lime
  Color(0xFF304CA6), // Indigo
  Color(0xFFB82EA1), // Magenta
];

String _colorToHex(Color c) =>
    '#${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}'
    '${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}'
    '${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}';

Color _parseColor(String hex, {required Color fallback}) {
  final h = hex.replaceAll('#', '');
  if (h.length != 6) return fallback;
  try {
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return fallback;
  }
}

// ── Icon preset data ────────────────────────────────────────────────────────

// Iconify `mdi:` names — the same set the backend stores. Saved verbatim into
// `category.icon`; rendered via [mdiIconData].
const _kPresetIcons = <String>[
  'mdi:cart',
  'mdi:silverware-fork-knife',
  'mdi:car',
  'mdi:home',
  'mdi:hospital-box',
  'mdi:school',
  'mdi:airplane',
  'mdi:gamepad-variant',
  'mdi:dumbbell',
  'mdi:basket',
  'mdi:coffee',
  'mdi:movie',
  'mdi:paw',
  'mdi:briefcase',
  'mdi:piggy-bank',
  'mdi:cash',
  'mdi:gift',
  'mdi:cellphone',
  'mdi:wifi',
  'mdi:dots-horizontal',
];

// ── Screen ──────────────────────────────────────────────────────────────────

/// Creates or edits a category. A transaction type keeps inline creation
/// compatible with the transaction that opened the editor.
Future<Category?> showCategoryEditor(
  BuildContext context, {
  Category? existing,
  String? transactionType,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    backgroundColor: context.palette.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        _CategoryEditor(existing: existing, transactionType: transactionType),
  );
}

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final async = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add category',
            onPressed: () => _openEditor(context, ref, existing: null),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              userMessage(e),
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.negativeText),
            ),
          ),
        ),
        data: (cats) {
          if (cats.isEmpty) {
            return _EmptyState(
              onAdd: () => _openEditor(context, ref, existing: null),
            );
          }
          final expense = cats.where((c) => c.type == 'expense').toList();
          final income = cats.where((c) => c.type == 'income').toList();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(categoriesProvider);
              await ref.read(categoriesProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              children: [
                if (expense.isNotEmpty)
                  _Section(
                    title: 'Expense (${expense.length})',
                    items: expense,
                    onTap: (c) => _openEditor(context, ref, existing: c),
                    onDelete: (c) => _confirmDeleteCategory(context, ref, c),
                  ),
                if (income.isNotEmpty)
                  _Section(
                    title: 'Income (${income.length})',
                    items: income,
                    onTap: (c) => _openEditor(context, ref, existing: c),
                    onDelete: (c) => _confirmDeleteCategory(context, ref, c),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    required Category? existing,
  }) async {
    await showCategoryEditor(context, existing: existing);
  }
}

// ── Shared delete flow (swipe-to-delete + editor delete button) ─────────────

Future<void> _confirmDeleteCategory(
  BuildContext context,
  WidgetRef ref,
  Category c, {
  VoidCallback? onDeleted,
}) async {
  if (c.profileId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Default categories cannot be deleted')),
    );
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Delete "${c.name}"?'),
      content: const Text(
        'Existing transactions will keep their category link.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Delete',
            style: TextStyle(color: context.palette.negativeText),
          ),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await ref.read(nativeApiProvider).deleteCategory(c.id);
    ref.invalidate(categoriesProvider);
    onDeleted?.call();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userMessage(e))));
    }
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category_outlined, size: 56, color: palette.muted),
            const SizedBox(height: 16),
            Text(
              'No categories yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create your first category to start\norganising your transactions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: palette.muted),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: palette.accentFill,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadii.medium,
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add category'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── List section ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    required this.onTap,
    required this.onDelete,
  });
  final String title;
  final List<Category> items;
  final ValueChanged<Category> onTap;
  final ValueChanged<Category> onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: palette.ink,
            ),
          ),
        ),
        for (final c in items)
          Dismissible(
            key: ValueKey('cat-${c.id}'),
            direction: c.profileId == null
                ? DismissDirection.none
                : DismissDirection.endToStart,
            background: Container(
              color: palette.expenseBg,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Icon(Icons.delete, color: palette.negativeText),
            ),
            confirmDismiss: (_) async {
              onDelete(c);
              return false;
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: c.profileId == null
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Built-in category — can't be edited"),
                      ),
                    )
                  : () => onTap(c),
              child: ListTile(
                leading: _CategoryAvatar(
                  color: c.color,
                  name: c.name,
                  icon: c.icon,
                ),
                title: Text(c.name),
                subtitle: Text(
                  c.profileId == null ? 'Default' : 'Custom',
                  style: TextStyle(color: palette.muted),
                ),
                trailing: c.profileId == null
                    ? null
                    : Icon(Icons.chevron_right, color: palette.muted),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Category avatar (shared between list and editor preview) ─────────────────

class _CategoryAvatar extends StatelessWidget {
  const _CategoryAvatar({
    required this.color,
    required this.name,
    required this.icon,
    this.radius = 20,
  });
  final String color;
  final String name;
  final String icon;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bg = _parseColor(
      color.isNotEmpty ? color : _colorToHex(palette.primary),
      fallback: palette.primary,
    );
    return QuietIcon(
      icon: icon.isNotEmpty ? mdiIconData(icon) : Icons.category_outlined,
      color: bg,
      size: radius * 2,
    );
  }
}

// ── Editor bottom sheet ───────────────────────────────────────────────────────

class _CategoryEditor extends ConsumerStatefulWidget {
  const _CategoryEditor({required this.existing, this.transactionType});
  final Category? existing;
  final String? transactionType;

  @override
  ConsumerState<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<_CategoryEditor> {
  final _nameController = TextEditingController();
  final _customHexController = TextEditingController();
  final _customHexFocus = FocusNode();
  String _type = 'expense';
  String _selectedIcon = '';
  Color _selectedColor = _kPresetColors.first;
  bool _showCustomHex = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _type = widget.transactionType ?? 'expense';
    final e = widget.existing;
    if (e != null) {
      _nameController.text = e.name;
      _type = e.type;
      if (e.icon.isNotEmpty) _selectedIcon = e.icon;
      if (e.color.isNotEmpty) {
        final parsed = _parseColor(e.color, fallback: _kPresetColors.first);
        final isPreset = _kPresetColors.contains(parsed);
        _selectedColor = isPreset ? parsed : _kPresetColors.first;
        if (!isPreset) {
          _showCustomHex = true;
          _customHexController.text = e.color;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customHexController.dispose();
    _customHexFocus.dispose();
    super.dispose();
  }

  String get _resolvedColorHex {
    if (_showCustomHex && _customHexController.text.trim().isNotEmpty) {
      final raw = _customHexController.text.trim();
      return raw.startsWith('#') ? raw : '#$raw';
    }
    return _colorToHex(_selectedColor);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isEdit = widget.existing != null;
    final previewColor = _showCustomHex && _customHexController.text.isNotEmpty
        ? _parseColor(_resolvedColorHex, fallback: palette.primary)
        : _selectedColor;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.divider,
                borderRadius: AppRadii.pill,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title + avatar preview
          Row(
            children: [
              Expanded(
                child: Text(
                  isEdit ? 'Edit category' : 'New category',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: palette.ink,
                  ),
                ),
              ),
              if (isEdit && widget.existing!.profileId != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: palette.negativeText,
                  tooltip: 'Delete category',
                  onPressed: () => _confirmDeleteCategory(
                    context,
                    ref,
                    widget.existing!,
                    onDeleted: () => Navigator.of(context).pop(),
                  ),
                ),
              _CategoryAvatar(
                color: _colorToHex(previewColor),
                name: _nameController.text,
                icon: _selectedIcon,
                radius: 22,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Name
          TextField(
            controller: _nameController,
            textInputAction: _showCustomHex
                ? TextInputAction.next
                : TextInputAction.done,
            onEditingComplete: () {
              if (_showCustomHex) {
                _customHexFocus.requestFocus();
              } else {
                FocusManager.instance.primaryFocus?.unfocus();
              }
            },
            onChanged: (_) => setState(() {}), // update preview initial
            decoration: const InputDecoration(hintText: 'Name'),
          ),
          const SizedBox(height: 12),

          // Type picker
          PickerFormField<String>(
            label: 'Type',
            title: 'Type',
            value: _type,
            placeholder: 'Type',
            enabled: !isEdit && widget.transactionType == null,
            items: const ['expense', 'income'],
            labelBuilder: (v) => v == 'income' ? 'Income' : 'Expense',
            onChanged: (v) => setState(() => _type = v ?? 'expense'),
          ),
          const SizedBox(height: 16),

          // Color label
          Text(
            'Colour',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 8),

          // Color swatch grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _kPresetColors)
                _ColorSwatch(
                  color: preset,
                  selected: !_showCustomHex && _selectedColor == preset,
                  onTap: () => setState(() {
                    _selectedColor = preset;
                    _showCustomHex = false;
                  }),
                ),
              // "Custom" toggle chip
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showCustomHex = !_showCustomHex),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: AnimatedContainer(
                      duration: MediaQuery.of(context).disableAnimations
                          ? AppMotion.reducedFallback
                          : AppMotion.chip,
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _showCustomHex
                            ? palette.accentFill
                            : palette.tile,
                        borderRadius: AppRadii.small,
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: _showCustomHex ? Colors.white : palette.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Optional custom hex field
          if (_showCustomHex) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _customHexController,
              focusNode: _customHexFocus,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '#RRGGBB',
                prefixIcon: Icon(Icons.tag, size: 18),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Icon label
          Text(
            'Icon',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 8),

          // Icon picker grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // "None" option
              _IconChip(
                iconData: Icons.block_outlined,
                selected: _selectedIcon.isEmpty,
                onTap: () => setState(() => _selectedIcon = ''),
              ),
              for (final name in _kPresetIcons)
                _IconChip(
                  iconData: mdiIconData(name),
                  selected: _selectedIcon == name,
                  onTap: () => setState(() => _selectedIcon = name),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: palette.accentFill,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadii.medium,
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isEdit ? 'Save changes' : 'Create category'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    setState(() => _busy = true);
    final color = _resolvedColorHex;
    final api = ref.read(nativeApiProvider);
    try {
      final Category saved;
      if (widget.existing == null) {
        final raw = await api.createCategory({
          'name': name,
          'type': _type,
          if (color.isNotEmpty) 'color': color,
          if (_selectedIcon.isNotEmpty) 'icon': _selectedIcon,
        });
        saved = Category.fromJson(raw);
      } else {
        await api.updateCategory(widget.existing!.id, {
          'name': name,
          if (color.isNotEmpty) 'color': color,
          'icon': _selectedIcon, // "" clears it ("None")
        });
        saved = widget.existing!.copyWith(
          name: name,
          color: color,
          icon: _selectedIcon,
        );
      }
      if (mounted) {
        ref.invalidate(categoriesProvider);
        ref.invalidate(usedCategoriesProvider);
        Navigator.of(context).pop(saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMessage(e))));
        setState(() => _busy = false);
      }
    }
  }
}

// ── Small reusable chips ──────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: AnimatedContainer(
            duration: MediaQuery.of(context).disableAnimations
                ? AppMotion.reducedFallback
                : AppMotion.chip,
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadii.small,
              border: selected
                  ? Border.all(color: palette.ink, width: 2.5)
                  : Border.all(color: Colors.transparent, width: 2.5),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? Icon(Icons.check, size: 16, color: wcagForeground(color))
                : null,
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.iconData,
    required this.selected,
    required this.onTap,
  });
  final IconData iconData;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: AnimatedContainer(
            duration: MediaQuery.of(context).disableAnimations
                ? AppMotion.reducedFallback
                : AppMotion.chip,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: selected ? palette.accentFill : palette.tile,
              borderRadius: AppRadii.small,
            ),
            child: Icon(
              iconData,
              size: 20,
              color: selected ? Colors.white : palette.muted,
            ),
          ),
        ),
      ),
    );
  }
}
