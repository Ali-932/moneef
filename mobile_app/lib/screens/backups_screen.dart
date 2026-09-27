import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/backup_service.dart';
import '../state/bootstrap.dart';
import '../state/providers.dart';
import '../state/insights_providers.dart';
import '../theme.dart';
import '../widgets/common/design.dart';

String _date(DateTime value) => DateFormat('d MMM y · h:mm a').format(value);
String _error(Object e) => e is PlatformException
    ? e.message ?? 'Could not access your backups. Please try again.'
    : 'Could not access your backups. Please try again.';

class BackupsScreen extends ConsumerStatefulWidget {
  const BackupsScreen({super.key});
  @override
  ConsumerState<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends ConsumerState<BackupsScreen> {
  bool _working = false;
  String? _failure;

  Future<void> _run(Future<void> Function(BackupService) action) async {
    setState(() {
      _working = true;
      _failure = null;
    });
    try {
      await action(ref.read(backupServiceProvider));
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _choose() => _run((service) async {
    final folder = await service.chooseFolder();
    if (folder != null) await service.configure(folder);
  });

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(backupStatusProvider);
    final status = async.valueOrNull;
    final busy = _working || (status?.busy ?? false);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Local backups')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _BackupCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QuietIcon(
                    icon: status?.enabled == true
                        ? Icons.folder_copy_outlined
                        : Icons.shield_outlined,
                    color: context.palette.primary,
                    size: 56,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    status?.enabled == true
                        ? 'A copy, close to home.'
                        : 'Keep a copy of your money story.',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Save your transactions, categories, and preferences to a folder on this device. No account or internet needed.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: context.palette.muted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (status == null)
                    const LinearProgressIndicator()
                  else if (!status.supported)
                    const Text(
                      'Local backups are available in the Android app.',
                    )
                  else if (status.enabled) ...[
                    _InfoRow(
                      icon: Icons.folder_outlined,
                      label: 'Backup folder',
                      value: status.folderName ?? 'Selected folder',
                    ),
                    const SizedBox(height: 18),
                    _InfoRow(
                      icon: status.error != null
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      label: busy
                          ? 'Updating backup…'
                          : 'Last successful backup',
                      value: status.lastBackup == null
                          ? 'No completed backup yet'
                          : _date(status.lastBackup!),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: busy ? null : () => _run((s) => s.backupNow()),
                      icon: const Icon(Icons.backup_outlined),
                      label: Text(busy ? 'Working…' : 'Back up now'),
                    ),
                    TextButton.icon(
                      onPressed: busy ? null : _choose,
                      icon: const Icon(
                        Icons.drive_file_move_outlined,
                        size: 20,
                      ),
                      label: const Text('Change folder'),
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: busy ? null : _choose,
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Enable local backups'),
                    ),
                ],
              ),
            ),
            if (_failure != null ||
                status?.error != null ||
                async.hasError) ...[
              const SizedBox(height: 16),
              _Failure(
                message: _failure ?? status?.error ?? _error(async.error!),
              ),
            ],
            const SizedBox(height: 20),
            _BackupCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Already have a backup?',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a saved copy to restore your data.',
                    style: TextStyle(color: context.palette.muted, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: busy || status?.supported != true
                        ? null
                        : () => context.push('/profile/backups/restore'),
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Restore backup'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _InfoRow(
              icon: Icons.update_rounded,
              label: 'Automatic after changes',
              value:
                  'While you use Moneef, each change updates your backup. The latest 7 copies from this installation are kept.',
            ),
            const SizedBox(height: 20),
            const _InfoRow(
              icon: Icons.phone_android_outlined,
              label: 'Ready for a reinstall',
              value:
                  'Your chosen folder stays after uninstalling. On reinstall, select Restore local backup and choose the folder again.',
            ),
            const SizedBox(height: 20),
            const _InfoRow(
              icon: Icons.lock_open_outlined,
              label: 'Your folder, your files',
              value:
                  'Backup files contain your financial data and are not password protected. Keep the folder private. Deleting it or resetting your phone removes these copies.',
            ),
          ],
        ),
      ),
    );
  }
}

class BackupWelcomeScreen extends ConsumerStatefulWidget {
  const BackupWelcomeScreen({super.key});
  @override
  ConsumerState<BackupWelcomeScreen> createState() =>
      _BackupWelcomeScreenState();
}

class _BackupWelcomeScreenState extends ConsumerState<BackupWelcomeScreen> {
  bool _restore = false;
  @override
  Widget build(BuildContext context) {
    if (_restore) {
      return RestoreBackupScreen(
        onBack: () => setState(() => _restore = false),
        firstLaunch: true,
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QuietIcon(
                    icon: Icons.account_balance_wallet_outlined,
                    color: context.palette.primary,
                    size: 72,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Your money.\nYour own space.',
                    style: TextStyle(
                      fontSize: 36,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Track your spending, understand your habits, and keep your data on your device.',
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.6,
                      color: context.palette.muted,
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => ref
                          .read(bootControllerProvider.notifier)
                          .startFresh(),
                      child: const Text('Start fresh'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _restore = true),
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Restore local backup'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No account needed. Works offline.',
                    style: TextStyle(
                      color: context.palette.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RestoreBackupScreen extends ConsumerStatefulWidget {
  const RestoreBackupScreen({super.key, this.firstLaunch = false, this.onBack});
  final bool firstLaunch;
  final VoidCallback? onBack;
  @override
  ConsumerState<RestoreBackupScreen> createState() =>
      _RestoreBackupScreenState();
}

class _RestoreBackupScreenState extends ConsumerState<RestoreBackupScreen> {
  BackupFolder? _folder;
  BackupListing? _listing;
  LocalBackup? _selected;
  bool _busy = false;
  String? _failure;

  Future<void> _choose() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final service = ref.read(backupServiceProvider);
      final folder = await service.chooseFolder();
      if (folder == null) return;
      final listing = await service.list(folder);
      if (mounted) {
        setState(() {
          _folder = folder;
          _listing = listing;
          _selected = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final id = await ref
          .read(backupServiceProvider)
          .restore(_folder!, _selected!);
      await ref.read(bootControllerProvider.notifier).completeRestore(id);
      // Most providers watch BootState. These retain explicit lists/filters.
      ref.invalidate(transactionFilterProvider);
      ref.invalidate(transactionsListProvider);
      ref.invalidate(transactionByIdProvider);
      ref.invalidate(analysisProvider);
      ref.invalidate(insightsIncomeProvider);
      ref.invalidate(patternsProvider);
      ref.invalidate(recurrenceTimelineProvider);
      if (mounted && !widget.firstLaunch) {
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup restored. Automatic backups are enabled.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Restore a backup'),
          leading: widget.onBack == null
              ? null
              : IconButton(
                  onPressed: _busy ? null : widget.onBack,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _BackupCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QuietIcon(
                    icon: Icons.history_rounded,
                    color: context.palette.primary,
                    size: 56,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Pick up where you left off.',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _folder?.name ??
                        'Choose the folder where you saved your Moneef backups. You can review a copy before restoring it.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: context.palette.muted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _choose,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: Text(
                      _folder == null
                          ? 'Choose backup folder'
                          : 'Choose another folder',
                    ),
                  ),
                ],
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: LinearProgressIndicator(),
              ),
            if (_failure != null && _selected == null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _Failure(message: _failure!),
              ),
            if (_listing != null) ...[
              const SizedBox(height: 24),
              Text(
                _listing!.backups.isEmpty
                    ? 'No backups found'
                    : 'Available copies',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (_listing!.backups.isEmpty)
                Text(
                  'Choose the folder containing your .moneefbackup files.',
                  style: TextStyle(color: context.palette.muted, height: 1.5),
                ),
              if (_listing!.unreadable > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${_listing!.unreadable} incomplete or unsupported file(s) could not be listed.',
                    style: TextStyle(color: context.palette.negativeText),
                  ),
                ),
              for (final backup in _listing!.backups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: _selected == backup
                        ? context.palette.primarySoft
                        : context.palette.card,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _busy
                          ? null
                          : () => setState(() => _selected = backup),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Icon(
                              _selected == backup
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: context.palette.primary,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _date(backup.createdAt),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${NumberFormat.decimalPattern().format(backup.transactionCount)} transactions',
                                    style: TextStyle(
                                      color: context.palette.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            if (_selected != null) ...[
              const SizedBox(height: 16),
              _BackupCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.firstLaunch
                          ? 'Restore this copy?'
                          : 'Replace current data?',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.firstLaunch
                          ? 'Your transactions, categories, and preferences will be restored. Automatic backups will use this folder.'
                          : 'This replaces all current transactions, categories, and preferences with the selected copy. The data is not merged. Automatic backups will use this folder.',
                      style: TextStyle(
                        height: 1.6,
                        color: context.palette.muted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_failure != null) ...[
                      _Failure(message: _failure!),
                      const SizedBox(height: 16),
                    ],
                    FilledButton.icon(
                      onPressed: _busy ? null : _restore,
                      icon: const Icon(Icons.restore_rounded),
                      label: Text(_busy ? 'Restoring…' : 'Restore this backup'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BackupPrompt extends ConsumerWidget {
  const BackupPrompt({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(backupStatusProvider).valueOrNull;
    if (status == null ||
        !status.supported ||
        (status.error == null && (status.enabled || status.dismissed))) {
      return const SizedBox.shrink();
    }
    final failed = status.error != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: _BackupCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  failed
                      ? Icons.warning_amber_rounded
                      : Icons.folder_copy_outlined,
                  color: context.palette.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    failed
                        ? 'Your backup needs attention'
                        : 'Keep a local backup',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              failed
                  ? status.error!
                  : 'Keep a copy in a device folder so you can restore after reinstalling.',
              style: TextStyle(color: context.palette.muted, height: 1.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () => context.push('/profile/backups'),
                  child: Text(
                    failed ? 'Review backups' : 'Enable local backups',
                  ),
                ),
                if (!failed)
                  TextButton(
                    onPressed: () => ref.read(backupServiceProvider).dismiss(),
                    child: const Text('Maybe later'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  const _BackupCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: context.palette.card,
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: context.palette.primary, size: 22),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: context.palette.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.palette.expenseBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        message,
        style: TextStyle(color: context.palette.negativeText, height: 1.5),
      ),
    ),
  );
}
