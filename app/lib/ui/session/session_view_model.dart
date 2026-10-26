import '../../domain/repositories.dart';
import '../../domain/session_use_case.dart';
import '../core/command_view_model.dart';

class SessionViewModel(final AuthRepository auth, final SessionUseCase session)
    extends CommandViewModel {
  bool restored = false;
  bool expired = false;
  void expire() {
    if (identity != null) {
      expired = true;
      notifyListeners();
    }
  }

  String? get identity => auth.identity;
  Future<bool> restore() => run(() async {
    await session.restore();
    restored = true;
  });
  Future<bool> signIn() => run(() async {
    if (expired) {
      await auth.signIn();
    } else {
      await session.signIn();
    }
    expired = false;
  });
  Future<bool> signOut() => run(session.signOut);
}
