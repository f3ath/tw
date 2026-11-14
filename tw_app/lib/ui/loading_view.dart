import 'package:material_ui/material_ui.dart';

class const LoadingView({super.key, required final Key indicatorKey}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: CircularProgressIndicator(key: indicatorKey));
}
