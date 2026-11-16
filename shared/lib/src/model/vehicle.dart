import 'package:shared/src/model/distance_unit.dart';

class const Vehicle(
  final String id, {
  required final String name,
  required final DateTime manufactureDate,
  required final DistanceUnit distanceUnit,
}) {
  Age ageAsOf(DateTime d) => Age.fromDuration(d.difference(manufactureDate));
}

class const Age(final int years, final int months) {
  factory fromDuration(Duration d) {
    const daysInYear = 365;
    const daysInMonth = 30;
    final days = d.inDays;
    final years = days ~/ daysInYear;
    final months = (days - years * daysInYear) ~/ daysInMonth;
    return Age(years, months);
  }
}
