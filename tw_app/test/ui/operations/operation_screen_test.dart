import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tw_app/app/repository_provider.dart';
import 'package:tw_app/app/vehicle_service.dart';
import 'package:shared/model.dart';
import 'package:tw_app/testing/samples.dart' as samples;
import 'package:tw_app/testing/stub.dart';
import 'package:tw_app/ui/operations/operation_screen.dart';

import '../../robots.dart';

void main() {
  group('OperationScreen', () {
    for (final service in samples.sampleServices) {
      testWidgets('shows only ${service.id} operations after loading', (tester) async {
        final vehicle = samples.sampleVehicles.singleWhere(
          (vehicle) => vehicle.id == service.vehicleId,
        );
        final harness = Harness(
          vehicle: vehicle,
          service: service,
          initialOperations: samples.sampleOperations,
        );
        final operations = OperationRobot(tester);
        final pending = harness.repo.pauseNextList();
        await harness.pumpScreen(tester);

        expect(find.byKey(OperationScreen.loadingIndicatorKey), findsOneWidget);
        expect(find.byKey(OperationScreen.emptyTextKey), findsNothing);
        expect(find.byType(ListTile), findsNothing);
        final localizations = MaterialLocalizations.of(tester.element(findOperationScreen));
        expect(operations.vehicleNameText.data, equals(vehicle.name));
        expect(
          operations.serviceDateText.data,
          equals(localizations.formatShortDate(service.date)),
        );
        expect(
          tester.getTopLeft(operations.findServiceDateText).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(operations.findVehicleNameText).dy),
        );

        pending.complete();
        await tester.pumpAndSettle();

        expect(find.byKey(OperationScreen.loadingIndicatorKey), findsNothing);
        expect(find.byKey(OperationScreen.errorTextKey), findsNothing);
        expect(find.byKey(OperationScreen.emptyTextKey), findsNothing);
        expectOperationsVisible(
          tester,
          samples.sampleOperations.where((operation) => operation.serviceId == service.id),
        );
        for (final other in samples.sampleOperations.where(
          (operation) => operation.serviceId != service.id,
        )) {
          expect(operations.findOperationCard(other.id), findsNothing);
        }
        expect(harness.repo.listCalls, equals(1));
      });
    }

    for (final initialOperations in [
      <Operation>[],
      [samples.tireRotationOperation],
    ]) {
      testWidgets('shows an empty state with ${initialOperations.length} unrelated operations', (
        tester,
      ) async {
        final harness = Harness(
          vehicle: samples.santaFe,
          service: samples.santaFeOilService,
          initialOperations: initialOperations,
        );
        await harness.pumpLoadedScreen(tester);

        expect(find.byKey(OperationScreen.emptyTextKey), findsOneWidget);
        expect(find.byKey(OperationScreen.loadingIndicatorKey), findsNothing);
        expect(find.byKey(OperationScreen.errorTextKey), findsNothing);
        expect(find.byType(ListTile), findsNothing);
      });
    }

    testWidgets('failed loading shows an error and can be retried', (tester) async {
      final harness = Harness(
        vehicle: samples.santaFe,
        service: samples.santaFeOilService,
        initialOperations: samples.sampleOperations,
      );
      final operations = OperationRobot(tester);
      final pending = harness.repo.pauseNextList();
      await harness.pumpScreen(tester);

      pending.completeError(Exception('Network error'));
      await tester.pumpAndSettle();

      expect(find.byKey(OperationScreen.errorTextKey), findsOneWidget);
      expect(find.byKey(OperationScreen.loadingIndicatorKey), findsNothing);
      expect(find.byKey(OperationScreen.emptyTextKey), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      final retry = harness.repo.pauseNextList();

      await operations.tapRetry();

      expect(find.byKey(OperationScreen.loadingIndicatorKey), findsOneWidget);
      expect(find.byKey(OperationScreen.errorTextKey), findsNothing);
      retry.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(OperationScreen.errorTextKey), findsNothing);
      expect(find.byKey(OperationScreen.loadingIndicatorKey), findsNothing);
      expectOperationsVisible(tester, [
        samples.oilChangeOperation,
        samples.brakeInspectionOperation,
      ]);
      expect(operations.findOperationCard(samples.tireRotationOperation.id), findsNothing);
      expect(harness.repo.listCalls, equals(2));
    });

    testWidgets('rebuilding does not reload operations', (tester) async {
      final harness = Harness(
        vehicle: samples.fourRunner,
        service: samples.fourRunnerTireService,
        initialOperations: samples.sampleOperations,
      );
      await harness.pumpLoadedScreen(tester);
      expect(harness.repo.listCalls, equals(1));

      await harness.pumpLoadedScreen(tester);

      expect(harness.repo.listCalls, equals(1));
      expectOperationsVisible(tester, [samples.tireRotationOperation]);
    });

    testWidgets('shows newly recorded scheduled work for the selected service', (tester) async {
      final harness = Harness(vehicle: samples.santaFe, service: samples.santaFeOilService);

      await harness.repo.createFromSchedule(
        samples.santaFeOilService.id,
        scheduleId: samples.oilChange.id,
      );
      await harness.pumpLoadedScreen(tester);

      final operation = harness.repo.operations.values.single;
      expect(operation.serviceId, equals(samples.santaFeOilService.id));
      expect(operation.scheduleId, equals(samples.oilChange.id));
      expectOperationsVisible(tester, [operation]);
      expect(find.text(samples.oilChange.name), findsOneWidget);
      expect(operation.details, isEmpty);
      expect(find.text(samples.oilChange.details), findsNothing);
    });

    testWidgets('linked work keeps its own name and details after schedule editing', (
      tester,
    ) async {
      final harness = Harness(
        vehicle: samples.santaFe,
        service: samples.santaFeOilService,
        initialOperations: [samples.oilChangeOperation, samples.brakeInspectionOperation],
      );
      final schedule = samples.oilChange;
      harness.scheduleRepo.schedules[schedule.id] = Schedule(
        id: schedule.id,
        vehicleId: schedule.vehicleId,
        name: 'Updated oil change',
        details: 'Updated oil instructions',
        intervalDistance: schedule.intervalDistance,
        intervalMonths: schedule.intervalMonths,
      );

      await harness.pumpLoadedScreen(tester);

      final operations = OperationRobot(tester);
      final card = operations.findOperationCard(samples.oilChangeOperation.id);
      expect(find.descendant(of: card, matching: find.text('Updated oil change')), findsNothing);
      expect(
        find.descendant(of: card, matching: find.text(samples.oilChangeOperation.details)),
        findsOneWidget,
      );
      expect(find.descendant(of: card, matching: find.text(schedule.name)), findsOneWidget);
      expectOperationsVisible(tester, [samples.brakeInspectionOperation]);
    });

    group('Edit Operation', () {
      for (final original in [samples.oilChangeOperation, samples.brakeInspectionOperation]) {
        testWidgets('edits ${original.id} and refreshes without changing its association', (
          tester,
        ) async {
          final harness = Harness(
            vehicle: samples.santaFe,
            service: samples.santaFeOilService,
            initialOperations: samples.sampleOperations,
          );
          final operations = OperationRobot(tester);
          final form = OperationFormRobot(tester);
          await harness.pumpLoadedScreen(tester);
          await operations.tapOperationMenuEdit(original.id);
          expect(find.text('Edit Operation'), findsOneWidget);
          expect(form.name, equals(original.name));
          expect(form.details, equals(original.details));
          await form.enterName('  Updated work  ');
          await form.enterDetails('  Updated notes  ');
          await form.saveForm(pump: .settle);
          final updated = harness.repo.operations[original.id]!;
          expect(updated.name, equals('Updated work'));
          expect(updated.details, equals('Updated notes'));
          expect(updated.scheduleId, equals(original.scheduleId));
          expect(updated.serviceId, equals(original.serviceId));
          expect(harness.repo.operations, hasLength(samples.sampleOperations.length));
          expect(
            harness.repo.operations[samples.tireRotationOperation.id],
            same(samples.tireRotationOperation),
          );
          expect(harness.repo.listCalls, equals(2));
          expectOperationsVisible(tester, [updated]);
        });
      }

      testWidgets('editing can link custom work to a schedule without copying its details', (
        tester,
      ) async {
        final original = samples.brakeInspectionOperation;
        final harness = Harness(
          vehicle: samples.santaFe,
          service: samples.santaFeOilService,
          initialOperations: [original],
        );
        final operations = OperationRobot(tester);
        final form = OperationFormRobot(tester);
        await harness.pumpLoadedScreen(tester);
        await operations.tapOperationMenuEdit(original.id);
        await form.enterName('');
        await tester.pumpAndSettle();
        await form.selectSchedule(samples.oilChange.id);
        await form.enterDetails('Independent operation notes');
        await form.saveForm(pump: .settle);
        final updated = harness.repo.operations[original.id]!;
        expect(updated.scheduleId, equals(samples.oilChange.id));
        expect(updated.details, equals('Independent operation notes'));
        expect(harness.repo.listCalls, equals(2));
      });

      for (final fails in [false, true]) {
        testWidgets(
          'Back during an update that later ${fails ? 'fails' : 'succeeds'} skips refresh',
          (tester) async {
            final original = samples.oilChangeOperation;
            final harness = Harness(
              vehicle: samples.santaFe,
              service: samples.santaFeOilService,
              initialOperations: [original],
            );
            final operations = OperationRobot(tester);
            final form = OperationFormRobot(tester);
            await harness.pumpLoadedScreen(tester);
            await operations.tapOperationMenuEdit(original.id);
            await form.enterDetails('Pending update');
            final pending = harness.repo.pauseNextUpdate();
            await form.saveForm();
            await tester.pageBack();
            await tester.pumpAndSettle();
            if (fails) {
              pending.completeError(Exception('Network error'));
            } else {
              pending.complete();
            }
            await tester.pumpAndSettle();
            expect(harness.repo.listCalls, equals(1));
            expect(tester.takeException(), isNull);
            expect(form.findSaveError, findsNothing);
          },
        );
      }

      testWidgets('Back from editing skips refresh', (tester) async {
        final original = samples.oilChangeOperation;
        final harness = Harness(
          vehicle: samples.santaFe,
          service: samples.santaFeOilService,
          initialOperations: [original],
        );
        final operations = OperationRobot(tester);
        await harness.pumpLoadedScreen(tester);
        await operations.tapOperationMenuEdit(original.id);
        await OperationFormRobot(tester).enterDetails('Unsaved');
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(harness.repo.listCalls, equals(1));
        expect(harness.repo.operations[original.id], same(original));
      });

      testWidgets(
        'validation and failed update retain inputs for retry and refresh only on success',
        (tester) async {
          final original = samples.oilChangeOperation;
          final harness = Harness(
            vehicle: samples.santaFe,
            service: samples.santaFeOilService,
            initialOperations: [original],
          );
          final operations = OperationRobot(tester);
          final form = OperationFormRobot(tester);
          await harness.pumpLoadedScreen(tester);
          await operations.tapOperationMenuEdit(original.id);
          await form.enterName('   ');
          await form.saveForm();
          expect(form.nameError, isNotEmpty);
          await form.enterName('  Renamed oil work  ');
          await form.enterDetails('   ');
          final pending = harness.repo.pauseNextUpdate();
          await form.saveForm(pump: .none);
          await form.saveForm();
          expect(form.saveButton.enabled, isFalse);
          expect(form.nameEnabled, isFalse);
          expect(form.detailsEnabled, isFalse);
          expect(harness.repo.operations[original.id], same(original));
          pending.completeError(Exception('Network error'));
          await tester.pumpAndSettle();
          expect(form.findSaveError, findsOneWidget);
          expect(form.name, equals('  Renamed oil work  '));
          expect(harness.repo.listCalls, equals(1));
          await form.saveForm(pump: .settle);
          expect(harness.repo.listCalls, equals(2));
          expect(harness.repo.operations[original.id]!.details, isEmpty);
          expect(harness.repo.operations[original.id]!.scheduleId, equals(original.scheduleId));
        },
      );
    });

    group('Delete Operation', () {
      for (final dismiss in [false, true]) {
        testWidgets(
          '${dismiss ? 'dismissing' : 'cancelling'} confirmation skips deletion and refresh',
          (tester) async {
            final harness = Harness(
              vehicle: samples.santaFe,
              service: samples.santaFeOilService,
              initialOperations: [samples.oilChangeOperation],
            );
            final operations = OperationRobot(tester);
            await harness.pumpLoadedScreen(tester);
            await operations.tapOperationMenuDelete(samples.oilChangeOperation.id);
            expect(operations.findDeleteConfirmation, findsOneWidget);
            expect(
              find.text('Delete "${samples.oilChangeOperation.name}"? This cannot be undone.'),
              findsOneWidget,
            );
            if (dismiss) {
              await operations.dismissOperationDeletion();
            } else {
              await operations.cancelOperationDeletion();
            }
            expect(harness.repo.operations, hasLength(1));
            expect(harness.repo.listCalls, equals(1));
          },
        );
      }

      for (final fails in [false, true]) {
        testWidgets(
          'confirmed deletion ${fails ? 'failure reconciles the list' : 'refreshes to empty'}',
          (tester) async {
            final original = samples.oilChangeOperation;
            final harness = Harness(
              vehicle: samples.santaFe,
              service: samples.santaFeOilService,
              initialOperations: [original, samples.tireRotationOperation],
            );
            final operations = OperationRobot(tester);
            await harness.pumpLoadedScreen(tester);
            await operations.tapOperationMenuDelete(original.id);
            final pending = harness.repo.pauseNextDelete();
            await operations.confirmOperationDeletion(pump: .frame);
            expect(harness.repo.listCalls, equals(1));
            expect(harness.repo.operations[original.id], same(original));
            final refresh = harness.repo.pauseNextList();
            if (fails) {
              pending.completeError(Exception('Network error'));
            } else {
              pending.complete();
            }
            await tester.pump();
            expect(harness.repo.listCalls, equals(2));
            expect(operations.findDeleteError, fails ? findsOneWidget : findsNothing);
            refresh.complete();
            await tester.pumpAndSettle();
            expect(
              harness.repo.operations[samples.tireRotationOperation.id],
              same(samples.tireRotationOperation),
            );
            expect(
              operations.findOperationCard(original.id),
              fails ? findsOneWidget : findsNothing,
            );
            expect(find.byKey(OperationScreen.emptyTextKey), fails ? findsNothing : findsOneWidget);
          },
        );
      }
    });

    group('New Operation', () {
      for (final service in samples.sampleServices) {
        final vehicle = samples.sampleVehicles.singleWhere(
          (vehicle) => vehicle.id == service.vehicleId,
        );

        testWidgets('opens the ${service.id} form and Back skips refresh', (tester) async {
          final harness = Harness(
            vehicle: vehicle,
            service: service,
            initialOperations: samples.sampleOperations,
          );
          final operations = OperationRobot(tester);
          final form = OperationFormRobot(tester);
          await harness.pumpLoadedScreen(tester);

          await operations.tapNewOperation();

          expect(findOperationFormScreen, findsOneWidget);
          expect(findOperationScreen, findsNothing);
          expect(find.text(vehicle.name), findsOneWidget);
          final labels = MaterialLocalizations.of(tester.element(findOperationFormScreen));
          expect(find.text(labels.formatShortDate(service.date)), findsOneWidget);
          await form.enterName('Unsaved work');

          await tester.pageBack();
          await tester.pumpAndSettle();

          expect(findOperationFormScreen, findsNothing);
          expect(findOperationScreen, findsOneWidget);
          expect(harness.repo.listCalls, equals(1));
          expect(harness.repo.operations, hasLength(samples.sampleOperations.length));
          expectOperationsVisible(
            tester,
            samples.sampleOperations.where((operation) => operation.serviceId == service.id),
          );
        });

        testWidgets('saving new work refreshes only ${service.id} operations', (tester) async {
          final harness = Harness(
            vehicle: vehicle,
            service: service,
            initialOperations: samples.sampleOperations,
          );
          final operations = OperationRobot(tester);
          final form = OperationFormRobot(tester);
          await harness.pumpLoadedScreen(tester);
          await operations.tapNewOperation();
          await form.enterName('  Inspection  ');
          await form.enterDetails('  Check brakes  ');
          final refresh = harness.repo.pauseNextList();

          await form.saveForm();
          await tester.pump(const Duration(seconds: 1));

          expect(findOperationFormScreen, findsNothing);
          expect(find.byKey(OperationScreen.loadingIndicatorKey), findsOneWidget);
          expect(harness.repo.listCalls, equals(2));
          refresh.complete();
          await tester.pumpAndSettle();

          final created = harness.repo.operations.values.singleWhere(
            (operation) => operation.name == 'Inspection',
          );
          expect(created.serviceId, equals(service.id));
          expect(created.details, equals('Check brakes'));
          expect(created.scheduleId, isNull);
          expectOperationsVisible(tester, [
            ...samples.sampleOperations.where((operation) => operation.serviceId == service.id),
            created,
          ]);
          for (final other in samples.sampleOperations.where(
            (operation) => operation.serviceId != service.id,
          )) {
            expect(operations.findOperationCard(other.id), findsNothing);
          }
        });
      }

      testWidgets('creating the first operation replaces the empty state', (tester) async {
        final harness = Harness(vehicle: samples.santaFe, service: samples.santaFeOilService);
        final operations = OperationRobot(tester);
        final form = OperationFormRobot(tester);
        await harness.pumpLoadedScreen(tester);
        expect(find.byKey(OperationScreen.emptyTextKey), findsOneWidget);
        await operations.tapNewOperation();
        await form.enterName('Inspection');

        await form.saveForm(pump: .settle);

        expect(findOperationFormScreen, findsNothing);
        expect(find.byKey(OperationScreen.emptyTextKey), findsNothing);
        expect(harness.repo.operations, hasLength(1));
        expectOperationsVisible(tester, harness.repo.operations.values);
        expect(harness.repo.listCalls, equals(2));
      });

      testWidgets('failed save refreshes only after retry succeeds', (tester) async {
        final harness = Harness(vehicle: samples.santaFe, service: samples.santaFeOilService);
        final operations = OperationRobot(tester);
        final form = OperationFormRobot(tester);
        await harness.pumpLoadedScreen(tester);
        await operations.tapNewOperation();
        await form.enterName('Inspection');
        final pending = harness.repo.pauseNextCreate();

        await form.saveForm();
        pending.completeError(Exception('Network error'));
        await tester.pumpAndSettle();

        expect(findOperationFormScreen, findsOneWidget);
        expect(form.findSaveError, findsOneWidget);
        expect(form.name, equals('Inspection'));
        expect(harness.repo.listCalls, equals(1));
        expect(harness.repo.operations, isEmpty);

        await form.saveForm(pump: .settle);

        expect(findOperationFormScreen, findsNothing);
        expect(findOperationScreen, findsOneWidget);
        expect(harness.repo.listCalls, equals(2));
        expect(harness.repo.operations, hasLength(1));
        expectOperationsVisible(tester, harness.repo.operations.values);
      });
    });

    for (final fails in [false, true]) {
      testWidgets('can leave while a request later ${fails ? 'fails' : 'succeeds'}', (
        tester,
      ) async {
        final harness = Harness(vehicle: samples.santaFe, service: samples.santaFeOilService);
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

void expectOperationsVisible(WidgetTester tester, Iterable<Operation> operations) {
  final robot = OperationRobot(tester);
  for (final operation in operations) {
    final card = robot.findOperationCard(operation.id);
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(operation.name)), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.descendant(of: card, matching: find.byType(ListTile)),
    );
    if (operation.details.isEmpty) {
      expect(tile.subtitle, isNull);
    } else {
      expect(find.descendant(of: card, matching: find.text(operation.details)), findsOneWidget);
    }
  }
}

class Harness({
  required final Vehicle vehicle,
  required final Service service,
  final Iterable<Operation> initialOperations = const [],
}) {
  final serviceRepo = InMemoryServiceRepo(initialServices: [service]);
  final scheduleRepo = InMemoryScheduleRepo(initialSchedules: samples.sampleSchedules);
  late final repo = InMemoryOperationRepo(
    initialOperations: initialOperations,
    serviceRepo: serviceRepo,
    scheduleRepo: scheduleRepo,
  );

  Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
    RepositoryProvider(
      vehicleRepo: InMemoryVehicleRepo(),
      scheduleRepo: scheduleRepo,
      serviceRepo: serviceRepo,
      operationRepo: repo,
      child: MaterialApp(
        home: OperationScreen(
          vehicleService: VehicleService(vehicle: vehicle, service: service),
        ),
      ),
    ),
  );

  Future<void> pumpLoadedScreen(WidgetTester tester) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();
  }
}
