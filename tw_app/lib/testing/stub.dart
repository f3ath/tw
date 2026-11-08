import 'package:tw_app/app/auth_service.dart';
import 'package:tw_app/app/vehicle_repo.dart';
import 'package:tw_app/domain/user.dart';
import 'package:tw_app/domain/vehicle.dart';

const user1 = User('user-1', name: 'Begelme Ashambe', email: 'begelme@example.com');

final vehicle1 = Vehicle(
  'vehicle-1',
  name: 'Santa Fe',
  manufactureDate: DateTime(2013),
  distanceUnit: .mi,
);
final vehicle2 = Vehicle(
  'vehicle-2',
  name: '4Runner',
  manufactureDate: DateTime(2022),
  distanceUnit: .mi,
);

final vehicles = [vehicle1, vehicle2];

class AuthServiceStub implements AuthService {
  @override
  Future<User> login({
    Duration pollInterval = const Duration(seconds: 1),
    Duration pollTimeout = const Duration(seconds: 10),
  }) async => user1;

  @override
  Future<void> logout() async {}
}

class VehicleRepoStub implements VehicleRepo {
  @override
  Future<List<Vehicle>> listVehicles() async {
    await Future<void>.delayed(Duration(seconds: 1));
    return vehicles;
  }

  @override
  Future<Vehicle> createVehicle({
    required String name,
    required DateTime manufactureDate,
    required DistanceUnit distanceUnit,
  }) async {
    return Vehicle(
      'new-id',
      name: name,
      manufactureDate: manufactureDate,
      distanceUnit: distanceUnit,
    );
  }
}
