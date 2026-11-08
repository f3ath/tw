import 'dart:async';

import '../../domain/models.dart';
import '../../domain/policies.dart';
import '../../domain/repositories.dart';
import '../core/command_view_model.dart';

class GarageViewModel(final VehicleMaintenanceRepository repository) extends CommandViewModel {
  this {
    _subscription = repository.changes.listen((_) => notifyListeners());
  }
  late final StreamSubscription<Garage> _subscription;
  final _policy = const SchedulingPolicy();
  Garage get data => repository.snapshot;
  bool get hasData => data.asOf.year != 2000;
  bool incomplete(String vehicle) => data.items
      .where((i) => i.vehicleId == vehicle && !i.isArchived)
      .any((i) => status(i).status == DueStatus.incomplete);
  bool get offline => repository.offline;
  List<DueItem> due(String vehicle) => _policy.due(data, vehicle);
  DueItem status(Schedule item) => _policy.calculate(data, item);
  List<Schedule> schedule(String vehicle, bool archived) =>
      data.items.where((i) => i.vehicleId == vehicle && i.isArchived == archived).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
  String summary(Service s) =>
      data.operationsFor(s.id).map((operation) => operation.name).join(' · ');
  Future<bool> refresh() => run(repository.refresh);
  Future<bool> archive(Schedule item) => run(() => repository.archive(item.id, !item.isArchived));
  Future<bool> delete(String id) => run(() => repository.deleteService(id));
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
