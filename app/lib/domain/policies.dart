import 'models.dart';

enum DueStatus() {
  overdue,
  soon,
  later,
  incomplete,
}

class const DueItem(
  final MaintenanceItem item,
  final DueStatus status,
  final DateTime? dateDue,
  final int? distanceDue,
  final int? daysRemaining,
  final int? distanceRemaining,
  final ServiceRecord? last,
) {
  String get label => switch (status) {
    DueStatus.overdue => 'Overdue',
    DueStatus.soon => 'Due soon',
    DueStatus.later => 'Later',
    DueStatus.incomplete => 'Incomplete data',
  };
  String reason(String unit) => [
    if (daysRemaining != null)
      daysRemaining == 0
          ? 'Due today'
          : daysRemaining! < 0
          ? 'Overdue by ${-daysRemaining!} days'
          : 'In $daysRemaining days',
    if (distanceRemaining != null)
      distanceRemaining == 0
          ? 'Due now: mileage limit reached'
          : distanceRemaining! < 0
          ? 'Overdue by ${-distanceRemaining!} $unit'
          : 'In $distanceRemaining $unit',
    if (distanceDue != null && distanceRemaining == null) 'Distance unavailable',
  ].join(' · ');
}

class const SchedulingPolicy() {
  DueItem calculate(Garage data, MaintenanceItem item) {
    final vehicle = data.vehicle(item.vehicleId);
    final last = data.history(vehicle.id).where((s) => s.links.contains(item.id)).firstOrNull;
    final dateDue = item.months == null
        ? null
        : calendarAdd(last?.date ?? vehicle.manufactured, item.months! * 30);
    final distanceDue = item.distance == null ? null : (last?.mileage ?? 0) + item.distance!;
    final days = dateDue == null ? null : calendarDifference(dateDue, data.asOf);
    final estimate = data.estimate(vehicle.id);
    final distance = estimate == null || distanceDue == null ? null : distanceDue - estimate;
    final status = (days != null && days <= 0) || (distance != null && distance <= 0)
        ? DueStatus.overdue
        : (days != null && days <= 30) || (distance != null && distance <= 1000)
        ? DueStatus.soon
        : distanceDue != null && estimate == null
        ? DueStatus.incomplete
        : DueStatus.later;
    return DueItem(item, status, dateDue, distanceDue, days, distance, last);
  }

  List<DueItem> due(Garage data, String vehicleId) {
    final result = data.items
        .where((i) => i.vehicleId == vehicleId && !i.archived)
        .map((i) => calculate(data, i))
        .where((d) => d.status == DueStatus.overdue || d.status == DueStatus.soon)
        .toList();
    result.sort((a, b) {
      final status = a.status.index.compareTo(b.status.index);
      if (status != 0) return status;
      final ad = a.dateDue != null && (a.status != DueStatus.overdue || a.daysRemaining! <= 0);
      final bd = b.dateDue != null && (b.status != DueStatus.overdue || b.daysRemaining! <= 0);
      if (ad != bd) return ad ? -1 : 1;
      final dimension = ad
          ? a.dateDue!.compareTo(b.dateDue!)
          : (a.distanceRemaining ?? 0).compareTo(b.distanceRemaining ?? 0);
      return dimension != 0 ? dimension : a.item.description.compareTo(b.item.description);
    });
    return List.unmodifiable(result);
  }
}

class const ValidationPolicy() {
  void vehicle(Garage data, Vehicle value, DateTime today) {
    if (value.name.trim().isEmpty) invalid('Enter a display name.', 'name');
    if (day(value.manufactured).isAfter(day(today))) {
      invalid('Manufacture date cannot be in the future.', 'date');
    }
    if (data.history(value.id).any((s) => s.date.isBefore(value.manufactured))) {
      invalid('Manufacture date must not be after existing services.', 'date');
    }
  }

  void item(MaintenanceItem value) {
    if (value.description.trim().isEmpty) invalid('Enter a description.', 'description');
    if ((value.distance == null && value.months == null) ||
        (value.distance != null && value.distance! <= 0) ||
        (value.months != null && value.months! <= 0)) {
      invalid('Enter at least one positive whole interval.', 'interval');
    }
  }

  void service(Garage data, ServiceRecord value, DateTime today) {
    final v = data.vehicle(value.vehicleId);
    if (value.date.isAfter(day(today))) invalid('Service date cannot be in the future.', 'date');
    if (value.date.isBefore(v.manufactured)) {
      invalid('Service date must be on or after manufacture date.', 'date');
    }
    if (value.mileage < 0) invalid('Enter a nonnegative whole odometer reading.', 'mileage');
    for (final other in data.history(v.id).where((s) => s.id != value.id)) {
      if ((other.date.isBefore(value.date) && other.mileage > value.mileage) ||
          (other.date.isAfter(value.date) && other.mileage < value.mileage)) {
        invalid(
          'Reading must be ${other.date.isBefore(value.date) ? 'at least' : 'at most'} ${other.mileage} ${v.unit} (${dateText(other.date)}).',
          'mileage',
        );
      }
    }
    if (value.links.toSet().length != value.links.length) {
      invalid('Select each item only once.', 'operations');
    }
    final previous = data.services.where((s) => s.id == value.id).firstOrNull;
    for (final id in value.links) {
      final item = data.item(id);
      if (item.vehicleId != v.id || (item.archived && !(previous?.links.contains(id) ?? false))) {
        invalid('Archived items cannot be selected.', 'operations');
      }
    }
  }
}

Never invalid(String message, String field) =>
    throw AppFailure(FailureKind.validation, message, field: field);
