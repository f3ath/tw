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
      .where((i) => i.vehicleId == vehicle && !i.archived)
      .any((i) => status(i).status == DueStatus.incomplete);
  bool get offline => repository.offline;
  List<DueItem> due(String vehicle) => _policy.due(data, vehicle);
  DueItem status(MaintenanceItem item) => _policy.calculate(data, item);
  List<MaintenanceItem> schedule(String vehicle, bool archived) =>
      data.items.where((i) => i.vehicleId == vehicle && i.archived == archived).toList()
        ..sort((a, b) => a.description.compareTo(b.description));
  String summary(ServiceRecord s) =>
      [...s.links.map((id) => data.item(id).description), ...s.custom].join(' · ');
  Future<bool> refresh() => run(repository.refresh);
  Future<bool> archive(MaintenanceItem item) =>
      run(() => repository.archive(item.id, !item.archived));
  Future<bool> delete(String id) => run(() => repository.deleteService(id));
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
