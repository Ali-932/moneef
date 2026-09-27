import 'package:flutter_test/flutter_test.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mobile_app/utils/mdi.dart';

void main() {
  test('mdiIconData maps mdi: names (incl. kebab-case) and falls back', () {
    expect(mdiIconData('mdi:cart'), MdiIcons.cart);
    expect(mdiIconData('mdi:cash-multiple'), MdiIcons.cashMultiple);
    expect(mdiIconData('coffee'), MdiIcons.coffee); // bare name also works
    expect(mdiIconData(''), MdiIcons.folder); // empty → default
    expect(mdiIconData('mdi:not-a-real-icon-xyz'), MdiIcons.folder); // unknown
  });
}
