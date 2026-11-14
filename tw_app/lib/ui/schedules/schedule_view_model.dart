import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/schedules_repo.dart';

class ScheduleViewModel({required final SchedulesRepo repo, required final String vehicleId})
    extends ChangeNotifier {
  var _isLoading = false;
  var _hasError = false;
  var _isDisposed = false;
  var _schedules = <Schedule>[];

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  List<Schedule> get schedules => _schedules;

  Future<void> load() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();
    try {
      _schedules = List.unmodifiable(await repo.list(vehicleId));
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
