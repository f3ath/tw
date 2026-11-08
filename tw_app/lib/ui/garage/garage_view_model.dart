import 'package:flutter/material.dart';
import 'package:tw_app/app/vehicle_repo.dart';
import 'package:tw_app/domain/vehicle.dart';

class GarageViewModel({required final VehicleRepo _vehicleRepository})
    extends ChangeNotifier {
  var _isLoading = false;
  var _isDisposed = false;
  var _hasError = false;
  var _vehicles = <Vehicle>[];

  bool get isLoading => _isLoading;

  bool get hasError => _hasError;

  List<Vehicle> get vehicles => _vehicles;

  Future<void> load() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();
    try {
      _vehicles = List.unmodifiableOf(await _vehicleRepository.listVehicles());
    } on Exception {
      _hasError = true;
    } finally {
      _isLoading = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
