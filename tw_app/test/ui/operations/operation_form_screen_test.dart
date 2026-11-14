import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/repository_provider.dart';
import 'package:tw_app/app/vehicle_service.dart';
import 'package:tw_app/testing/samples.dart' as samples;
import 'package:tw_app/testing/stub.dart';
import 'package:tw_app/ui/operations/operation_form_screen.dart';

import '../../robots.dart';

void main() {
  group('OperationFormScreen', () {
    for (final name in ['', '   ']) {
      testWidgets('rejects a blank name "$name"', (tester) async {
        final harness = Harness();
        final form = OperationFormRobot(tester);
        await harness.pumpForm(tester);
        await form.enterName(name);
        await form.enterDetails('Some work');

        await form.saveForm();

        expect(form.nameError, isNotEmpty);
        expect(findOperationFormScreen, findsOneWidget);
        expect(harness.repo.operations, isEmpty);
      });
    }

    for (final service in samples.sampleServices) {
      testWidgets('creates trimmed custom work for ${service.id} and returns success', (
        tester,
      ) async {
        final vehicle = samples.sampleVehicles.singleWhere(
          (vehicle) => vehicle.id == service.vehicleId,
        );
        final harness = Harness(
          vehicleService: VehicleService(vehicle: vehicle, service: service),
          initialOperations: samples.sampleOperations,
        );
        final form = OperationFormRobot(tester);
        await harness.pumpForm(tester);
        expect(find.text(vehicle.name), findsOneWidget);
        final labels = MaterialLocalizations.of(tester.element(findOperationFormScreen));
        expect(find.text(labels.formatShortDate(service.date)), findsOneWidget);
        await form.enterName('  Inspection  ');
        await form.enterDetails('  Check brakes\nand tires  ');

        await form.saveForm(pump: .settle);

        expect(await harness.result, isTrue);
        expect(findOperationFormScreen, findsNothing);
        final created = harness.repo.operations.values.singleWhere(
          (operation) => operation.name == 'Inspection',
        );
        expect(created.serviceId, equals(service.id));
        expect(created.name, equals('Inspection'));
        expect(created.details, equals('Check brakes\nand tires'));
        expect(created.scheduleId, isNull);
        expect(harness.repo.operations, hasLength(samples.sampleOperations.length + 1));
        for (final original in samples.sampleOperations) {
          expect(harness.repo.operations[original.id], same(original));
        }
      });
    }

    for (final details in ['', '   ']) {
      testWidgets('accepts blank optional details "$details" as an empty string', (tester) async {
        final harness = Harness();
        final form = OperationFormRobot(tester);
        await harness.pumpForm(tester);
        await form.enterName('Inspection');
        await form.enterDetails(details);

        await form.saveForm(pump: .settle);

        expect(await harness.result, isTrue);
        expect(harness.repo.operations.values.single.details, isEmpty);
      });
    }

    testWidgets('disables fields, prevents repeat saves, and preserves inputs for retry', (
      tester,
    ) async {
      final harness = Harness();
      final form = OperationFormRobot(tester);
      await harness.pumpForm(tester);
      await form.enterName('  Inspection  ');
      await form.enterDetails('  Check brakes  ');
      final pending = harness.repo.pauseNextCreate();

      await form.saveForm(pump: .none);
      await form.saveForm();

      expect(form.saveButton.enabled, isFalse);
      expect(form.nameEnabled, isFalse);
      expect(form.detailsEnabled, isFalse);
      expect(harness.repo.operations, isEmpty);
      pending.completeError(Exception('Network error'));
      await tester.pumpAndSettle();

      expect(form.findSaveError, findsOneWidget);
      expect(form.saveButton.enabled, isTrue);
      expect(form.nameEnabled, isTrue);
      expect(form.detailsEnabled, isTrue);
      expect(form.name, equals('  Inspection  '));
      expect(form.details, equals('  Check brakes  '));
      expect(harness.repo.operations, isEmpty);

      final retry = harness.repo.pauseNextCreate();
      await form.saveForm(pump: .none);
      await form.saveForm();
      expect(harness.repo.operations, isEmpty);
      retry.complete();
      await tester.pumpAndSettle();

      expect(await harness.result, isTrue);
      final created = harness.repo.operations.values.single;
      expect(created.name, equals('Inspection'));
      expect(created.details, equals('Check brakes'));
    });

    testWidgets('Back returns without creating an operation', (tester) async {
      final harness = Harness();
      final form = OperationFormRobot(tester);
      await harness.pumpForm(tester);
      await form.enterName('Inspection');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(await harness.result, isNull);
      expect(harness.repo.operations, isEmpty);
    });

    for (final fails in [false, true]) {
      testWidgets('can leave while creation later ${fails ? 'fails' : 'succeeds'}', (tester) async {
        final harness = Harness();
        final form = OperationFormRobot(tester);
        await harness.pumpForm(tester);
        await form.enterName('Inspection');
        final pending = harness.repo.pauseNextCreate();
        await form.saveForm();

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(await harness.result, isNull);
        if (fails) {
          pending.completeError(Exception('Network error'));
        } else {
          pending.complete();
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(form.findSaveError, findsNothing);
      });
    }
  });
}

class Harness({
  final VehicleService? vehicleService,
  Iterable<Operation> initialOperations = const [],
}) {
  final repo = InMemoryOperationRepo(initialOperations: initialOperations);
  final _navigatorKey = GlobalKey<NavigatorState>();
  late Future<bool?> result;

  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      RepositoryProvider(
        vehicleRepo: InMemoryVehicleRepo(),
        scheduleRepo: InMemoryScheduleRepo(),
        serviceRepo: InMemoryServiceRepo(),
        operationRepo: repo,
        child: MaterialApp(navigatorKey: _navigatorKey, home: const Scaffold()),
      ),
    );
    result = _navigatorKey.currentState!.push<bool>(
      MaterialPageRoute(
        builder: (_) => OperationFormScreen(
          vehicleService:
              vehicleService ??
              VehicleService(vehicle: samples.santaFe, service: samples.santaFeOilService),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}
