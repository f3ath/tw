class const Vehicle(
  final String id, {
  required final String name,
  required final DateTime manufactureDate,
  required final DistanceUnit distanceUnit,
});

enum DistanceUnit() {
  mi,
  km,
}
