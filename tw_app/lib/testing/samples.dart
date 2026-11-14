import 'package:shared/model.dart';

const sampleUser = User('user-0', name: 'Begelme Ashambe', email: 'begelme@example.com');

final santaFe = Vehicle(
  'vehicle-0',
  name: 'Santa Fe',
  manufactureDate: DateTime(2013),
  distanceUnit: .km,
);

final fourRunner = Vehicle(
  'vehicle-1',
  name: '4Runner',
  manufactureDate: DateTime(2022),
  distanceUnit: .mi,
);

final sampleVehicles = List<Vehicle>.unmodifiable([santaFe, fourRunner]);
