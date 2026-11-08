import 'package:app/data/repositories/api_auth_repository.dart';
import 'package:app/data/repositories/api_maintenance_repository.dart';
import 'package:app/data/repositories/local_repositories.dart';
import 'package:app/data/services/api_auth_service.dart';
import 'package:app/data/services/api_maintenance_service.dart';
import 'package:app/data/services/oauth_window.dart';
import 'package:app/domain/models.dart';
import 'package:app/domain/session_use_case.dart';
import 'package:app/ui/forms/form_view_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fakes.dart';

class TestOAuthWindow(final String email) implements OAuthWindow {
  @override
  bool get isClosed => false;

  @override
  Future<void> navigate(Uri uri) async {
    expect(uri.host, 'example.com', reason: 'Start the server with INSTANCE_TYPE=test.');
    final response = await http.get(
      Uri.http('localhost:8080', '/auth/google/callback', {
        'nonce': uri.queryParameters['nonce']!,
        'email': email,
        'name': 'App integration test',
      }),
    );
    expect(response.statusCode, 200);
  }

  @override
  void close() {}
}

void main() {
  test('real API supports forms, operation edits, restore and sign-out', () async {
    final persistence = MemoryStorage();
    final settings = LocalSettingsRepository(persistence);
    var disconnected = false;
    var expirations = 0;
    final email = 'app-${DateTime.now().microsecondsSinceEpoch}@example.com';
    ApiAuthService authService() => ApiAuthService(
      settings,
      persistence,
      windowFactory: () => TestOAuthWindow(email),
      pollInterval: Duration.zero,
      onAuthenticationExpired: () => expirations++,
      httpClientFactory: () => disconnected
          ? MockClient((_) async => throw http.ClientException('Test connection unavailable'))
          : http.Client(),
    );
    final apiAuth = authService();
    final auth = ApiAuthRepository(apiAuth);
    final repository = ApiMaintenanceRepository(
      ApiMaintenanceService(apiAuth),
      persistence,
      clock: DateTime.now,
    );
    final session = SessionUseCase(auth, repository);
    await session.signIn();
    addTearDown(() async {
      await repository.refresh();
      for (final vehicle in repository.snapshot.vehicles) {
        await apiAuth.withClient((client) => client.deleteVehicle(vehicle.id));
      }
      await session.signOut();
    });
    expect(repository.snapshot.vehicles, isEmpty);

    final vehicleForm = VehicleFormViewModel(repository, day(DateTime.now()))
      ..name = 'API car'
      ..date = '2020-01-02'
      ..odometer = '100'
      ..distanceUnit = DistanceUnit.km;
    final draftId = vehicleForm.id;
    expect(await vehicleForm.save(), isTrue, reason: vehicleForm.failure?.message);
    expect(vehicleForm.id, isNot(draftId));
    final vehicleId = vehicleForm.id;
    final vehicle = repository.snapshot.vehicle(vehicleId);
    expect(vehicle.distanceUnit, DistanceUnit.km);
    expect(repository.snapshot.history(vehicleId).single.odometer, 100);
    final vehicleEdit = VehicleFormViewModel(repository, day(DateTime.now()), original: vehicle)
      ..name = 'Renamed car';
    expect(await vehicleEdit.save(), isTrue, reason: vehicleEdit.failure?.message);
    expect(repository.snapshot.vehicle(vehicleId).name, 'Renamed car');

    final itemForm = ItemFormViewModel(repository, vehicle)
      ..name = 'Oil'
      ..details = 'Synthetic'
      ..intervalDistance = '5000';
    expect(await itemForm.save(), isTrue, reason: itemForm.failure?.message);
    final scheduleId = itemForm.id;
    final form = ServiceFormViewModel(repository, vehicle, day(DateTime.now()))..odometer = '150';
    form.toggle(scheduleId, true);
    form.addCustom();
    form.custom.single
      ..name = 'Inspection'
      ..details = 'All good';
    form.addCustom();
    expect(await form.save(), isTrue, reason: form.failure?.message);
    final serviceId = form.id;
    final original = repository.snapshot.service(serviceId);
    final operations = repository.snapshot.operationsFor(serviceId);
    expect(operations, hasLength(2));
    expect(operations.singleWhere((op) => op.scheduleId != null).details, 'Synthetic');

    final scheduleEdit = ItemFormViewModel(
      repository,
      vehicle,
      original: repository.snapshot.item(scheduleId),
    )..details = 'New specification';
    expect(await scheduleEdit.save(), isTrue, reason: scheduleEdit.failure?.message);
    expect(
      repository.snapshot
          .operationsFor(serviceId)
          .singleWhere((op) => op.scheduleId != null)
          .details,
      'New specification',
    );
    await repository.archive(scheduleId, true);
    final edit = ServiceFormViewModel(repository, vehicle, day(DateTime.now()), original: original)
      ..odometer = '200';
    edit.custom.single.details = 'Updated';
    expect(await edit.save(), isTrue, reason: edit.failure?.message);
    expect(
      repository.snapshot.operationsFor(serviceId).map((op) => op.id),
      unorderedEquals(operations.map((op) => op.id)),
    );
    expect(
      repository.snapshot
          .operationsFor(serviceId)
          .singleWhere((op) => op.scheduleId == null)
          .details,
      'Updated',
    );

    final stale = ServiceFormViewModel(
      repository,
      vehicle,
      day(DateTime.now()),
      original: original,
    );
    expect(await stale.save(), isFalse);
    expect(stale.failure?.kind, FailureKind.conflict);
    final removal = ServiceFormViewModel(
      repository,
      vehicle,
      day(DateTime.now()),
      original: repository.snapshot.service(serviceId),
    );
    removal.custom.clear();
    removal.toggle(scheduleId, false);
    expect(await removal.save(), isTrue, reason: removal.failure?.message);
    expect(repository.snapshot.operationsFor(serviceId), isEmpty);

    final restoredAuth = authService();
    await restoredAuth.restore();
    final restored = ApiMaintenanceRepository(
      ApiMaintenanceService(restoredAuth),
      persistence,
      clock: DateTime.now,
    );
    await restored.open(email);
    expect(restored.snapshot.service(serviceId).odometer, 200);
    expect(restored.snapshot.item(scheduleId).isArchived, isTrue);
    disconnected = true;
    final offline = ApiMaintenanceRepository(
      ApiMaintenanceService(restoredAuth),
      persistence,
      clock: DateTime.now,
    );
    await offline.open(email);
    expect(offline.offline, isTrue);
    expect(offline.snapshot.service(serviceId).odometer, 200);
    expect(offline.snapshot.asOf, restored.snapshot.asOf);
    await expectLater(offline.deleteService(serviceId), throwsA(isA<AppFailure>()));
    disconnected = false;
    await offline.refresh();
    expect(offline.offline, isFalse);

    // Revoke the shared session through another client; retain the running draft.
    final retained = ServiceFormViewModel(repository, vehicle, day(DateTime.now()))
      ..odometer = '250';
    retained.changed();
    await restoredAuth.withClient((client) => client.deleteCurrentSession());
    expect(await retained.save(), isFalse);
    expect(retained.failure?.kind, FailureKind.authentication);
    expect(expirations, 1);
    expect(retained.odometer, '250');
    expect(retained.dirty, isTrue);
    await session.signIn();
    expect(await retained.save(), isTrue, reason: retained.failure?.message);

    await repository.deleteService(serviceId);
    await repository.refresh();
    expect(repository.snapshot.services.any((service) => service.id == serviceId), isFalse);
    expect(repository.snapshot.operationsFor(serviceId), isEmpty);

    await session.signOut();
    expect(repository.snapshot.vehicles, isEmpty);
    expect(persistence.values.keys.where((key) => key.startsWith('api.garage.')), isEmpty);
    await session.signIn();
    expect(repository.snapshot.vehicle(vehicleId).name, 'Renamed car');
  });
}
