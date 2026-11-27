import 'dart:async';

import 'package:material_ui/material_ui.dart';

Future<void> openAndRefreshOnChange({
  required BuildContext context,
  required Widget Function(VoidCallback) buildScreen,
  required Future<void> Function() refresh,
  VoidCallback? onChanged,
}) async {
  var changed = false;
  var returned = false;

  void markChanged() {
    changed = true;
    onChanged?.call();
    if (returned && context.mounted) unawaited(refresh());
  }

  await Navigator.of(context)
      .push<void>(MaterialPageRoute(builder: (_) => buildScreen(markChanged)));
  returned = true;
  if (changed && context.mounted) await refresh();
}
