import '../../domain/repositories.dart';
import '../../domain/session_use_case.dart';
import '../core/command_view_model.dart';

class SessionViewModel(final AuthRepository auth, final SessionUseCase session)
    extends CommandViewModel {
  Future<bool> Function()? _retry;
  Future<bool> retry() => _retry?.call() ?? restore();

  Future<bool> _run(Future<void> Function() command) {
    _retry = () => run(command);
    return run(command);
  }

  bool restored = false;
  bool expired = false;
  void expire() {
    if (identity != null) {
      expired = true;
      notifyListeners();
    }
  }

  String? get identity => auth.identity;
  Future<bool> restore() => _run(() async {
    await session.restore();
    restored = true;
  });
  Future<bool> signIn() => _run(() async {
    if (expired) {
      await auth.signIn();
    } else {
      await session.signIn();
    }
    expired = false;
  });
  Future<bool> signOut() => _run(session.signOut);
}
