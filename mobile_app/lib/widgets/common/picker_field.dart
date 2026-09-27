import 'package:flutter/material.dart';

import '../../theme.dart';

/// Shows a generic picker bottom sheet that works with any data type.
///
/// Returns the selected item, or `null` if dismissed or the null option was
/// picked. When [nullOptionLabel] is provided, a "null" entry is rendered at
/// the top of the list so callers can express a valid empty selection.
Future<T?> showPickerBottomSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T) labelBuilder,
  T? selectedItem,
  bool Function(T, T)? itemEquals,
  bool showSearch = true,
  String? nullOptionLabel,
  String? createLabel,
  Future<T?> Function()? onCreate,
}) async {
  // End text editing before the sheet takes focus. Otherwise popping the
  // sheet restores the route's last text field and reopens its keyboard.
  FocusManager.instance.primaryFocus?.unfocus();
  var createRequested = false;
  final picked = await showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _PickerSheet<T>(
      title: title,
      items: items,
      labelBuilder: labelBuilder,
      selectedItem: selectedItem,
      itemEquals: itemEquals,
      showSearch: showSearch,
      nullOptionLabel: nullOptionLabel,
      createLabel: createLabel,
      onCreate: onCreate == null
          ? null
          : () {
              createRequested = true;
              Navigator.pop(sheetContext);
            },
    ),
  );
  if (createRequested && context.mounted) return onCreate!();
  return picked;
}

class _PickerSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelBuilder;
  final T? selectedItem;
  final bool Function(T, T)? itemEquals;
  final bool showSearch;
  final String? nullOptionLabel;
  final String? createLabel;
  final VoidCallback? onCreate;

  const _PickerSheet({
    required this.title,
    required this.items,
    required this.labelBuilder,
    this.selectedItem,
    this.itemEquals,
    this.showSearch = true,
    this.nullOptionLabel,
    this.createLabel,
    this.onCreate,
  });

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  late final TextEditingController _searchController;
  late List<T> _filtered;

  bool get _shouldShowSearch => widget.showSearch && widget.items.length > 5;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filtered = widget.items;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isSelected(T item) {
    final selected = widget.selectedItem;
    if (selected == null) {
      return false;
    }
    if (widget.itemEquals != null) {
      return widget.itemEquals!(item, selected);
    }
    return item == selected;
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.items;
      } else {
        final lower = query.toLowerCase();
        _filtered = widget.items
            .where(
              (item) => widget.labelBuilder(item).toLowerCase().contains(lower),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = screenHeight * 0.65;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight, minHeight: 250),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.subtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: palette.ink,
                ),
              ),
            ),
            // Search field
            if (_shouldShowSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: TextStyle(fontSize: 14, color: palette.ink),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    hintStyle: TextStyle(color: palette.muted),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: palette.muted,
                    ),
                    filled: true,
                    fillColor: palette.tile,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: palette.primary, width: 1),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            // Item list
            Flexible(child: _buildList()),
            if (widget.onCreate != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: widget.onCreate,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(widget.createLabel ?? 'Add new'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final palette = context.palette;
    final hasNullOption = widget.nullOptionLabel != null;
    final totalCount = _filtered.length + (hasNullOption ? 1 : 0);

    if (_filtered.isEmpty && !hasNullOption) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No results',
          style: TextStyle(fontSize: 14, color: palette.muted),
        ),
      );
    }

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(8, 0, 8, 16 + bottomPadding),
      itemCount: totalCount,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        // Null option at the top.
        if (hasNullOption && index == 0) {
          return _buildTile(
            palette: palette,
            label: widget.nullOptionLabel!,
            isSelected: widget.selectedItem == null,
            onTap: () => Navigator.pop(context, null),
          );
        }

        final item = _filtered[hasNullOption ? index - 1 : index];
        return _buildTile(
          palette: palette,
          label: widget.labelBuilder(item),
          isSelected: _isSelected(item),
          onTap: () => Navigator.pop(context, item),
        );
      },
    );
  }

  Widget _buildTile({
    required AppColors palette,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: MediaQuery.of(context).disableAnimations
              ? AppMotion.reducedFallback
              : const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? palette.primary.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? palette.primary : palette.ink,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: palette.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A trigger widget that shows the selected value and opens the picker on tap.
///
/// Styled to match moneef text inputs (filled tile, no visible border). Shows
/// a placeholder when nothing is selected, with a down chevron. When [enabled]
/// is false the field is muted and non-tappable.
class PickerField extends StatelessWidget {
  final String? selectedLabel;
  final String placeholder;
  final VoidCallback onTap;
  final bool enabled;

  const PickerField({
    required this.placeholder,
    required this.onTap,
    this.selectedLabel,
    this.enabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasSelection = selectedLabel != null;

    final Color textColor;
    if (!enabled) {
      textColor = palette.muted;
    } else if (hasSelection) {
      textColor = palette.ink;
    } else {
      textColor = palette.muted;
    }

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: MediaQuery.of(context).disableAnimations
            ? AppMotion.reducedFallback
            : AppMotion.chip,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: palette.card,
          border: Border.all(color: palette.divider),
          borderRadius: AppRadii.medium,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasSelection ? selectedLabel! : placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: hasSelection ? FontWeight.w600 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: enabled ? palette.muted : palette.subtle,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

/// A [FormField] wrapper around [PickerField] that adds an optional label
/// above the field and an inline error message below when validation fails.
///
/// Opens [showPickerBottomSheet] on tap and forwards the picked value to both
/// [onChanged] and the form field's own state. When [nullOptionLabel] is set,
/// a null result counts as a valid selection (e.g. an "All" option).
class PickerFormField<T> extends FormField<T> {
  PickerFormField({
    required T? value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required void Function(T?) onChanged,
    required String placeholder,
    required String title,
    super.key,
    String? label,
    super.validator,
    bool Function(T, T)? itemEquals,
    bool showSearch = true,
    String? nullOptionLabel,
    String? createLabel,
    Future<T?> Function()? onCreate,
    super.enabled,
  }) : super(
         initialValue: value,
         builder: (FormFieldState<T> state) {
           final palette = state.context.palette;
           final current = state.value;
           final selectedLabel = current == null ? null : labelBuilder(current);

           Future<void> openSheet() async {
             final picked = await showPickerBottomSheet<T>(
               context: state.context,
               title: title,
               items: items,
               labelBuilder: labelBuilder,
               selectedItem: state.value,
               itemEquals: itemEquals,
               showSearch: showSearch,
               nullOptionLabel: nullOptionLabel,
               createLabel: createLabel,
               onCreate: onCreate,
             );
             if (!state.mounted) return;
             // A null result is only meaningful when a null option exists;
             // otherwise treat null as a dismissal and keep the value.
             if (picked != null || nullOptionLabel != null) {
               onChanged(picked);
               state.didChange(picked);
             }
           }

           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             mainAxisSize: MainAxisSize.min,
             children: [
               if (label != null) ...[
                 Text(
                   label,
                   style: TextStyle(
                     fontSize: 13,
                     fontWeight: FontWeight.w600,
                     color: palette.ink,
                   ),
                 ),
                 const SizedBox(height: 8),
               ],
               PickerField(
                 selectedLabel: selectedLabel,
                 placeholder: placeholder,
                 enabled: enabled,
                 onTap: openSheet,
               ),
               if (state.hasError) ...[
                 const SizedBox(height: 6),
                 Text(
                   state.errorText!,
                   style: TextStyle(
                     fontSize: 11,
                     height: 1,
                     color: Theme.of(state.context).colorScheme.error,
                   ),
                 ),
               ],
             ],
           );
         },
       );

  @override
  FormFieldState<T> createState() => _PickerFormFieldState<T>();
}

class _PickerFormFieldState<T> extends FormFieldState<T> {
  @override
  void didUpdateWidget(covariant PickerFormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Options can arrive after a transaction has loaded. Keep an externally
    // supplied selection in sync without treating hydration as a user edit.
    if (widget.initialValue != oldWidget.initialValue) {
      setValue(widget.initialValue);
    }
  }
}
