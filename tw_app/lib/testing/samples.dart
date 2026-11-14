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

final oilChange = Schedule(
  id: 'schedule-0',
  vehicleId: santaFe.id,
  name: 'Oil change',
  intervalDistance: 10000,
  intervalMonths: 12,
  details: 'Replace engine oil and filter',
);

final tireRotation = Schedule(
  id: 'schedule-1',
  vehicleId: fourRunner.id,
  name: 'Tire rotation',
  intervalDistance: 5000,
  intervalMonths: 6,
  details: '',
);

final sampleSchedules = List<Schedule>.unmodifiable([oilChange, tireRotation]);

final santaFeOilService = Service(
  'service-0',
  vehicleId: santaFe.id,
  date: DateTime(2026, 11, 1),
  odometer: 120000,
  details: 'Changed engine oil and filter',
);

final fourRunnerTireService = Service(
  'service-1',
  vehicleId: fourRunner.id,
  date: DateTime(2026, 10, 15),
  odometer: 45000,
  details: '',
);

final sampleServices = List<Service>.unmodifiable([santaFeOilService, fourRunnerTireService]);
