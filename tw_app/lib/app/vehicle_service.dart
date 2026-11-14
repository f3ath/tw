import 'package:shared/model.dart';

final class VehicleService({required final Vehicle vehicle, required final Service service}) {
  this {
    if (service.vehicleId != vehicle.id) {
      throw ArgumentError.value(service, 'service', 'Service must belong to vehicle ${vehicle.id}');
    }
  }
}
