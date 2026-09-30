import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/currency.dart';
import '../models/exchange_rate.dart';
import '../state/bootstrap.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/common/labeled_switch_row.dart';
import '../widgets/common/picker_field.dart';
import '../widgets/common/skeletons.dart';
import '../widgets/common/design.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const PageHeading(
        title: 'Profile',
        subtitle: 'Your account and preferences',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [
          _ProfileCard(),
          SizedBox(height: 16),
          _ManagementCard(),
          SizedBox(height: 16),
          _PreferencesCard(),
          SizedBox(height: 16),
          _ExchangeRateApiCard(),
          SizedBox(height: 16),
          _CurrenciesCard(),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          color: palette.ink,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppMotion.sectionSwitch,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: AppRadii.large,
        ),
        child: child,
      ),
    );
  }
}

class _ProfileCard extends ConsumerStatefulWidget {
  const _ProfileCard();
  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _lastNameFocus = FocusNode();
  bool _hydrated = false;
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _firstController.dispose();
    _lastController.dispose();
    _lastNameFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    HapticFeedback.selectionClick();
    setState(() => _saving = true);
    try {
      await ref.read(nativeApiProvider).updateProfile({
        'first_name': _firstController.text.trim(),
        'last_name': _lastController.text.trim(),
      });
      ref.invalidate(profileProvider);
      if (mounted) setState(() => _editing = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final async = ref.watch(profileProvider);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          async.when(
            loading: () => const ProfileCardRowsSkeleton(rows: 2),
            error: (e, _) => Text(
              userMessage(e),
              style: TextStyle(color: palette.negativeText),
            ),
            data: (p) {
              final first = p['first_name'] as String? ?? '';
              final last = p['last_name'] as String? ?? '';
              if (!_hydrated) {
                _firstController.text = first;
                _lastController.text = last;
                _hydrated = true;
              }
              final fullName = [
                first,
                last,
              ].where((s) => s.isNotEmpty).join(' ');
              final initials =
                  '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}'
                      .toUpperCase();
              return Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: palette.primarySoft,
                        child: Text(
                          initials.isEmpty ? '?' : initials,
                          style: TextStyle(
                            color: palette.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName.isEmpty ? 'Your name' : fullName,
                              style: TextStyle(
                                color: palette.ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Personal profile',
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: _editing
                            ? 'Close profile editor'
                            : 'Edit profile',
                        onPressed: () => setState(() => _editing = !_editing),
                        icon: Icon(
                          _editing ? Icons.close_rounded : Icons.edit_outlined,
                          size: 20,
                          color: palette.primary,
                        ),
                      ),
                    ],
                  ),
                  if (_editing) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstController,
                            textInputAction: TextInputAction.next,
                            onEditingComplete: _lastNameFocus.requestFocus,
                            decoration: const InputDecoration(
                              labelText: 'First name',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lastController,
                            focusNode: _lastNameFocus,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Last name',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.accentFill,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadii.medium,
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PreferencesCard extends ConsumerWidget {
  const _PreferencesCard();

  Future<void> _setCurrency(
    BuildContext context,
    WidgetRef ref,
    String code,
  ) async {
    try {
      await ref.read(nativeApiProvider).updateSettings({'currency_code': code});
      ref.invalidate(settingsProvider);
      ref.invalidate(exchangeRatesProvider);
      ref.invalidate(availableCurrenciesProvider);
      ref.invalidate(dashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMessage(e))));
      }
    }
  }

  Future<void> _setDarkMode(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    HapticFeedback.selectionClick();
    try {
      await ref.read(nativeApiProvider).updateSettings({'is_dark_mode': value});
      // themeModeProvider watches settingsProvider; the whole app
      // cross-fades to the new palette when this reloads.
      ref.invalidate(settingsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final settingsAsync = ref.watch(settingsProvider);
    final available = ref
        .watch(availableCurrenciesProvider)
        .maybeWhen(data: (d) => d, orElse: () => const <Currency>[]);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Preferences'),
          settingsAsync.when(
            loading: () => const ProfileCardRowsSkeleton(rows: 2),
            error: (e, _) => Text(
              userMessage(e),
              style: TextStyle(color: palette.negativeText),
            ),
            data: (s) {
              final codes = available.map((c) => c.code).toSet()
                ..add(s.currencyCode);
              final sorted = codes.toList()..sort();
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Default currency',
                          style: TextStyle(
                            color: palette.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showPickerBottomSheet<String>(
                            context: context,
                            title: 'Default currency',
                            items: sorted,
                            labelBuilder: (code) => code,
                            selectedItem: s.currencyCode,
                          );
                          if (picked != null && context.mounted) {
                            _setCurrency(context, ref, picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: palette.tile,
                            borderRadius: AppRadii.medium,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                s.currencyCode,
                                style: TextStyle(
                                  color: palette.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: palette.muted,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LabeledSwitchRow(
                    label: 'Dark mode',
                    labelStyle: TextStyle(
                      color: palette.ink,
                      fontWeight: FontWeight.w600,
                    ),
                    value: s.isDarkMode,
                    activeThumbColor: palette.primary,
                    adaptive: true,
                    onChanged: (v) => _setDarkMode(context, ref, v),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExchangeRateApiCard extends ConsumerStatefulWidget {
  const _ExchangeRateApiCard();
  @override
  ConsumerState<_ExchangeRateApiCard> createState() =>
      _ExchangeRateApiCardState();
}

class _ExchangeRateApiCardState extends ConsumerState<_ExchangeRateApiCard> {
  final _keyController = TextEditingController();
  bool _hydrated = false;
  bool _obscure = true;
  bool _savingKey = false;
  bool _fetching = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    setState(() => _savingKey = true);
    try {
      await ref.read(nativeApiProvider).updateSettings({
        'exchange_rate_api_key': _keyController.text.trim(),
      });
      ref.invalidate(settingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _savingKey = false);
    }
  }

  Future<void> _fetch() async {
    HapticFeedback.selectionClick();
    setState(() => _fetching = true);
    try {
      await ref.read(nativeApiProvider).fetchExchangeRates();
      ref.invalidate(exchangeRatesProvider);
      ref.invalidate(availableCurrenciesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Rates updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final settingsAsync = ref.watch(settingsProvider);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Live exchange rates'),
          Text(
            'Automatically pulls current conversion rates from exchangerate-api.com so your transactions convert correctly. Optional — you can enter rates manually below.',
            style: TextStyle(color: palette.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          settingsAsync.maybeWhen(
            data: (s) {
              if (!_hydrated) {
                _keyController.text = s.exchangeRateApiKey;
                _hydrated = true;
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
          TextField(
            controller: _keyController,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Service key',
              hintText: 'Service key',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _savingKey ? null : _saveKey,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accentFill,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.medium,
                    ),
                  ),
                  child: _savingKey
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save key'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _fetching ? null : _fetch,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.medium,
                    ),
                  ),
                  child: _fetching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update rates now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurrenciesCard extends ConsumerWidget {
  const _CurrenciesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final settingsAsync = ref.watch(settingsProvider);
    final ratesAsync = ref.watch(exchangeRatesProvider);
    final base = settingsAsync.maybeWhen(
      data: (s) => s.currencyCode,
      orElse: () => '',
    );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _SectionTitle('Currencies')),
              TextButton.icon(
                onPressed: base.isEmpty
                    ? null
                    : () => _openAddCurrency(context, ref, base),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          Text(
            base.isEmpty
                ? ''
                : 'Rates relative to your base currency ($base). Only added currencies can be used in transactions.',
            style: TextStyle(color: palette.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ratesAsync.when(
            loading: () => const ProfileCardRowsSkeleton(rows: 3),
            error: (e, _) => Text(
              userMessage(e),
              style: TextStyle(color: palette.negativeText),
            ),
            data: (rates) {
              if (rates.isEmpty) {
                return Text(
                  'No currencies added yet. Tap Add or update rates to get started.',
                  style: TextStyle(color: palette.muted, fontSize: 13),
                );
              }
              return Column(
                children: [
                  for (final r in rates) _RateRow(rate: r, base: base),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openAddCurrency(
    BuildContext context,
    WidgetRef ref,
    String base,
  ) async {
    final master = await ref.read(currenciesProvider.future);
    final rates = await ref.read(exchangeRatesProvider.future);
    final usedCodes = {base, for (final r in rates) r.from};
    final addable = master.where((c) => !usedCodes.contains(c.code)).toList();

    if (!context.mounted) return;
    if (addable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All currencies already added')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: context.palette.surface,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddCurrencySheet(base: base, options: addable),
    );
  }
}

class _RateRow extends ConsumerStatefulWidget {
  const _RateRow({required this.rate, required this.base});
  final ExchangeRate rate;
  final String base;
  @override
  ConsumerState<_RateRow> createState() => _RateRowState();
}

class _RateRowState extends ConsumerState<_RateRow> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Stored rate is foreign→base (e.g. 1 IQD = 0.00076 USD); show its inverse
    // so the field reads as the natural "1 {base} = N {foreign}" (e.g. 1314).
    _controller = TextEditingController(
      text: inverseRateString(widget.rate.rate),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = Decimal.tryParse(_controller.text.trim());
    if (value == null || value <= Decimal.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rate must be greater than zero')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      // Field holds the base→foreign rate ("1 USD = 1314 IQD"), so store
      // from=base, to=foreign. UpsertExchangeRate also writes the inverse
      // (foreign→base) — the row the dashboard reads. Do NOT swap from/to.
      await ref
          .read(nativeApiProvider)
          .upsertExchangeRate(
            from: widget.base,
            to: widget.rate.from,
            rate: value.toString(),
          );
      ref.invalidate(exchangeRatesProvider);
      ref.invalidate(availableCurrenciesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              widget.rate.from,
              style: TextStyle(color: palette.ink, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '1 ${widget.base} =',
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
          ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.check, color: palette.primary),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _AddCurrencySheet extends ConsumerStatefulWidget {
  const _AddCurrencySheet({required this.base, required this.options});
  final String base;
  final List<Currency> options;
  @override
  ConsumerState<_AddCurrencySheet> createState() => _AddCurrencySheetState();
}

class _AddCurrencySheetState extends ConsumerState<_AddCurrencySheet> {
  Currency? _selected;
  final _rateController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_selected == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pick a currency')));
      return;
    }
    final value = Decimal.tryParse(_rateController.text.trim());
    if (value == null || value <= Decimal.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a rate greater than zero')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(nativeApiProvider)
          .upsertExchangeRate(
            from: widget.base,
            to: _selected!.code,
            rate: value.toString(),
          );
      ref.invalidate(exchangeRatesProvider);
      ref.invalidate(availableCurrenciesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMessage(e))));
        setState(() => _saving = false);
      }
    }
  }

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add currency',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 16),
          PickerFormField<Currency>(
            title: 'Select currency',
            value: _selected,
            placeholder: 'Select currency',
            items: widget.options,
            labelBuilder: (c) => '${c.code} — ${c.name}',
            itemEquals: (a, b) => a.code == b.code,
            onChanged: (v) => setState(() => _selected = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText:
                  '1 ${widget.base} = ? ${_selected?.code ?? 'currency'}',
              hintText: '0.00',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _add,
              style: FilledButton.styleFrom(
                backgroundColor: palette.accentFill,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadii.medium,
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Add currency'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementCard extends StatelessWidget {
  const _ManagementCard();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Organize your money'),
          // ListTile paints its background/ink on the nearest Material
          // ancestor; without this, _Card's colored Container hides both.
          Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: QuietIcon(
                    icon: Icons.account_balance_wallet_outlined,
                    color: palette.primary,
                    size: 36,
                  ),
                  title: const Text('Accounts'),
                  subtitle: const Text('Where your money lives'),
                  trailing: Icon(Icons.chevron_right, color: palette.muted),
                  onTap: () => context.push('/profile/accounts'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: QuietIcon(
                    icon: Icons.grid_view_rounded,
                    color: palette.primary,
                    size: 36,
                  ),
                  title: const Text('Categories'),
                  subtitle: const Text('Give every expense a place'),
                  trailing: Icon(Icons.chevron_right, color: palette.muted),
                  onTap: () => context.push('/profile/categories'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: QuietIcon(
                    icon: Icons.event_repeat_outlined,
                    color: palette.primary,
                    size: 36,
                  ),
                  title: const Text('Recurring payments'),
                  subtitle: const Text('Subscriptions and regular bills'),
                  trailing: Icon(Icons.chevron_right, color: palette.muted),
                  onTap: () => context.push('/profile/recurrences'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: QuietIcon(
                    icon: Icons.folder_copy_outlined,
                    color: palette.primary,
                    size: 36,
                  ),
                  title: const Text('Local backups'),
                  subtitle: const Text('Save and restore on this device'),
                  trailing: Icon(Icons.chevron_right, color: palette.muted),
                  onTap: () => context.push('/profile/backups'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
