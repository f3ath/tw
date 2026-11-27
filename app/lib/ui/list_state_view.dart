import 'package:app/ui/error_retry_view.dart';
import 'package:app/ui/list_view_model.dart';
import 'package:app/ui/loading_view.dart';
import 'package:material_ui/material_ui.dart';

class const ListStateView<T>({
  super.key,
  required final ListViewModel<T> model,
  required final Key loadingIndicatorKey,
  required final Key errorTextKey,
  required final Key retryButtonKey,
  required final Key emptyTextKey,
  required final String errorMessage,
  required final String emptyMessage,
  required final Widget Function(T item) itemBuilder,
  final MainAxisSize errorMainAxisSize = MainAxisSize.min,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (_, _) {
      if (model.isLoading) {
        return LoadingView(indicatorKey: loadingIndicatorKey);
      }
      if (model.hasError) {
        return ErrorRetryView(
          message: errorMessage,
          errorTextKey: errorTextKey,
          retryButtonKey: retryButtonKey,
          onRetry: model.load,
          mainAxisSize: errorMainAxisSize,
        );
      }
      final items = model.items;
      if (items.isEmpty) {
        return Center(child: Text(emptyMessage, key: emptyTextKey));
      }
      return ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, index) => itemBuilder(items[index]),
      );
    },
  );
}
