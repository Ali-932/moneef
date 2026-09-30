import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';
import '../models/category.dart';
import '../models/currency.dart';
import '../state/providers.dart';
import '../state/transactions_controller.dart';
import '../theme.dart';
import '../utils/amount_input.dart';
import '../widgets/common/design.dart';
import '../widgets/common/date_picker_style.dart';
import '../widgets/common/discard_changes_dialog.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/common/labeled_switch_row.dart';
import '../widgets/common/picker_field.dart';
import 'categories_screen.dart';

const _lastAccountKey = 'last_account_id';

/// Full-screen create/edit form. When [initialId] is non-null the form
/// loads the existing transaction (via `transactionByIdProvider`) and
/// submits via `update` instead of `create`.
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.initialId,
    this.initialRecurring = false,
  });

  final int? initialId;
  final bool initialRecurring;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _CategoryRowState {
  _CategoryRowState({this.categoryId, required this.amountController});

  int? categoryId;
  final TextEditingController amountController;
  final amountFocus = FocusNode();

  void dispose() {
    amountController.dispose();
    amountFocus.dispose();
  }
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _merchantController = TextEditingController();
  final _notesController = TextEditingController();
  final _merchantFocus = FocusNode();
  final _notesFocus = FocusNode();
  final _recurrentPaidFocus = FocusNode();
  final List<_CategoryRowState> _categoryRows = [];

  String _type = 'expense';
  String _currencyCode = 'USD';
  int? _accountId;
  DateTime _date = DateTime.now();
  bool _isRecurrent = false;
  RecurrenceFrequency _recurrentFreq = RecurrenceFrequency.monthly;
  bool _recurrentHasEndDate = false;
  DateTime? _recurrentEndDate;
  final _recurrentTotalController = TextEditingController();
  final _recurrentPaidController = TextEditingController(text: '0');
  bool _busy = false;
  bool _hydrated = false;

  // Unsaved-changes guard
  bool _isDirty = false;

  // Per-form inline error messages so they surface near the right field
  String? _duplicateCategoryError;
  String? _endDateError;
  String? _paidVsTotalError;

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  @override
  void initState() {
    super.initState();
    _isRecurrent = widget.initialId == null && widget.initialRecurring;
    _categoryRows.add(
      _CategoryRowState(amountController: TextEditingController()),
    );
    if (widget.initialId == null) {
      SharedPreferences.getInstance().then((prefs) {
        final last = prefs.getInt(_lastAccountKey);
        if (mounted && _accountId == null) {
          setState(() => _accountId = last);
        }
      }).ignore(); // no stored choice: the first account applies
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    _merchantFocus.dispose();
    _notesFocus.dispose();
    _recurrentPaidFocus.dispose();
    _recurrentTotalController.dispose();
    _recurrentPaidController.dispose();
    for (final row in _categoryRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _resetCategoryRows() {
    for (final row in _categoryRows) {
      row.dispose();
    }
    _categoryRows.clear();
    _categoryRows.add(
      _CategoryRowState(amountController: TextEditingController()),
    );
  }

  void _setCategoryRowsFromAmounts(List<MapEntry<int?, String>> rows) {
    for (final row in _categoryRows) {
      row.dispose();
    }
    _categoryRows.clear();
    for (final entry in rows) {
      _categoryRows.add(
        _CategoryRowState(
          categoryId: entry.key,
          amountController: TextEditingController(
            text: formatAmountInput(entry.value),
          ),
        ),
      );
    }
  }

  Decimal get _runningTotal {
    var total = Decimal.zero;
    for (final row in _categoryRows) {
      final amount = parseAmountInput(row.amountController.text);
      if (amount != null) total += amount;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initialId == null && !_hydrated) {
      // New transactions start in the default currency from settings. Wait out
      // a refresh so a just-changed default doesn't hydrate from the old value.
      final settings = ref.watch(settingsProvider);
      if (settings.hasValue && !settings.isLoading) {
        if (!_isDirty) _currencyCode = settings.requireValue.currencyCode;
        _hydrated = true;
      }
    }
    if (widget.initialId != null && !_hydrated) {
      final async = ref.watch(transactionByIdProvider(widget.initialId!));
      return async.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: Center(child: Text(userMessage(e))),
        ),
        data: (t) {
          _nameController.text = t.name;
          _merchantController.text = t.merchantName;
          _notesController.text = t.notes;
          _type = t.type;
          _currencyCode = t.currencyCode;
          _accountId = t.accountId;
          _date = t.date;
          _setCategoryRowsFromAmounts(
            t.categories
                .map((c) => MapEntry(c.categoryId, c.amount.toString()))
                .toList(),
          );
          _hydrated = true;
          return _buildForm(context);
        },
      );
    }
    return _buildForm(context);
  }

  /// The account this transaction goes to; null while there is only one.
  Account? _selectedAccount(List<Account> accounts) {
    if (accounts.length < 2) return null;
    return accounts.where((a) => a.id == _accountId).firstOrNull ??
        accounts.first;
  }

  Future<void> _pickAccount(List<Account> accounts) async {
    final picked = await showPickerBottomSheet<Account>(
      context: context,
      title: 'Account',
      items: accounts,
      labelBuilder: (a) => a.name,
      selectedItem: _selectedAccount(accounts),
      itemEquals: (a, b) => a.id == b.id,
      showSearch: false,
    );
    if (picked != null && picked.id != _accountId) {
      setState(() => _accountId = picked.id);
      _markDirty();
    }
  }

  Widget _buildForm(BuildContext context) {
    final palette = context.palette;
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final selectedAccount = _selectedAccount(accounts);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.maybeWhen(
      data: (d) => d.where((c) => c.type == _type).toList(),
      orElse: () => const <Category>[],
    );

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final ok = await _confirmDiscard();
        if (ok == true && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.initialId == null ? 'Add transaction' : 'Edit transaction',
          ),
          actions: [
            if (widget.initialId != null)
              IconButton(
                icon: Icon(Icons.delete_outline, color: palette.negativeText),
                onPressed: _busy ? null : _confirmDelete,
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _TypeToggle(
                value: _type,
                onChanged: (v) {
                  setState(() {
                    _type = v;
                    _resetCategoryRows();
                  });
                  _markDirty();
                },
              ),
              const SizedBox(height: 16),
              _RunningTotal(total: _runningTotal, currencyCode: _currencyCode),
              const SizedBox(height: 24),
              const _FieldLabel('Name'),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                onEditingComplete: () =>
                    _categoryRows.first.amountFocus.requestFocus(),
                onChanged: (_) => _markDirty(),
                decoration: const InputDecoration(
                  hintText: 'e.g. Morning latte',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Date'),
                        _DateField(
                          date: _date,
                          onChanged: (d) {
                            setState(() => _date = d);
                            _markDirty();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Currency'),
                        _CurrencyChip(
                          code: _currencyCode,
                          onTap: _pickCurrency,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (selectedAccount != null) ...[
                const SizedBox(height: 16),
                const _FieldLabel('Account'),
                PickerField(
                  placeholder: 'Select account',
                  selectedLabel: selectedAccount.name,
                  onTap: () => _pickAccount(accounts),
                ),
              ],
              const SizedBox(height: 24),
              const _FieldLabel('Split by category'),
              ..._categoryRows.asMap().entries.map((entry) {
                final i = entry.key;
                final row = entry.value;
                return Padding(
                  // Keep field state and validation with their category split
                  // when another row is removed.
                  key: ObjectKey(row),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CategoryRowField(
                    transactionType: _type,
                    categories: categories,
                    selectedId: row.categoryId,
                    amountController: row.amountController,
                    amountFocus: row.amountFocus,
                    onNext: () {
                      if (i + 1 < _categoryRows.length) {
                        _categoryRows[i + 1].amountFocus.requestFocus();
                      } else {
                        _merchantFocus.requestFocus();
                      }
                    },
                    onAmountChanged: (_) => setState(() => _isDirty = true),
                    onCategoryChanged: (id) {
                      setState(() {
                        row.categoryId = id;
                        _duplicateCategoryError = null;
                      });
                      _markDirty();
                    },
                    onRemoved: _categoryRows.length > 1
                        ? () => setState(() {
                            row.dispose();
                            _categoryRows.removeAt(i);
                            _isDirty = true;
                            _duplicateCategoryError = null;
                          })
                        : null,
                  ),
                );
              }),
              // Inline duplicate-category error
              if (_duplicateCategoryError != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    _duplicateCategoryError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              _AddCategoryButton(
                onTap: () {
                  setState(() {
                    _categoryRows.add(
                      _CategoryRowState(
                        amountController: TextEditingController(),
                      ),
                    );
                  });
                  _markDirty();
                },
              ),
              const SizedBox(height: 16),
              const _FieldLabel('Merchant (optional)'),
              TextFormField(
                controller: _merchantController,
                focusNode: _merchantFocus,
                textInputAction: TextInputAction.next,
                onEditingComplete: _notesFocus.requestFocus,
                onChanged: (_) => _markDirty(),
                decoration: const InputDecoration(hintText: 'e.g. Blue Bottle'),
              ),
              const SizedBox(height: 16),
              const _FieldLabel('Notes (optional)'),
              TextFormField(
                controller: _notesController,
                focusNode: _notesFocus,
                onChanged: (_) => _markDirty(),
                decoration: const InputDecoration(hintText: 'e.g. Team lunch'),
                maxLines: 3,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),
              if (widget.initialId == null) ...[
                const SizedBox(height: 16),
                _RecurrenceSection(
                  txDate: _date,
                  isRecurrent: _isRecurrent,
                  onRecurrentChanged: (v) {
                    setState(() => _isRecurrent = v);
                    _markDirty();
                  },
                  frequency: _recurrentFreq,
                  onFrequencyChanged: (v) {
                    setState(
                      () => _recurrentFreq = v ?? RecurrenceFrequency.monthly,
                    );
                    _markDirty();
                  },
                  hasEndDate: _recurrentHasEndDate,
                  onHasEndDateChanged: (v) {
                    setState(() {
                      _recurrentHasEndDate = v;
                      if (v) {
                        _recurrentEndDate = _recurrentEndDate ?? DateTime.now();
                      }
                      _endDateError = null;
                      _paidVsTotalError = null;
                    });
                    _markDirty();
                  },
                  endDate: _recurrentEndDate,
                  onEndDateChanged: (d) {
                    setState(() {
                      _recurrentEndDate = d;
                      _endDateError = null;
                    });
                    _markDirty();
                  },
                  totalController: _recurrentTotalController,
                  paidController: _recurrentPaidController,
                  paidFocus: _recurrentPaidFocus,
                  endDateError: _endDateError,
                  paidVsTotalError: _paidVsTotalError,
                  onAnyChanged: _markDirty,
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: palette.accentFill,
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                  : Text(
                      widget.initialId == null
                          ? 'Add transaction'
                          : 'Save changes',
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDiscard() => showDiscardChangesDialog(context);

  Future<void> _pickCurrency() async {
    List<Currency> currencies;
    try {
      currencies = await ref.read(availableCurrenciesProvider.future);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMessage(e))));
      }
      return;
    }

    if (currencies.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a currency in Settings first')),
        );
      }
      return;
    }

    await _showCurrencySheet(currencies);
  }

  Future<void> _showCurrencySheet(List<Currency> currencies) async {
    final result = await showPickerBottomSheet<String>(
      context: context,
      title: 'Currency',
      items: [for (final c in currencies) c.code],
      labelBuilder: (code) {
        final c = currencies.firstWhere((c) => c.code == code);
        return '${c.code} ${c.symbol.isNotEmpty ? '(${c.symbol})' : ''}';
      },
      selectedItem: _currencyCode,
    );
    if (result != null) {
      setState(() => _currencyCode = result);
      _markDirty();
    }
  }

  Future<void> _submit() async {
    // Clear cross-field errors before revalidating
    setState(() {
      _duplicateCategoryError = null;
      _endDateError = null;
      _paidVsTotalError = null;
    });

    // Per-field inline validation
    if (!_formKey.currentState!.validate()) return;

    // Build draft categories — per-row validators already caught amount/category
    final draftCategories = <TransactionDraftCategory>[];
    for (final row in _categoryRows) {
      draftCategories.add(
        TransactionDraftCategory(
          categoryId: row.categoryId!,
          amount: parseAmountInput(row.amountController.text)!,
        ),
      );
    }

    // Duplicate-category cross-field check (inline, not SnackBar)
    final seen = <int>{};
    bool hasDuplicate = false;
    for (final c in draftCategories) {
      if (!seen.add(c.categoryId)) {
        hasDuplicate = true;
        break;
      }
    }
    if (hasDuplicate) {
      setState(
        () => _duplicateCategoryError = 'Each category can only appear once',
      );
      return;
    }

    // Recurrence cross-field checks (inline near their fields)
    if (_isRecurrent && _recurrentHasEndDate) {
      final endDate = _recurrentEndDate;
      if (endDate != null && !endDate.isAfter(_date)) {
        setState(
          () => _endDateError = 'End date must be after the transaction date',
        );
        return;
      }
      final total = parseAmountInput(_recurrentTotalController.text);
      final paid = parseAmountInput(_recurrentPaidController.text);
      if (paid != null && total != null && paid > total) {
        setState(
          () =>
              _paidVsTotalError = 'Amount already paid cannot exceed the total',
        );
        return;
      }
    }

    final draft = TransactionDraft(
      name: _nameController.text.trim(),
      type: _type,
      currencyCode: _currencyCode,
      date: _date,
      categories: draftCategories,
      merchantName: _merchantController.text.trim(),
      notes: _notesController.text.trim(),
      isRecurrent: widget.initialId == null && _isRecurrent,
      recurrentFreq: _recurrentFreq,
      recurrentHasEndDate: _recurrentHasEndDate,
      recurrentEndDate: _recurrentEndDate,
      recurrentTotalAmount: parseAmountInput(_recurrentTotalController.text),
      recurrentPaidPreviously: parseAmountInput(_recurrentPaidController.text),
      accountId: _selectedAccount(
        ref.read(accountsProvider).valueOrNull ?? const [],
      )?.id,
    );

    final validationError = draft.validate();
    if (validationError != null) {
      // Surface leftover backend-side validations as SnackBar (last resort)
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(validationError)));
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final ctrl = ref.read(transactionsMutationProvider);
      if (widget.initialId == null) {
        await ctrl.create(draft);
        if (draft.accountId case final id?) {
          SharedPreferences.getInstance()
              .then((prefs) => prefs.setInt(_lastAccountKey, id))
              .ignore();
        }
      } else {
        await ctrl.update(widget.initialId!, draft);
      }
      if (mounted) {
        setState(() => _isDirty = false);
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final palette = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: palette.negativeText),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(transactionsMutationProvider).delete(widget.initialId!);
      if (mounted) {
        setState(() => _isDirty = false);
        context.pop(true);
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 0, 6),
      child: Text(
        text,
        style: TextStyle(
          color: palette.muted,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: 'Transaction type',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: palette.tile,
          borderRadius: AppRadii.medium,
        ),
        child: Row(
          children: [
            _half(
              context,
              'Expense',
              Icons.south,
              value == 'expense',
              () => onChanged('expense'),
            ),
            _half(
              context,
              'Income',
              Icons.north,
              value == 'income',
              () => onChanged('income'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _half(
    BuildContext context,
    String label,
    IconData icon,
    bool on,
    VoidCallback onTap,
  ) {
    final palette = context.palette;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    return Expanded(
      child: Semantics(
        label: label,
        selected: on,
        button: true,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: reducedMotion
                ? AppMotion.reducedFallback
                : AppMotion.chip,
            curve: AppMotion.emphasized,
            decoration: BoxDecoration(
              color: on ? palette.card : Colors.transparent,
              borderRadius: AppRadii.medium,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: on ? palette.primary : palette.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: on ? palette.primary : palette.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({required this.code, required this.onTap});
  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: 'Currency: $code. Tap to change.',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: palette.card,
            border: Border.all(color: palette.divider),
            borderRadius: AppRadii.medium,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Text(
                code,
                style: TextStyle(
                  color: palette.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, size: 18, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunningTotal extends StatelessWidget {
  const _RunningTotal({required this.total, required this.currencyCode});
  final Decimal total;
  final String currencyCode;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      children: [
        Text(
          'Total amount',
          style: TextStyle(color: context.palette.muted, fontSize: 12),
        ),
        const SizedBox(height: 5),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppMotion.chip,
          child: MoneyText(
            formatMoney(total, currencyCode),
            key: ValueKey(total),
            size: 36,
            weight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Calculated from your category amounts',
          style: TextStyle(color: context.palette.muted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _CategoryRowField extends StatelessWidget {
  const _CategoryRowField({
    required this.transactionType,
    required this.categories,
    required this.selectedId,
    required this.amountController,
    required this.amountFocus,
    required this.onNext,
    required this.onAmountChanged,
    required this.onCategoryChanged,
    this.onRemoved,
  });

  final List<Category> categories;
  final String transactionType;
  final int? selectedId;
  final TextEditingController amountController;
  final FocusNode amountFocus;
  final VoidCallback onNext;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<int?> onCategoryChanged;
  final VoidCallback? onRemoved;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: PickerFormField<Category>(
            label: 'Category',
            title: 'Category',
            value: categories.where((c) => c.id == selectedId).firstOrNull,
            placeholder: 'Select category',
            items: categories,
            labelBuilder: (category) => category.name,
            itemEquals: (a, b) => a.id == b.id,
            validator: (v) => v == null ? 'Required' : null,
            onChanged: (category) => onCategoryChanged(category?.id),
            createLabel: 'Add new category',
            onCreate: () =>
                showCategoryEditor(context, transactionType: transactionType),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FieldLabel('Amount'),
              TextFormField(
                controller: amountController,
                focusNode: amountFocus,
                textInputAction: TextInputAction.next,
                onEditingComplete: onNext,
                inputFormatters: const [AmountInputFormatter()],
                onChanged: onAmountChanged,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  errorStyle: TextStyle(fontSize: 11, height: 1),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final amount = parseAmountInput(v);
                  if (amount == null || amount <= Decimal.zero) {
                    return 'Enter an amount greater than 0';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        if (onRemoved != null)
          IconButton(
            icon: Icon(Icons.close, color: context.palette.muted),
            onPressed: onRemoved,
          ),
      ],
    );
  }
}

class _AddCategoryButton extends StatelessWidget {
  const _AddCategoryButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: 'Add category split',
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: palette.tile,
            borderRadius: AppRadii.medium,
            border: Border.all(
              color: palette.divider,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 18, color: palette.primary),
              const SizedBox(width: 6),
              Text(
                'Add category split',
                style: TextStyle(
                  color: palette.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurrenceSection extends StatelessWidget {
  const _RecurrenceSection({
    required this.txDate,
    required this.isRecurrent,
    required this.onRecurrentChanged,
    required this.frequency,
    required this.onFrequencyChanged,
    required this.hasEndDate,
    required this.onHasEndDateChanged,
    required this.endDate,
    required this.onEndDateChanged,
    required this.totalController,
    required this.paidController,
    required this.paidFocus,
    required this.endDateError,
    required this.paidVsTotalError,
    required this.onAnyChanged,
  });

  final DateTime txDate;
  final bool isRecurrent;
  final ValueChanged<bool> onRecurrentChanged;
  final RecurrenceFrequency frequency;
  final ValueChanged<RecurrenceFrequency?> onFrequencyChanged;
  final bool hasEndDate;
  final ValueChanged<bool> onHasEndDateChanged;
  final DateTime? endDate;
  final ValueChanged<DateTime?> onEndDateChanged;
  final TextEditingController totalController;
  final TextEditingController paidController;
  final FocusNode paidFocus;
  final String? endDateError;
  final String? paidVsTotalError;
  final VoidCallback onAnyChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: AppRadii.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabeledSwitchRow(
            label: 'Recurring payment',
            labelStyle: TextStyle(
              color: palette.ink,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            value: isRecurrent,
            onChanged: onRecurrentChanged,
            activeThumbColor: palette.primary,
          ),
          if (isRecurrent) ...[
            const SizedBox(height: 4),
            Text(
              'Set how often this transaction repeats.',
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            PickerFormField<RecurrenceFrequency>(
              label: 'Frequency',
              title: 'Frequency',
              value: frequency,
              placeholder: 'Frequency',
              items: const [
                RecurrenceFrequency.weekly,
                RecurrenceFrequency.biWeekly,
                RecurrenceFrequency.monthly,
                RecurrenceFrequency.yearly,
              ],
              labelBuilder: (f) => switch (f) {
                RecurrenceFrequency.weekly => 'Weekly',
                RecurrenceFrequency.biWeekly => 'Bi-weekly',
                RecurrenceFrequency.monthly => 'Monthly',
                RecurrenceFrequency.yearly => 'Yearly',
              },
              onChanged: onFrequencyChanged,
            ),
            const SizedBox(height: 16),
            // ── End-date block ──────────────────────────────────────────────
            Text(
              'Plan end date',
              style: TextStyle(
                color: palette.ink,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Optional. If this payment has a fixed end, set it here.',
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            LabeledSwitchRow(
              label: 'Has end date?',
              labelStyle: TextStyle(
                color: palette.ink,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              value: hasEndDate,
              onChanged: onHasEndDateChanged,
              activeThumbColor: palette.primary,
            ),
            if (hasEndDate) ...[
              const SizedBox(height: 8),
              Semantics(
                label: 'End date',
                child: _DateField(
                  // ponytail: defensive fallback only — onHasEndDateChanged
                  // always sets a real endDate the moment this switch flips.
                  date: endDate ?? DateTime.now(),
                  title: 'Plan end date',
                  onChanged: onEndDateChanged,
                ),
              ),
              if (endDateError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    endDateError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: totalController,
                textInputAction: TextInputAction.next,
                onEditingComplete: paidFocus.requestFocus,
                inputFormatters: const [AmountInputFormatter()],
                onChanged: (_) => onAnyChanged(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Total plan amount',
                  hintText: '0.00',
                ),
                validator: (v) {
                  if (!isRecurrent || !hasEndDate) return null;
                  final amount = parseAmountInput(v ?? '');
                  if (amount == null || amount <= Decimal.zero) {
                    return 'Enter a total greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: paidController,
                focusNode: paidFocus,
                textInputAction: TextInputAction.done,
                inputFormatters: const [AmountInputFormatter()],
                onChanged: (_) => onAnyChanged(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount already paid',
                  hintText: '0.00',
                ),
                validator: (v) {
                  if (!isRecurrent || !hasEndDate) return null;
                  final amount = parseAmountInput(v ?? '');
                  if (amount == null || amount < Decimal.zero) {
                    return 'Enter 0 or more';
                  }
                  return null;
                },
              ),
              if (paidVsTotalError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    paidVsTotalError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.date,
    required this.onChanged,
    this.title = 'Transaction date',
  });
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = formatDateLong(date);
    return GestureDetector(
      onTap: () async {
        FocusManager.instance.primaryFocus?.unfocus();
        final picked = await showDatePicker(
          context: context,
          builder: buildAppDatePicker,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(DateTime.now().year + 2),
          helpText: title,
          confirmText: 'Use date',
          switchToInputEntryModeIcon: const Icon(Icons.edit_calendar_outlined),
          switchToCalendarEntryModeIcon: const Icon(
            Icons.calendar_month_outlined,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: palette.card,
          border: Border.all(color: palette.divider),
          borderRadius: AppRadii.medium,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: palette.muted),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: palette.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
