import 'package:app/ui/list_state_view.dart';
import 'package:app/ui/list_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('shows the empty message after a successful empty load', (tester) async {
    final model = ListViewModel<String>(fetch: () async => []);
    addTearDown(model.dispose);
    await model.load();

    await tester.pumpWidget(
      MaterialApp(
        home: ListStateView<String>(
          model: model,
          loadingIndicatorKey: const ValueKey('loading'),
          errorTextKey: const ValueKey('error'),
          retryButtonKey: const ValueKey('retry'),
          emptyTextKey: const ValueKey('empty'),
          errorMessage: 'Could not load items',
          emptyMessage: 'No items yet',
          itemBuilder: (item) => Text(item),
        ),
      ),
    );

    expect(find.text('No items yet'), findsOneWidget);
  });
}
