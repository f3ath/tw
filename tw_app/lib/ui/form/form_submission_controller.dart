import 'package:material_ui/material_ui.dart';

class FormSubmissionController extends ChangeNotifier {
  var _isSubmitting = false;
  var _hasError = false;
  var _isDisposed = false;

  bool get isSubmitting => _isSubmitting;
  bool get hasError => _hasError;

  Future<bool> submit(Future<void> Function() persist) async {
    if (_isSubmitting || _isDisposed) return false;
    _isSubmitting = true;
    _hasError = false;
    notifyListeners();
    try {
      await persist();
      return true;
    } on Exception {
      _hasError = true;
      return false;
    } finally {
      _isSubmitting = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
