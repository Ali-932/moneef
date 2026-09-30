import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/account.dart';
import '../models/currency.dart';
import '../models/transaction.dart';
import '../state/bootstrap.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../utils/amount_input.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/common/design.dart';
import '../widgets/common/picker_field.dart';
import '../widgets/common/skeletons.dart';
import '../widgets/common/staggered_animated_item.dart';
import '../widgets/transaction_row.dart';

/// Bridge refusals ("this account still has activity") arrive as
/// PlatformException; show their message, not the wrapper.
String _message(Object e) =>
    userMessage(e is PlatformException ? (e.message ?? e) : e);

void _refreshAccounts(WidgetRef ref) {
  ref.invalidate(accountsProvider);
  ref.invalidate(accountActivityProvider);
}

void _showError(BuildContext context, Object e) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(_message(e))));
}

/// Rose "Delete" confirmation, like the other delete dialogs in the app.
Future<bool> _confirmDelete(
  BuildContext context,
  String title,
  String message,
) async {
  final negativeText = context.palette.negativeText;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('Delete', style: TextStyle(color: negativeText)),
        ),
      ],
    ),
  );
  return ok == true;
}

String _balancesLine(Account a) =>
    a.balances.map((b) => formatMoney(b.amount, b.currency)).join(' · ');

/// One currency in the default currency needs no approximation or breakdown.
bool _isSimple(Account a, String base) =>
    a.balances.isEmpty ||
    (a.balances.length == 1 && a.balances.first.currency == base);

/// The account's headline figure, in the default currency when possible.
String _headline(Account a, String base) {
  if (base.isEmpty) return _balancesLine(a);
  if (a.balances.isEmpty) return formatMoney(Decimal.zero, base);
  if (_isSimple(a, base)) return formatMoney(a.balances.first.amount, base);
  final approx = a.approxTotal;
  return approx == null ? _balancesLine(a) : '≈ ${formatMoney(approx, base)}';
}

// ── accounts list ───────────────────────────────────────────────────

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  Future<void> _addAccount(BuildContext context, WidgetRef ref) async {
    final name = await _askName(
      context,
      title: 'Add account',
      action: 'Add account',
    );
    if (name == null) return;
    try {
      await ref.read(nativeApiProvider).createAccount(name);
      _refreshAccounts(ref);
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final base = ref.watch(settingsProvider).valueOrNull?.currencyCode ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            tooltip: 'Add account',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _addAccount(context, ref),
          ),
        ],
      ),
      body: ref
          .watch(accountsProvider)
          .when(
            loading: () => const RecurrencesSkeleton(itemCount: 2),
            error: (e, _) => _ErrorText(e),
            data: (accounts) => RefreshIndicator(
              onRefresh: () async => _refreshAccounts(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  for (var i = 0; i < accounts.length; i++)
                    StaggeredAnimatedItem(
                      key: ValueKey(accounts[i].id),
                      index: i,
                      shouldStagger: true,
                      child: _AccountCard(account: accounts[i], base: base),
                    ),
                  if (accounts.length < 2)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: Text(
                        'Add accounts for cash, bank or savings. Moving money '
                        'between them never counts as spending.',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.base});
  final Account account;
  final String base;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final breakdown = !_isSimple(account, base) && account.approxTotal != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: palette.card,
        borderRadius: AppRadii.large,
        child: InkWell(
          borderRadius: AppRadii.large,
          onTap: () => context.push('/profile/accounts/${account.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      MoneyText(_headline(account, base), size: 20),
                      if (breakdown) ...[
                        const SizedBox(height: 4),
                        Text(
                          _balancesLine(account),
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 12,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: palette.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── account page ────────────────────────────────────────────────────

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key, required this.id});
  final int id;

  Future<void> _rename(BuildContext context, WidgetRef ref, Account a) async {
    final name = await _askName(
      context,
      title: 'Rename account',
      action: 'Save',
      initial: a.name,
    );
    if (name == null || name == a.name) return;
    try {
      await ref.read(nativeApiProvider).updateAccount(a.id, name);
      _refreshAccounts(ref);
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Account a) async {
    if (!await _confirmDelete(
      context,
      'Delete "${a.name}"?',
      'Only an account without activity can be deleted.',
    )) {
      return;
    }
    try {
      await ref.read(nativeApiProvider).deleteAccount(a.id);
      HapticFeedback.mediumImpact();
      _refreshAccounts(ref);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final accounts = ref.watch(accountsProvider);
    final account = accounts.valueOrNull?.where((a) => a.id == id).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          account?.name ?? 'Account',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (account != null)
            PopupMenuButton<String>(
              tooltip: 'Account actions',
              icon: Icon(Icons.more_horiz_rounded, color: palette.muted),
              onSelected: (action) => switch (action) {
                'exchange' => _openSheet(
                  context,
                  _ExchangeSheet(account: account),
                ),
                'rename' => _rename(context, ref, account),
                _ => _delete(context, ref, account),
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'exchange',
                  child: ListTile(
                    leading: Icon(Icons.currency_exchange_rounded),
                    title: Text('Exchange currency'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'rename',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Rename account'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: palette.negativeText,
                    ),
                    title: Text(
                      'Delete account',
                      style: TextStyle(color: palette.negativeText),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: accounts.when(
        loading: () => const TransactionListSkeleton(itemCount: 4),
        error: (e, _) => _ErrorText(e),
        data: (all) => account == null
            ? const _ErrorText('This account no longer exists.')
            : _AccountBody(account: account, accounts: all),
      ),
    );
  }
}

class _AccountBody extends ConsumerWidget {
  const _AccountBody({required this.account, required this.accounts});
  final Account account;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final base = ref.watch(settingsProvider).valueOrNull?.currencyCode ?? '';
    final activity = ref.watch(accountActivityProvider(account.id));
    final names = {
      for (final c in ref.watch(currenciesProvider).valueOrNull ?? const [])
        c.code: c.name,
    };
    return RefreshIndicator(
      onRefresh: () async => _refreshAccounts(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: AppRadii.large,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balance',
                  style: TextStyle(color: palette.muted, fontSize: 13),
                ),
                const SizedBox(height: 6),
                MoneyText(
                  _headline(account, base),
                  size: 30,
                  weight: FontWeight.w800,
                ),
                if (!_isSimple(account, base)) ...[
                  const SizedBox(height: 12),
                  for (final b in account.balances)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              names[b.currency] ?? b.currency,
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          MoneyText(
                            formatMoney(b.amount, b.currency),
                            size: 14,
                            weight: FontWeight.w600,
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openSheet(
                            context,
                            _TransferSheet(
                              account: account,
                              accounts: accounts,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.accentFill,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadii.medium,
                            ),
                          ),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const Text('Transfer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openSheet(
                            context,
                            _SetBalanceSheet(account: account),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.ink,
                            side: BorderSide(color: palette.divider),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadii.medium,
                            ),
                          ),
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: const Text('Set balance'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent activity',
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(transactionFilterProvider.notifier).state =
                      TransactionFilter(accountId: account.id);
                  context.go('/transactions');
                },
                child: Text(
                  'See all',
                  style: TextStyle(fontSize: 12, color: palette.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          activity.when(
            loading: () => const TransactionListSkeleton(itemCount: 3),
            error: (e, _) => _ErrorText(e),
            data: (items) => _ActivityCard(
              items: items,
              account: account,
              accounts: accounts,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.items,
    required this.account,
    required this.accounts,
  });
  final List<Object> items;
  final Account account;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: items.isEmpty ? const EdgeInsets.all(20) : null,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: AppRadii.large,
      ),
      child: items.isEmpty
          ? Text(
              'Transactions and transfers for this account show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.muted, fontSize: 13),
            )
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  StaggeredAnimatedItem(
                    key: ValueKey(items[i]),
                    index: i,
                    shouldStagger: true,
                    child: switch (items[i]) {
                      final Transaction t => TransactionRow(
                        transaction: t,
                        showDate: true,
                        onTap: () => context.push('/transactions/${t.id}'),
                      ),
                      final Transfer t => _TransferRow(
                        transfer: t,
                        accountId: account.id,
                        accounts: accounts,
                      ),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                  if (i < items.length - 1)
                    const Divider(height: 1, indent: 68),
                ],
              ],
            ),
    );
  }
}

class _TransferRow extends ConsumerWidget {
  const _TransferRow({
    required this.transfer,
    required this.accountId,
    required this.accounts,
  });
  final Transfer transfer;
  final int accountId;
  final List<Account> accounts;

  String _nameOf(int? id) =>
      accounts.where((a) => a.id == id).firstOrNull?.name ?? 'another account';

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await _confirmDelete(
      context,
      transfer.isCorrection ? 'Delete balance correction?' : 'Delete transfer?',
      'Balances go back to what they were before it.',
    )) {
      return;
    }
    try {
      await ref.read(nativeApiProvider).deleteTransfer(transfer.id);
      HapticFeedback.mediumImpact();
      _refreshAccounts(ref);
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = transfer;
    final large =
        MediaQuery.textScalerOf(context).scale(1) >= 1.3 ||
        MediaQuery.sizeOf(context).width < 360;
    final sent = t.fromAmount == null
        ? ''
        : formatMoney(t.fromAmount!, t.fromCurrency);
    final received = formatMoney(t.toAmount, t.toCurrency);
    final exchanged = t.fromCurrency != t.toCurrency;
    // What this account gained or lost, and the other side when it differs.
    final (String title, String amount, String? other) = switch (t) {
      _ when t.isCorrection => (
        'Balance correction',
        formatMoney(t.toAmount, t.toCurrency, signed: true),
        null,
      ),
      _ when t.fromAccountId == t.toAccountId => (
        'Exchange',
        formatMoney(t.toAmount, t.toCurrency, signed: true),
        '$sent exchanged',
      ),
      _ when t.fromAccountId == accountId => (
        'To ${_nameOf(t.toAccountId)}',
        formatMoney(-t.fromAmount!, t.fromCurrency),
        exchanged ? '$received received' : null,
      ),
      _ => (
        'From ${_nameOf(t.fromAccountId)}',
        formatMoney(t.toAmount, t.toCurrency, signed: true),
        exchanged ? '$sent sent' : null,
      ),
    };
    final value = Text(
      amount,
      style: TextStyle(
        color: palette.ink,
        fontWeight: FontWeight.w700,
        fontSize: 14,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _delete(context, ref),
        borderRadius: AppRadii.medium,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              QuietIcon(
                icon: t.isCorrection
                    ? Icons.tune_rounded
                    : Icons.swap_horiz_rounded,
                color: palette.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [?other, formatDateShort(t.date)].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.muted, fontSize: 11),
                    ),
                    if (large) ...[const SizedBox(height: 6), value],
                  ],
                ),
              ),
              if (!large) ...[const SizedBox(width: 12), value],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.error);
  final Object error;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        error is String ? error as String : _message(error),
        style: TextStyle(color: context.palette.negativeText),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

// ── sheets ──────────────────────────────────────────────────────────

Future<T?> _openSheet<T>(BuildContext context, Widget sheet) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => sheet,
    );

Future<String?> _askName(
  BuildContext context, {
  required String title,
  required String action,
  String initial = '',
}) => _openSheet<String>(
  context,
  _NameSheet(title: title, action: action, initial: initial),
);

/// Title, fields and one full-width primary action, like "Add currency".
class _SheetLayout extends StatelessWidget {
  const _SheetLayout({
    required this.title,
    required this.children,
    required this.action,
    required this.busy,
    required this.onSubmit,
  });
  final String title;
  final List<Widget> children;
  final String action;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accentFill,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadii.medium,
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(action),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({
    required this.title,
    required this.action,
    required this.initial,
  });
  final String title;
  final String action;
  final String initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => _SheetLayout(
    title: widget.title,
    action: widget.action,
    busy: false,
    onSubmit: _submit,
    children: [
      TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Name',
          hintText: 'e.g. Cash',
          errorText: _error,
        ),
      ),
    ],
  );
}

/// Amount field plus its currency, shared by both money sheets.
/// Amount field plus its currency, shared by the money sheets.
class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.controller,
    required this.currency,
    required this.currencies,
    required this.onCurrency,
    this.error,
  });
  final String label;
  final TextEditingController controller;
  final String currency;
  final List<Currency> currencies;
  final ValueChanged<String> onCurrency;
  final String? error;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: TextField(
          controller: controller,
          inputFormatters: const [AmountInputFormatter()],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          decoration: InputDecoration(
            labelText: label,
            hintText: '0.00',
            errorText: error,
          ),
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 104,
        child: PickerField(
          placeholder: 'Currency',
          selectedLabel: currency,
          onTap: () async {
            final picked = await showPickerBottomSheet<String>(
              context: context,
              title: 'Currency',
              items: [for (final c in currencies) c.code],
              labelBuilder: (code) => code,
              selectedItem: currency,
            );
            if (picked != null) onCurrency(picked);
          },
        ),
      ),
    ],
  );
}

Decimal? _positiveAmount(TextEditingController c) {
  final amount = parseAmountInput(c.text);
  return amount != null && amount > Decimal.zero ? amount : null;
}

/// Moves money between accounts; it arrives in the same currency.
class _TransferSheet extends ConsumerStatefulWidget {
  const _TransferSheet({required this.account, required this.accounts});
  final Account account;
  final List<Account> accounts;

  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  late Account _from = widget.account;
  late Account _to =
      widget.accounts.where((a) => a.id != widget.account.id).firstOrNull ??
      widget.account;
  String? _currency;
  final _amount = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit(String currency) async {
    final amount = _positiveAmount(_amount);
    setState(
      () => _error = amount == null ? 'Enter an amount greater than 0' : null,
    );
    if (amount == null) return;
    if (_from.id == _to.id) {
      _showError(context, 'Pick a different account');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(nativeApiProvider).createTransfer({
        'from_account_id': _from.id,
        'to_account_id': _to.id,
        'from_currency': currency,
        'from_amount': amount.toString(),
      });
      HapticFeedback.lightImpact();
      _refreshAccounts(ref);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencies =
        ref.watch(availableCurrenciesProvider).valueOrNull ?? const [];
    final base = ref.watch(settingsProvider).valueOrNull?.currencyCode ?? '';
    final currency =
        _currency ?? widget.account.balances.firstOrNull?.currency ?? base;
    Widget accountPicker(
      String title,
      Account value,
      ValueChanged<Account> on,
    ) => PickerFormField<Account>(
      title: title,
      value: value,
      placeholder: title,
      items: widget.accounts,
      labelBuilder: (a) => a.name,
      itemEquals: (a, b) => a.id == b.id,
      onChanged: (a) {
        if (a != null) setState(() => on(a));
      },
    );
    return _SheetLayout(
      title: 'Transfer',
      action: 'Transfer',
      busy: _busy,
      onSubmit: () => _submit(currency),
      children: [
        Text('From', style: TextStyle(color: context.palette.muted)),
        const SizedBox(height: 6),
        accountPicker('From', _from, (a) => _from = a),
        const SizedBox(height: 12),
        Text('To', style: TextStyle(color: context.palette.muted)),
        const SizedBox(height: 6),
        accountPicker('To', _to, (a) => _to = a),
        const SizedBox(height: 16),
        _AmountRow(
          label: 'Amount',
          controller: _amount,
          currency: currency,
          currencies: currencies,
          error: _error,
          onCurrency: (c) => setState(() => _currency = c),
        ),
      ],
    );
  }
}

/// Changes one currency into another inside the account, at the rate you got.
class _ExchangeSheet extends ConsumerStatefulWidget {
  const _ExchangeSheet({required this.account});
  final Account account;

  @override
  ConsumerState<_ExchangeSheet> createState() => _ExchangeSheetState();
}

class _ExchangeSheetState extends ConsumerState<_ExchangeSheet> {
  String? _giveCurrency;
  String? _getCurrency;
  final _give = TextEditingController();
  final _get = TextEditingController();
  String? _giveError;
  String? _getError;
  bool _busy = false;

  @override
  void dispose() {
    _give.dispose();
    _get.dispose();
    super.dispose();
  }

  Future<void> _submit(String giveCurrency, String getCurrency) async {
    final give = _positiveAmount(_give);
    final get = _positiveAmount(_get);
    setState(() {
      _giveError = give == null ? 'Enter an amount greater than 0' : null;
      _getError = get == null ? 'Enter the amount you got' : null;
    });
    if (give == null || get == null) return;
    if (giveCurrency == getCurrency) {
      _showError(context, 'Pick two different currencies');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(nativeApiProvider).createTransfer({
        'from_account_id': widget.account.id,
        'to_account_id': widget.account.id,
        'from_currency': giveCurrency,
        'from_amount': give.toString(),
        'to_currency': getCurrency,
        'to_amount': get.toString(),
      });
      HapticFeedback.lightImpact();
      _refreshAccounts(ref);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencies =
        ref.watch(availableCurrenciesProvider).valueOrNull ?? const [];
    final base = ref.watch(settingsProvider).valueOrNull?.currencyCode ?? '';
    final giveCurrency =
        _giveCurrency ?? widget.account.balances.firstOrNull?.currency ?? base;
    // Prefer another currency the account holds, then the default currency.
    final getCurrency =
        _getCurrency ??
        [
          ...widget.account.balances.map((b) => b.currency),
          base,
          ...currencies.map((c) => c.code),
        ].where((c) => c.isNotEmpty && c != giveCurrency).firstOrNull ??
        giveCurrency;
    return _SheetLayout(
      title: 'Exchange currency',
      action: 'Exchange',
      busy: _busy,
      onSubmit: () => _submit(giveCurrency, getCurrency),
      children: [
        Text(
          'Record money you changed inside ${widget.account.name}, at the '
          'rate you actually got.',
          style: TextStyle(
            color: context.palette.muted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        _AmountRow(
          label: 'You give',
          controller: _give,
          currency: giveCurrency,
          currencies: currencies,
          error: _giveError,
          onCurrency: (c) => setState(() => _giveCurrency = c),
        ),
        const SizedBox(height: 12),
        _AmountRow(
          label: 'You get',
          controller: _get,
          currency: getCurrency,
          currencies: currencies,
          error: _getError,
          onCurrency: (c) => setState(() => _getCurrency = c),
        ),
      ],
    );
  }
}

class _SetBalanceSheet extends ConsumerStatefulWidget {
  const _SetBalanceSheet({required this.account});
  final Account account;

  @override
  ConsumerState<_SetBalanceSheet> createState() => _SetBalanceSheetState();
}

class _SetBalanceSheetState extends ConsumerState<_SetBalanceSheet> {
  String? _currency;
  final _amount = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit(String currency) async {
    final amount = parseAmountInput(_amount.text);
    if (amount == null || amount < Decimal.zero) {
      setState(() => _error = 'Enter the amount you actually have');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await ref
          .read(nativeApiProvider)
          .setBalance(
            accountId: widget.account.id,
            currency: currency,
            amount: amount.toString(),
          );
      HapticFeedback.lightImpact();
      _refreshAccounts(ref);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencies =
        ref.watch(availableCurrenciesProvider).valueOrNull ?? const [];
    final base = ref.watch(settingsProvider).valueOrNull?.currencyCode ?? '';
    final currency =
        _currency ?? widget.account.balances.firstOrNull?.currency ?? base;
    final current =
        widget.account.balances
            .where((b) => b.currency == currency)
            .firstOrNull
            ?.amount ??
        Decimal.zero;
    return _SheetLayout(
      title: 'Set balance',
      action: 'Set balance',
      busy: _busy,
      onSubmit: () => _submit(currency),
      children: [
        Text(
          'Moneef shows ${formatMoney(current, currency)} in '
          '${widget.account.name}. Enter what you actually have; the '
          "difference is saved as a correction and doesn't count as income "
          'or spending.',
          style: TextStyle(
            color: context.palette.muted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        _AmountRow(
          label: 'Actual balance',
          controller: _amount,
          currency: currency,
          currencies: currencies,
          error: _error,
          onCurrency: (c) => setState(() => _currency = c),
        ),
      ],
    );
  }
}
