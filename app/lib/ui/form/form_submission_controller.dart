import 'package:material_ui/material_ui.dart';

sealed class const SubmissionResult<T>();

final class const SubmissionSuccess<T>(final T value) extends SubmissionResult<T>;

final class const SubmissionFailure<T>() extends SubmissionResult<T>;

final class const SubmissionIgnored<T>() extends SubmissionResult<T>;

class FormSubmissionController extends ChangeNotifier {
  var _isSubmitting = false;
  var _isDisposed = false;

  bool get isSubmitting => _isSubmitting;

  Future<SubmissionResult<T>> submit<T>(Future<T> Function() persist) async {
    if (_isSubmitting || _isDisposed) return SubmissionIgnored<T>();
    _isSubmitting = true;
    notifyListeners();
    try {
      return SubmissionSuccess(await persist());
    } on Exception {
      return SubmissionFailure<T>();
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
