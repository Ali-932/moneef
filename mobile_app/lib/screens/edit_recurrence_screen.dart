import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/recurrence_template.dart';
import '../state/recurrences_controller.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/errors.dart';
import '../widgets/common/date_picker_style.dart';
import '../widgets/common/discard_changes_dialog.dart';
import '../widgets/common/picker_field.dart';
import '../widgets/common/skeletons.dart';

class EditRecurrenceScreen extends ConsumerWidget {
  const EditRecurrenceScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recurrencesProvider);
    return records.when(
      data: (items) {
        for (final item in items) {
          if (item.id == id) {
            return _RecurrenceForm(key: ValueKey(id), initial: item);
          }
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Edit recurring payment')),
          body: const Center(
            child: Text('This recurring payment no longer exists.'),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Edit recurring payment')),
        body: const RecurrencesSkeleton(itemCount: 3),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: const Text('Edit recurring payment')),
        body: Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(recurrencesProvider),
            child: const Text('Could not load payment. Try again'),
          ),
        ),
      ),
    );
  }
}

class _RecurrenceForm extends ConsumerStatefulWidget {
  const _RecurrenceForm({super.key, required this.initial});
  final RecurrenceTemplate initial;

  @override
  ConsumerState<_RecurrenceForm> createState() => _RecurrenceFormState();
}

class _RecurrenceFormState extends ConsumerState<_RecurrenceForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _merchant, _notes;
  final _merchantFocus = FocusNode();
  final _notesFocus = FocusNode();
  late String _frequency;
  late bool _active, _hasEndDate;
  DateTime? _nextDate, _endDate;
  late final Map<String, dynamic> _initialPayload;
  bool _busy = false, _leaving = false, _confirmingDiscard = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial.name);
    _merchant = TextEditingController(text: initial.merchantName);
    _notes = TextEditingController(text: initial.notes);
    _frequency = initial.frequency;
    _active = initial.isActive;
    _hasEndDate = initial.hasEndDate;
    _nextDate = initial.nextDate;
    _endDate = initial.endDate;
    _initialPayload = _payload();
  }

  @override
  void dispose() {
    _name.dispose();
    _merchant.dispose();
    _notes.dispose();
    _merchantFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  Map<String, dynamic> _payload() => {
    'name': _name.text.trim(),
    'frequency': _frequency,
    'next_date': _nextDate?.toUtc().toIso8601String(),
    'has_end_date': _hasEndDate,
    // End dates include the selected day, even when the next payment has a time.
    'end_date': _hasEndDate && _endDate != null
        ? DateTime(
            _endDate!.year,
            _endDate!.month,
            _endDate!.day,
            23,
            59,
            59,
          ).toUtc().toIso8601String()
        : null,
    'is_active': _active,
    'merchant_name': _merchant.text.trim(),
    'notes': _notes.text.trim(),
  };

  bool get _dirty => !mapEquals(_payload(), _initialPayload);

  void _changed() => setState(() => _saveError = null);

  Future<void> _leave({bool saved = false}) async {
    setState(() => _leaving = true);
    // Let PopScope rebuild before popping, including the Android back gesture.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) context.pop(saved);
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _saveError = null;
    });
    try {
      await ref
          .read(recurrencesControllerProvider)
          .update(widget.initial.id, _payload());
      if (!mounted) return;
      setState(() => _busy = false);
      await _leave(saved: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _saveError = userMessage(
          e is PlatformException ? e.message ?? '' : e,
          fallback: 'Could not save changes. Please try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PopScope(
      canPop: !_busy && (_leaving || !_dirty),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _busy || _confirmingDiscard) return;
        _confirmingDiscard = true;
        final discard = await showDiscardChangesDialog(context);
        _confirmingDiscard = false;
        if (discard == true && mounted) await _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Edit recurring payment',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: AbsorbPointer(
          absorbing: _busy,
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  'Changes apply to this recurring schedule. Past transactions stay unchanged.',
                  style: TextStyle(color: palette.muted, fontSize: 13),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  textInputAction: TextInputAction.next,
                  onEditingComplete: _merchantFocus.requestFocus,
                  onChanged: (_) => _changed(),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 24),
                Text(
                  'Schedule',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                PickerFormField<String>(
                  label: 'Frequency',
                  title: 'Frequency',
                  placeholder: 'Choose a frequency',
                  value: _frequency,
                  items: recurrenceFrequencies.keys.toList(),
                  labelBuilder: (value) =>
                      recurrenceFrequencies[value] ?? value,
                  showSearch: false,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _frequency = value;
                        _saveError = null;
                      });
                    }
                  },
                  validator: (value) => recurrenceFrequencies.containsKey(value)
                      ? null
                      : 'Choose a frequency',
                ),
                const SizedBox(height: 16),
                _ScheduleDateField(
                  label: 'Next payment date',
                  date: _nextDate,
                  validator: (_) =>
                      _nextDate == null ? 'Choose the next payment date' : null,
                  onChanged: (date) => setState(() {
                    _nextDate = date;
                    _saveError = null;
                  }),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: Text(
                    _active ? 'Included in upcoming payments' : 'Paused',
                  ),
                  value: _active,
                  onChanged: (value) => setState(() {
                    _active = value;
                    _saveError = null;
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Set an end date'),
                  value: _hasEndDate,
                  onChanged: (value) => setState(() {
                    _hasEndDate = value;
                    if (value) _endDate ??= _nextDate ?? DateTime.now();
                    _saveError = null;
                  }),
                ),
                if (_hasEndDate) ...[
                  const SizedBox(height: 8),
                  _ScheduleDateField(
                    label: 'End date',
                    date: _endDate,
                    onChanged: (date) => setState(() {
                      _endDate = date;
                      _saveError = null;
                    }),
                    validator: (_) {
                      if (_endDate == null) return 'Choose an end date';
                      if (_nextDate != null &&
                          DateUtils.dateOnly(
                            _endDate!,
                          ).isBefore(DateUtils.dateOnly(_nextDate!))) {
                        return 'End date must be on or after the next payment';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 24),
                Text('Details', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _merchant,
                  focusNode: _merchantFocus,
                  decoration: const InputDecoration(
                    labelText: 'Merchant (optional)',
                  ),
                  textInputAction: TextInputAction.next,
                  onEditingComplete: _notesFocus.requestFocus,
                  onChanged: (_) => _changed(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notes,
                  focusNode: _notesFocus,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  onChanged: (_) => _changed(),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_saveError != null) ...[
                  Text(
                    _saveError!,
                    style: TextStyle(color: palette.negativeText),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Saving…' : 'Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleDateField extends StatelessWidget {
  const _ScheduleDateField({
    required this.label,
    required this.date,
    required this.onChanged,
    required this.validator,
  });
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onChanged;
  final FormFieldValidator<DateTime> validator;

  @override
  Widget build(BuildContext context) => FormField<DateTime>(
    initialValue: date,
    validator: validator,
    builder: (state) => InkWell(
      borderRadius: AppRadii.medium,
      onTap: () async {
        FocusManager.instance.primaryFocus?.unfocus();
        final current = date ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          builder: buildAppDatePicker,
          helpText: label,
          confirmText: 'Use date',
          initialDate: current,
          firstDate: DateTime(current.year < 1900 ? current.year : 1900),
          lastDate: DateTime(current.year > 2100 ? current.year + 1 : 2100),
          switchToInputEntryModeIcon: const Icon(Icons.edit_calendar_outlined),
        );
        if (picked != null && state.mounted) {
          state.didChange(picked);
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: state.errorText,
          errorMaxLines: 3,
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: context.palette.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                date == null ? 'Choose a date' : formatDateLong(date!),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
