import 'package:flutter/widgets.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Resolves a backend icon string — an Iconify `mdi:` name like
/// `mdi:cash-multiple` — to a Flutter [IconData]. The backend stores icons
/// from the `mdi:` (Material Design Icons) set.
///
/// Unknown or empty values fall back to `mdi:folder`.
IconData mdiIconData(String? raw) {
  if (raw == null || raw.trim().isEmpty) return MdiIcons.folder;
  var name = raw.trim();
  if (name.startsWith('mdi:')) name = name.substring(4);
  if (name.startsWith('mdi-')) name = name.substring(4);
  // Iconify names are kebab-case; the Flutter package keys are camelCase.
  final key = name.replaceAllMapped(
    RegExp(r'[-_](\w)'),
    (m) => m[1]!.toUpperCase(),
  );
  return MdiIcons.fromString(key) ?? MdiIcons.folder;
}
