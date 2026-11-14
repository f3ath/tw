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
  Iterable<Operation> initialOperations = const [],
}) {
  final repo = InMemoryOperationRepo(initialOperations: initialOperations);

  Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
    RepositoryProvider(
      vehicleRepo: InMemoryVehicleRepo(),
      scheduleRepo: InMemoryScheduleRepo(),
      serviceRepo: InMemoryServiceRepo(),
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
