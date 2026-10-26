import 'repositories.dart';

class const SessionUseCase(
  final AuthRepository auth,
  final VehicleMaintenanceRepository maintenance,
) {
  Future<void> restore() async {
    await auth.restore();
    if (auth.identity != null) await maintenance.open(auth.identity!);
  }

  Future<void> signIn() async {
    await auth.signIn();
    await maintenance.open(auth.identity!);
  }

  Future<void> signOut() async {
    await auth.signOut();
    await maintenance.clearAccount();
  }
}
