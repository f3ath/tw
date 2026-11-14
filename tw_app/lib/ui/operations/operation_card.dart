import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';

class const OperationCard({super.key, required final Operation operation}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(operation.name),
      subtitle: operation.details.isEmpty ? null : Text(operation.details),
    ),
  );
}
