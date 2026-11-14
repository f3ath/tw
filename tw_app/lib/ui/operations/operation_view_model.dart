import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/operation_repo.dart';

class OperationViewModel({required final OperationRepo _repo, required final String _serviceId})
    extends ChangeNotifier {
  var _isLoading = false;
  var _hasError = false;
  var _isDisposed = false;
  var _operations = <Operation>[];

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  List<Operation> get operations => _operations;

  Future<void> load() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();
    try {
      _operations = List.unmodifiable(await _repo.list(_serviceId));
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
