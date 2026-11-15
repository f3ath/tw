import 'package:material_ui/material_ui.dart';

class const ErrorRetryView({
  super.key,
  required final String message,
  required final Key errorTextKey,
  required final Key retryButtonKey,
  required final VoidCallback onRetry,
  final MainAxisSize mainAxisSize = MainAxisSize.min,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: mainAxisSize,
      children: [
        Text(message, key: errorTextKey),
        FilledButton(key: retryButtonKey, onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
