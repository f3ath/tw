class const SessionInfo({required final String id, final String? bearer, final Uri? redirect});

class const VehicleInfo({
  required final String id,
  required final String name,
  required final String manufactureDate,
});

class const ScheduleInfo({
  required final String id,
  required final String vehicleId,
  required final String name,
  required final int intervalMiles,
  required final int intervalMonths,
  required final String details,
});
