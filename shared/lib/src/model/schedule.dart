class const Schedule({
  required final String id,
  required final String vehicleId,
  required final String name,
  required final int? intervalDistance,
  required final int? intervalMonths,
  required final String details,
  final bool isArchived = false,
});
