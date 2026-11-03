import 'models.dart';

enum DueStatus() {
  overdue,
  soon,
  later,
  incomplete,
}

class const DueItem(
  final Schedule item,
  final DueStatus status,
  final DateTime? dateDue,
  final int? distanceDue,
  final int? daysRemaining,
  final int? distanceRemaining,
  final Service? last,
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
  DueItem calculate(Garage data, Schedule item) {
    final vehicle = data.vehicle(item.vehicleId);
    final last = data.history(vehicle.id).where((s) => data.completes(s.id, item.id)).firstOrNull;
    final dateDue = item.intervalMonths == null
        ? null
        : calendarAdd(last?.date ?? vehicle.manufactureDate, item.intervalMonths! * 30);
    final distanceDue = item.intervalDistance == null
        ? null
        : (last?.odometer ?? 0) + item.intervalDistance!;
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
        .where((i) => i.vehicleId == vehicleId && !i.isArchived)
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
      return dimension != 0 ? dimension : a.item.name.compareTo(b.item.name);
    });
    return List.unmodifiable(result);
  }
}

class const ValidationPolicy() {
  void vehicle(Garage data, Vehicle value, DateTime today) {
    if (value.name.trim().isEmpty) invalid('Enter a display name.', 'name');
    if (day(value.manufactureDate).isAfter(day(today))) {
      invalid('Manufacture date cannot be in the future.', 'date');
    }
    if (data.history(value.id).any((s) => s.date.isBefore(value.manufactureDate))) {
      invalid('Manufacture date must not be after existing services.', 'date');
    }
  }

  void item(Schedule value) {
    if (value.name.trim().isEmpty) invalid('Enter a description.', 'description');
    if ((value.intervalDistance == null && value.intervalMonths == null) ||
        (value.intervalDistance != null && value.intervalDistance! <= 0) ||
        (value.intervalMonths != null && value.intervalMonths! <= 0)) {
      invalid('Enter at least one positive whole interval.', 'interval');
    }
  }

  void service(
    Garage data,
    Service value,
    DateTime today, {
    Iterable<Operation> operations = const [],
  }) {
    final v = data.vehicle(value.vehicleId);
    if (value.date.isAfter(calendarAdd(day(today), 7))) {
      invalid('Service date cannot be more than seven days in the future.', 'date');
    }
    if (value.date.isBefore(v.manufactureDate)) {
      invalid('Service date must be on or after manufacture date.', 'date');
    }
    if (value.odometer < 0) invalid('Enter a nonnegative whole odometer reading.', 'mileage');
    for (final other in data.history(v.id).where((s) => s.id != value.id)) {
      if ((other.date.isBefore(value.date) && other.odometer > value.odometer) ||
          (other.date.isAfter(value.date) && other.odometer < value.odometer)) {
        invalid(
          'Reading must be ${other.date.isBefore(value.date) ? 'at least' : 'at most'} ${other.odometer} ${v.distanceUnit.name} (${dateText(other.date)}).',
          'mileage',
        );
      }
    }
    final operationIds = <String>{};
    final scheduleIds = <String>{};
    final previous = data.operationsFor(value.id);
    for (final operation in operations) {
      if (operation.serviceId != value.id ||
          !operationIds.add(operation.id) ||
          data.operations.any(
            (existing) => existing.id == operation.id && existing.serviceId != value.id,
          )) {
        invalid('Operation unavailable for this service.', 'operations');
      }
      final scheduleId = operation.scheduleId;
      if (scheduleId == null) {
        if (operation.name.trim().isEmpty) invalid('Enter an operation name.', 'operations');
        continue;
      }
      if (!scheduleIds.add(scheduleId)) invalid('Select each item only once.', 'operations');
      final item = data.item(scheduleId);
      if (item.vehicleId != v.id ||
          (item.isArchived && !previous.any((existing) => existing.scheduleId == scheduleId))) {
        invalid('Archived items cannot be selected.', 'operations');
      }
    }
  }
}

Never invalid(String message, String field) =>
    throw AppFailure(FailureKind.validation, message, field: field);
