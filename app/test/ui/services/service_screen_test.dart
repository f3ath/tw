import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:app/app/repository_provider.dart';
import 'package:shared/model.dart';
import 'package:app/testing/samples.dart' as samples;
import 'package:app/testing/stub.dart';
import 'package:app/ui/services/service_screen.dart';

import '../../robots.dart';

void main() {
  group('ServiceScreen', () {
    testWidgets('shows only the selected vehicle services after loading', (tester) async {
      final harness = Harness(vehicle: samples.santaFe, initialServices: samples.sampleServices);
      final pending = harness.repo.pauseNextList();
      await harness.pumpScreen(tester);

      expect(find.byKey(ServiceScreen.loadingIndicatorKey), findsOneWidget);
      expect(find.text(samples.santaFe.name), findsOneWidget);
      expect(find.byKey(ServiceScreen.serviceKey(samples.santaFeOilService.id)), findsNothing);

      pending.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(ServiceScreen.loadingIndicatorKey), findsNothing);
      expectServicesVisible(tester, [samples.santaFeOilService]);
      expect(find.text('120,000 km'), findsOneWidget);
      expect(find.byKey(ServiceScreen.serviceKey(samples.fourRunnerTireService.id)), findsNothing);
    });

    testWidgets('rebuilding does not reload services', (tester) async {
      final harness = Harness(vehicle: samples.santaFe, initialServices: samples.sampleServices);
      await harness.pumpLoadedScreen(tester);
      expect(harness.repo.listCalls, equals(1));

      await harness.pumpLoadedScreen(tester);

      expect(harness.repo.listCalls, equals(1));
      expectServicesVisible(tester, [samples.santaFeOilService]);
    });

    testWidgets('shows an empty state when the vehicle has no services', (tester) async {
      final harness = Harness(
        vehicle: samples.santaFe,
        initialServices: [samples.fourRunnerTireService],
      );
      await harness.pumpLoadedScreen(tester);

      expect(find.byKey(ServiceScreen.emptyTextKey), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byKey(ServiceScreen.loadingIndicatorKey), findsNothing);
    });

    testWidgets('failed loading shows an error and can be retried', (tester) async {
      final harness = Harness(vehicle: samples.fourRunner, initialServices: samples.sampleServices);
      final services = ServiceRobot(tester);
      final pending = harness.repo.pauseNextList();
      await harness.pumpScreen(tester);

      pending.completeError(Exception('Network error'));
      await tester.pumpAndSettle();

      expect(find.byKey(ServiceScreen.errorTextKey), findsOneWidget);
      expect(find.byKey(ServiceScreen.loadingIndicatorKey), findsNothing);
      expect(find.byKey(ServiceScreen.emptyTextKey), findsNothing);

      final retry = harness.repo.pauseNextList();
      await services.tapRetry();
      expect(find.byKey(ServiceScreen.loadingIndicatorKey), findsOneWidget);

      retry.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(ServiceScreen.errorTextKey), findsNothing);
      expectServicesVisible(tester, [samples.fourRunnerTireService]);
      expect(find.text('45,000 mi'), findsOneWidget);
      expect(services.findServiceCard(samples.santaFeOilService.id), findsNothing);
      expect(harness.repo.listCalls, equals(2));
    });

    for (final vehicle in samples.sampleVehicles) {
      testWidgets('New Service opens the form for ${vehicle.name} and Back preserves the list', (
        tester,
      ) async {
        final harness = Harness(vehicle: vehicle, initialServices: samples.sampleServices);
        final services = ServiceRobot(tester);
        final form = ServiceFormRobot(tester);
        await harness.pumpLoadedScreen(tester);

        await services.tapNewService();

        expect(findServiceFormScreen, findsOneWidget);
        expect(findServiceScreen, findsNothing);
        expect(find.text(vehicle.name), findsOneWidget);
        expect(form.distanceUnitLabel, equals(vehicle.distanceUnit.name));
        expect(form.saveButton.enabled, isTrue);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(findServiceFormScreen, findsNothing);
        expect(findServiceScreen, findsOneWidget);
        expectServicesVisible(
          tester,
          samples.sampleServices.where((service) => service.vehicleId == vehicle.id).toList(),
        );
        expect(harness.repo.listCalls, equals(1));
      });
    }

    testWidgets('successful creation refreshes the selected vehicle history', (tester) async {
      final harness = Harness(vehicle: samples.santaFe, initialServices: samples.sampleServices);
      final services = ServiceRobot(tester);
      final form = ServiceFormRobot(tester);
      await harness.pumpLoadedScreen(tester);
      await services.tapNewService();
      await form.enterOdometer('123456');
      await form.enterDetails('New service');

      await form.saveForm(pump: .settle);

      expect(findServiceFormScreen, findsNothing);
      expect(findServiceScreen, findsOneWidget);
      expect(harness.repo.listCalls, equals(2));
      final created = harness.repo.services.values.singleWhere(
        (service) => service.details == 'New service',
      );
      expect(created.vehicleId, equals(samples.santaFe.id));
      expect(created.odometer, equals(123456));
      expectServicesVisible(tester, [samples.santaFeOilService, created]);
      expect(services.findServiceCard(samples.fourRunnerTireService.id), findsNothing);
    });

    group('Operations', () {
      for (final service in samples.sampleServices) {
        testWidgets('tapping ${service.id} opens its operations and Back preserves history', (
          tester,
        ) async {
          final vehicle = samples.sampleVehicles.singleWhere(
            (vehicle) => vehicle.id == service.vehicleId,
          );
          final otherService = Service(
            'other-service',
            vehicleId: vehicle.id,
            date: DateTime(2020),
            odometer: 1000,
            details: 'Other service',
          );
          final otherOperation = Operation(
            'other-operation',
            serviceId: otherService.id,
            name: 'Other work',
            details: '',
          );
          final harness = Harness(
            vehicle: vehicle,
            initialServices: [otherService, ...samples.sampleServices],
            initialOperations: [otherOperation, ...samples.sampleOperations],
          );
          final services = ServiceRobot(tester);
          final operations = OperationRobot(tester);
          await harness.pumpLoadedScreen(tester);

          await services.tapServiceCard(service.id);

          expect(findOperationScreen, findsOneWidget);
          expect(findServiceScreen, findsNothing);
          expect(operations.vehicleNameText.data, equals(vehicle.name));
          final localizations = MaterialLocalizations.of(
            tester.element(operations.findServiceDateText),
          );
          expect(
            operations.serviceDateText.data,
            equals(localizations.formatShortDate(service.date)),
          );
          for (final operation in samples.sampleOperations) {
            expect(
              operations.findOperationCard(operation.id),
              operation.serviceId == service.id ? findsOneWidget : findsNothing,
            );
          }
          expect(operations.findOperationCard(otherOperation.id), findsNothing);
          expect(harness.operationRepo.listCalls, equals(1));
          expect(harness.repo.listCalls, equals(1));

          await tester.pageBack();
          await tester.pumpAndSettle();

          expect(findOperationScreen, findsNothing);
          expect(findServiceScreen, findsOneWidget);
          expectServicesVisible(tester, [otherService, service]);
          expect(harness.repo.listCalls, equals(1));
          expect(harness.operationRepo.listCalls, equals(1));
        });
      }
    });

    group('Editing', () {
      final inspection = Service(
        'inspection',
        vehicleId: samples.santaFe.id,
        date: DateTime(2026, 11, 3),
        odometer: 121000,
        details: 'Check brakes and tires',
      );

      testWidgets('Edit opens the selected service prefilled and Back preserves history', (
        tester,
      ) async {
        final harness = Harness(
          vehicle: samples.santaFe,
          initialServices: [...samples.sampleServices, inspection],
        );
        final services = ServiceRobot(tester);
        final form = ServiceFormRobot(tester);
        await harness.pumpLoadedScreen(tester);

        await services.tapServiceMenuEdit(inspection.id);

        expect(findServiceFormScreen, findsOneWidget);
        expect(findServiceScreen, findsNothing);
        expect(find.text('Edit Service'), findsOneWidget);
        expect(form.selectedDate, equals(inspection.date));
        expect(form.odometer, equals(inspection.odometer.toString()));
        expect(form.details, equals(inspection.details));
        expect(form.distanceUnitLabel, equals(samples.santaFe.distanceUnit.name));
        await form.enterDetails('Unsaved edit');

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(findServiceFormScreen, findsNothing);
        expect(findServiceScreen, findsOneWidget);
        expectServicesVisible(tester, [samples.santaFeOilService, inspection]);
        expect(harness.repo.listCalls, equals(1));
        expect(harness.repo.updateCalls, equals(0));
        expect(harness.repo.services[inspection.id], same(inspection));
      });

      testWidgets('saving edits reloads history and changes only the selected service', (
        tester,
      ) async {
        final harness = Harness(
          vehicle: samples.santaFe,
          initialServices: [...samples.sampleServices, inspection],
        );
        final services = ServiceRobot(tester);
        final form = ServiceFormRobot(tester);
        await harness.pumpLoadedScreen(tester);
        await services.tapServiceMenuEdit(inspection.id);
        await form.selectDayAndConfirm('13');
        await form.enterOdometer('123456');
        await form.enterDetails('Updated inspection');
        final refresh = harness.repo.pauseNextList();

        await form.saveForm();
        await tester.pump(const Duration(seconds: 1));

        expect(findServiceFormScreen, findsNothing);
        expect(find.byKey(ServiceScreen.loadingIndicatorKey), findsOneWidget);
        expect(harness.repo.listCalls, equals(2));
        refresh.complete();
        await tester.pumpAndSettle();

        final updated = harness.repo.services[inspection.id]!;
        expect(harness.repo.updateCalls, equals(1));
        expect(harness.repo.services, hasLength(3));
        expect(updated.vehicleId, equals(inspection.vehicleId));
        expect(updated.date, equals(DateTime(2026, 11, 13)));
        expect(updated.odometer, equals(123456));
        expect(updated.details, equals('Updated inspection'));
        expectServicesVisible(tester, [samples.santaFeOilService, updated]);
        final updatedCard = services.findServiceCard(inspection.id);
        expect(find.descendant(of: updatedCard, matching: find.text('123,456 km')), findsOneWidget);
        expect(
          find.descendant(of: updatedCard, matching: find.text(inspection.details)),
          findsNothing,
        );
        expect(
          harness.repo.services[samples.santaFeOilService.id],
          same(samples.santaFeOilService),
        );
        expect(
          harness.repo.services[samples.fourRunnerTireService.id],
          same(samples.fourRunnerTireService),
        );
        expect(services.findServiceCard(samples.fourRunnerTireService.id), findsNothing);
      });

      testWidgets('failed edits keep the form open and refresh history only after retry succeeds', (
        tester,
      ) async {
        final service = samples.fourRunnerTireService;
        final harness = Harness(
          vehicle: samples.fourRunner,
          initialServices: samples.sampleServices,
        );
        final services = ServiceRobot(tester);
        final form = ServiceFormRobot(tester);
        await harness.pumpLoadedScreen(tester);
        await services.tapServiceMenuEdit(service.id);
        await form.enterDetails('Updated tire service');
        final pending = harness.repo.pauseNextUpdate();

        await form.saveForm();
        pending.completeError(Exception('Network error'));
        await tester.pumpAndSettle();

        expect(findServiceFormScreen, findsOneWidget);
        expect(form.findSaveError, findsOneWidget);
        expect(form.details, equals('Updated tire service'));
        expect(harness.repo.listCalls, equals(1));
        expect(harness.repo.services[service.id], same(service));

        await form.saveForm(pump: .settle);

        expect(findServiceFormScreen, findsNothing);
        expect(findServiceScreen, findsOneWidget);
        expect(harness.repo.listCalls, equals(2));
        expect(harness.repo.updateCalls, equals(2));
        expectServicesVisible(tester, [harness.repo.services[service.id]!]);
        expect(find.text('45,000 mi'), findsOneWidget);
        expect(find.text('Updated tire service'), findsOneWidget);
      });
    });

    group('Deletion', () {
      for (final dismiss in [false, true]) {
        testWidgets(
          '${dismiss ? 'dismissing' : 'cancelling'} confirmation preserves history without a request',
          (tester) async {
            final vehicle = dismiss ? samples.santaFe : samples.fourRunner;
            final service = dismiss ? samples.santaFeOilService : samples.fourRunnerTireService;
            final harness = Harness(vehicle: vehicle, initialServices: samples.sampleServices);
            final services = ServiceRobot(tester);
            await harness.pumpLoadedScreen(tester);

            await services.tapServiceMenuDelete(service.id);

            expect(services.findDeleteConfirmation, findsOneWidget);
            expect(services.deleteDialog.service, same(service));
            expect(services.deleteDialog.distanceUnit, equals(vehicle.distanceUnit));
            expect(harness.repo.deleteCalls, equals(0));
            if (dismiss) {
              await services.dismissServiceDeletion();
            } else {
              await services.cancelServiceDeletion();
            }

            expect(services.findDeleteConfirmation, findsNothing);
            expectServicesVisible(tester, [service]);
            expect(harness.repo.services, hasLength(2));
            expect(harness.repo.services[service.id], same(service));
            expect(harness.repo.deleteCalls, equals(0));
            expect(harness.repo.listCalls, equals(1));
          },
        );
      }

      testWidgets('confirmed deletion removes only the selected service and reloads history', (
        tester,
      ) async {
        final inspection = Service(
          'inspection',
          vehicleId: samples.santaFe.id,
          date: DateTime(2026, 11, 3),
          odometer: 121000,
          details: 'Inspection',
        );
        final harness = Harness(
          vehicle: samples.santaFe,
          initialServices: [...samples.sampleServices, inspection],
        );
        final services = ServiceRobot(tester);
        final pending = harness.repo.pauseNextDelete();
        await harness.pumpLoadedScreen(tester);
        await services.tapServiceMenuDelete(inspection.id);

        await services.confirmServiceDeletion();

        expect(harness.repo.deleteCalls, equals(1));
        expect(harness.repo.services, hasLength(3));
        expect(harness.repo.listCalls, equals(1));
        final refresh = harness.repo.pauseNextList();
        pending.complete();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(services.findDeleteConfirmation, findsNothing);
        expect(harness.repo.listCalls, equals(2));
        expect(find.byKey(ServiceScreen.loadingIndicatorKey), findsOneWidget);
        refresh.complete();
        await tester.pumpAndSettle();

        expect(services.findServiceCard(inspection.id), findsNothing);
        expectServicesVisible(tester, [samples.santaFeOilService]);
        expect(harness.repo.services, hasLength(2));
        expect(
          harness.repo.services[samples.santaFeOilService.id],
          same(samples.santaFeOilService),
        );
        expect(
          harness.repo.services[samples.fourRunnerTireService.id],
          same(samples.fourRunnerTireService),
        );
        expect(services.findServiceCard(samples.fourRunnerTireService.id), findsNothing);
        expect(services.findDeleteError, findsNothing);
      });

      testWidgets('deleting the final service shows the empty state', (tester) async {
        final service = samples.santaFeOilService;
        final harness = Harness(vehicle: samples.santaFe, initialServices: [service]);
        final services = ServiceRobot(tester);
        await harness.pumpLoadedScreen(tester);
        await services.tapServiceMenuDelete(service.id);

        await services.confirmServiceDeletion(pump: .settle);

        expect(services.findDeleteConfirmation, findsNothing);
        expect(findServiceScreen, findsOneWidget);
        expect(harness.repo.services, isEmpty);
        expect(services.findServiceCard(service.id), findsNothing);
        expect(find.byKey(ServiceScreen.emptyTextKey), findsOneWidget);
        expect(harness.repo.deleteCalls, equals(1));
        expect(harness.repo.listCalls, equals(2));
      });

      for (final deleted in [false, true]) {
        testWidgets('deletion error reconciles a ${deleted ? 'deleted' : 'retained'} service', (
          tester,
        ) async {
          final service = samples.santaFeOilService;
          final harness = Harness(vehicle: samples.santaFe, initialServices: [service]);
          final services = ServiceRobot(tester);
          final pending = harness.repo.pauseNextDelete();
          await harness.pumpLoadedScreen(tester);
          await services.tapServiceMenuDelete(service.id);
          await services.confirmServiceDeletion();
          expect(harness.repo.listCalls, equals(1));

          if (deleted) {
            // Simulate a committed deletion whose response was lost.
            harness.repo.services.remove(service.id);
          }
          pending.completeError(Exception('Network error'));
          await tester.pumpAndSettle();

          expect(services.findDeleteError, findsOneWidget);
          expect(harness.repo.deleteCalls, equals(1));
          expect(harness.repo.listCalls, equals(2));
          if (deleted) {
            expect(services.findServiceCard(service.id), findsNothing);
            expect(find.byKey(ServiceScreen.emptyTextKey), findsOneWidget);
          } else {
            expectServicesVisible(tester, [service]);
            expect(find.byKey(ServiceScreen.emptyTextKey), findsNothing);
          }
        });
      }

      for (final fails in [false, true]) {
        testWidgets('can leave while deletion later ${fails ? 'fails' : 'succeeds'}', (
          tester,
        ) async {
          final service = samples.santaFeOilService;
          final harness = Harness(vehicle: samples.santaFe, initialServices: [service]);
          final services = ServiceRobot(tester);
          final pending = harness.repo.pauseNextDelete();
          await harness.pumpLoadedScreen(tester);
          await services.tapServiceMenuDelete(service.id);
          await services.confirmServiceDeletion();

          await tester.pumpWidget(const SizedBox());
          if (fails) {
            pending.completeError(Exception('Network error'));
          } else {
            pending.complete();
          }
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(harness.repo.deleteCalls, equals(1));
          expect(harness.repo.listCalls, equals(1));
        });
      }
    });

    for (final fails in [false, true]) {
      testWidgets('can leave while a request later ${fails ? 'fails' : 'succeeds'}', (
        tester,
      ) async {
        final harness = Harness(vehicle: samples.santaFe);
        final pending = harness.repo.pauseNextList();
        await harness.pumpScreen(tester);

        await tester.pumpWidget(const SizedBox());
        if (fails) {
          pending.completeError(Exception('Network error'));
        } else {
          pending.complete();
        }
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    }
  });
}

void expectServicesVisible(WidgetTester tester, List<Service> services) {
  for (final service in services) {
    final card = find.byKey(ServiceScreen.serviceKey(service.id));
    expect(card, findsOneWidget);
    final localizations = MaterialLocalizations.of(tester.element(card));
    expect(
      find.descendant(of: card, matching: find.text(localizations.formatShortDate(service.date))),
      findsOneWidget,
    );
    if (service.details.isNotEmpty) {
      expect(find.descendant(of: card, matching: find.text(service.details)), findsOneWidget);
    }
  }
}

class Harness({
  required final Vehicle vehicle,
  Iterable<Service> initialServices = const [],
  Iterable<Operation> initialOperations = const [],
}) {
  final repo = InMemoryServiceRepo(initialServices: initialServices);
  final operationRepo = InMemoryOperationRepo(initialOperations: initialOperations);

  Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
    RepositoryProvider(
      vehicleRepo: InMemoryVehicleRepo(),
      scheduleRepo: InMemoryScheduleRepo(),
      serviceRepo: repo,
      operationRepo: operationRepo,
      child: MaterialApp(home: ServiceScreen(vehicle: vehicle)),
    ),
  );

  Future<void> pumpLoadedScreen(WidgetTester tester) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();
  }
}
