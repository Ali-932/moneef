import 'package:flutter/material.dart';

import '../../theme.dart';

Future<bool?> showDiscardChangesDialog(BuildContext context) =>
    showDialog<bool>(
      context: context,
      builder: (_) => const _DiscardChangesDialog(),
    );

class _DiscardChangesDialog extends StatelessWidget {
  const _DiscardChangesDialog();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      constraints: const BoxConstraints(maxWidth: 400),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: palette.primarySoft,
                borderRadius: AppRadii.large,
              ),
              child: Icon(
                Icons.edit_note_rounded,
                color: palette.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              namesRoute: true,
              child: Text(
                'Discard changes?',
                style: Theme.of(context).dialogTheme.titleTextStyle,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your transaction has unsaved changes. Keep editing to finish, or discard to leave without saving.',
              style: Theme.of(context).dialogTheme.contentTextStyle,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: palette.negativeText,
                  minimumSize: const Size(48, 48),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadii.medium,
                  ),
                ),
                child: const Text('Discard changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
