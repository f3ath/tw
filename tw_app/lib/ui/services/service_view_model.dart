import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/service_repo.dart';

class ServiceViewModel({required final ServiceRepo _repo, required final String _vehicleId})
    extends ChangeNotifier {
  var _isLoading = false;
  var _hasError = false;
  var _isDisposed = false;
  var _services = <Service>[];

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  List<Service> get services => _services;

  Future<void> load() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();
    try {
      _services = List.unmodifiable(await _repo.list(_vehicleId));
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
