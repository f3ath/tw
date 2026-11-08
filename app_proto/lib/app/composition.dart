import '../data/repositories/api_auth_repository.dart';
import '../data/repositories/api_maintenance_repository.dart';
import '../data/services/api_maintenance_service.dart';
import '../data/services/api_auth_service.dart';
import '../data/repositories/local_repositories.dart';
import '../data/services/services.dart';
import '../domain/models.dart';
import '../domain/repositories.dart';
import '../domain/session_use_case.dart';
import '../ui/session/session_view_model.dart';
import '../ui/garage/garage_view_model.dart';
import '../ui/forms/form_view_models.dart';

class Composition({
  required final AuthRepository auth,
  required final VehicleMaintenanceRepository maintenance,
  required final SettingsRepository settings,
  required final DateTime Function() clock,
  final DemoSimulation? demo,
}) {
  this {
    session = SessionViewModel(auth, SessionUseCase(auth, maintenance));
    garage = GarageViewModel(maintenance);
  }
  factory local() {
    final persistence = PreferencesPersistenceService.platform();
    final settings = LocalSettingsRepository(persistence);
    late final Composition composition;
    final api = ApiAuthService(
      settings,
      persistence,
      onAuthenticationExpired: () => composition.session.expire(),
    );
    composition = Composition(
      auth: ApiAuthRepository(api),
      maintenance: ApiMaintenanceRepository(
        ApiMaintenanceService(api),
        persistence,
        clock: DateTime.now,
      ),
      settings: settings,
      clock: DateTime.now,
    );
    return composition;
  }

  late final SessionViewModel session;
  late final GarageViewModel garage;
  VehicleFormViewModel vehicleForm([Vehicle? vehicle]) =>
      VehicleFormViewModel(maintenance, day(clock()), original: vehicle);
  ItemFormViewModel itemForm(Vehicle vehicle, [Schedule? item]) =>
      ItemFormViewModel(maintenance, vehicle, original: item);
  ServiceFormViewModel serviceForm(Vehicle vehicle, [Service? service]) =>
      ServiceFormViewModel(maintenance, vehicle, day(clock()), original: service);
  SettingsViewModel settingsForm() => SettingsViewModel(settings);
  void toggleOffline() {
    final control = demo;
    if (control != null) {
      control.offline = !control.offline;
      garage.refresh();
    }
  }

  void toggleSaveFailure() {
    final control = demo;
    if (control != null) {
      control.failWrites = !control.failWrites;
    }
  }

  void dispose() {
    session.dispose();
    garage.dispose();
  }
}
