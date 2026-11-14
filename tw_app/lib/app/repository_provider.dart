import 'package:material_ui/material_ui.dart';
import 'package:tw_app/app/vehicle_repo.dart';
import 'package:tw_app/app/schedule_repo.dart';
import 'package:tw_app/app/service_repo.dart';
import 'package:tw_app/app/operation_repo.dart';

class const RepositoryProvider({
  super.key,
  required super.child,
  required final VehicleRepo vehicleRepo,
  required final ScheduleRepo scheduleRepo,
  required final ServiceRepo serviceRepo,
  required final OperationRepo operationRepo,
}) extends InheritedWidget {
  static RepositoryProvider read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<RepositoryProvider>();
    if (scope == null) {
      throw FlutterError('RepositoryProvider must be placed above the Navigator.');
    }
    return scope;
  }

  @override
  bool updateShouldNotify(RepositoryProvider oldWidget) => false;
}
