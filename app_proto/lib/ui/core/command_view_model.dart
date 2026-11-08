import 'package:flutter/foundation.dart';

import '../../domain/models.dart';

class CommandViewModel() extends ChangeNotifier {
  bool busy = false;
  AppFailure? failure;
  bool _disposed = false;
  Future<bool> run(Future<void> Function() command) async {
    if (busy) return false;
    busy = true;
    failure = null;
    notifyListeners();
    try {
      await command();
      return true;
    } on AppFailure catch (e) {
      failure = e;
      return false;
    } catch (_) {
      failure = const AppFailure(FailureKind.persistence, 'Something went wrong. Please retry.');
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
