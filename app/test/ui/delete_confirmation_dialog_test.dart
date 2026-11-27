import 'package:app/ui/delete_confirmation_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('Delete confirms the action', (tester) async {
    bool? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => const DeleteConfirmationDialog(
                  title: 'Delete vehicle?',
                  message: 'Delete "Truck"? This cannot be undone.',
                ),
              );
            },
            child: const Text('Open dialog'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
  });
}
