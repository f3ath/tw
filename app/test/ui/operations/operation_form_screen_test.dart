import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:app/app/repository_provider.dart';
import 'package:app/app/vehicle_service.dart';
import 'package:app/testing/samples.dart' as samples;
import 'package:app/testing/stub.dart';
import 'package:app/ui/operations/operation_form_screen.dart';

import '../../robots.dart';

void main() {
  group('OperationFormScreen', () {
    testWidgets('empty name shows all vehicle suggestions with intervals and scrolls', (
      tester,
    ) async {
      final schedules = [
        samples.oilChange,
        for (var i = 0; i < 12; i++)
          Schedule(
            id: 'inspection-$i',
            vehicleId: samples.santaFe.id,
            name: 'Inspection $i',
            intervalDistance: null,
            intervalMonths: 6,
            details: '',
          ),
      ];
      final harness = Harness(initialSchedules: [...schedules, samples.tireRotation]);
      final form = OperationFormRobot(tester);
      await harness.pumpForm(tester);

      await form.focusName();

      for (final schedule in schedules) {
        expect(form.findScheduleSuggestion(schedule.id), findsOneWidget);
      }
      expect(form.findScheduleSuggestion(samples.tireRotation.id), findsNothing);
      expect(
        form.findSuggestionText(samples.oilChange.id, 'Every 10,000 km / 12 mo'),
        findsOneWidget,
      );
      await form.selectSchedule(schedules.last.id);
      expect(form.name, equals(schedules.last.name));
      expect(form.findSummaryText('Every 6 mo'), findsOneWidget);
    });

    for (final schedules in [
      <Schedule>[],
      [samples.tireRotation],
    ]) {
      testWidgets('custom work remains available without eligible schedules ${schedules.length}', (
        tester,
      ) async {
        final harness = Harness(initialSchedules: schedules);
        final form = OperationFormRobot(tester);
        await harness.pumpForm(tester);
        await form.focusName();
        expect(form.findScheduleSuggestion(samples.tireRotation.id), findsNothing);
        expect(form.findScheduleSummary, findsNothing);
        await form.enterName('Custom inspection');
        await form.saveForm(pump: .settle);
        expect(await harness.result, isTrue);
        expect(harness.repo.operations.values.single.scheduleId, isNull);
      });
    }

    testWidgets('rebuilding does not reload schedule suggestions', (tester) async {
      final harness = Harness(initialSchedules: samples.sampleSchedules);
      await harness.pumpForm(tester);
      await harness.rebuild(tester);
      await tester.pumpAndSettle();
      expect(harness.scheduleRepo.listCalls, equals(1));
    });

    testWidgets('filters suggestions and supports keyboard selection', (tester) async {
      final second = Schedule(
        id: 'oil-inspection',
        vehicleId: samples.santaFe.id,
        name: 'Oil inspection',
        intervalDistance: 5000,
        intervalMonths: null,
        details: '',
      );
      final harness = Harness(initialSchedules: [samples.oilChange, second]);
      final form = OperationFormRobot(tester);
      await harness.pumpForm(tester);
      await form.enterName('OIL');
      await tester.pumpAndSettle();
      expect(form.findScheduleSuggestion(samples.oilChange.id), findsOneWidget);
      expect(form.findScheduleSuggestion(second.id), findsOneWidget);

      await form.selectNextSuggestionWithKeyboard();
      expect(form.isSuggestionHighlighted(second.id), isTrue);
      await form.confirmSuggestionWithKeyboard();
      expect(form.name, equals(second.name));
      expect(form.findSummaryText('Every 5,000 km'), findsOneWidget);
      await form.enterName('unmatched work');
      await tester.pumpAndSettle();
      expect(form.findScheduleSuggestion(second.id), findsNothing);
      expect(form.findScheduleSummary, findsNothing);
    });

    for (final details in ['  Replaced with synthetic oil  ', '', '   ']) {
      testWidgets('selected schedule saves independent details "$details"', (tester) async {
        final harness = Harness(initialSchedules: [samples.oilChange]);
        final form = OperationFormRobot(tester);
        await harness.pumpForm(tester);
        await form.enterDetails(details);
        await form.focusName();
        await form.selectSchedule(samples.oilChange.id);

        expect(form.findSummaryText('Every 10,000 km / 12 mo'), findsOneWidget);
        expect(form.findSummaryText(samples.oilChange.details), findsOneWidget);
        expect(form.details, equals(details));
        expect(form.detailsEnabled, isTrue);
        await form.saveForm(pump: .settle);

        expect(await harness.result, isTrue);
        final operation = harness.repo.operations.values.single;
        expect(operation.scheduleId, equals(samples.oilChange.id));
        expect(operation.name, equals(samples.oilChange.name));
        expect(operation.details, equals(details.trim()));
        expect(
          (await harness.repo.list(operation.serviceId)).single.details,
          equals(details.trim()),
        );
      });
    }

    testWidgets('scheduled submission failure retains selection and details for retry', (
      tester,
    ) async {
      final harness = Harness(initialSchedules: [samples.oilChange]);
      final form = OperationFormRobot(tester);
      await harness.pumpForm(tester);
      await form.focusName();
      await form.selectSchedule(samples.oilChange.id);
      await form.enterDetails('  Independent notes  ');
      final pending = harness.repo.pauseNextCreate();
      await form.saveForm(pump: .none);
      await form.saveForm();
      expect(form.nameEnabled, isFalse);
      expect(form.detailsEnabled, isFalse);
      expect(form.saveButton.enabled, isFalse);
      expect(harness.repo.operations, isEmpty);
      pending.completeError(Exception('Network error'));
      await tester.pumpAndSettle();
      expect(form.findSaveError, findsOneWidget);
      expect(form.findSummaryText(samples.oilChange.details), findsOneWidget);
      expect(form.details, equals('  Independent notes  '));
      expect(form.detailsEnabled, isTrue);
      await form.saveForm(pump: .settle);
      expect(await harness.result, isTrue);
      expect(harness.repo.operations, hasLength(1));
      expect(harness.repo.operations.values.single.scheduleId, equals(samples.oilChange.id));
      expect(harness.repo.operations.values.single.details, equals('Independent notes'));
    });

    for (final scenario in ['missing service', 'missing schedule', 'wrong vehicle', 'duplicate']) {
      testWidgets('a stale $scenario choice shows failure and allows retry', (tester) async {
        final harness = Harness(initialSchedules: samples.sampleSchedules);
        final selection = OperationFormRobot(tester);
        await harness.pumpForm(tester);
        await selection.focusName();
        await selection.selectSchedule(samples.oilChange.id);
        switch (scenario) {
          case 'missing service':
            harness.serviceRepo.services.remove(samples.santaFeOilService.id);
          case 'missing schedule':
            harness.scheduleRepo.schedules.remove(samples.oilChange.id);
          case 'wrong vehicle':
            harness.scheduleRepo.schedules[samples.oilChange.id] = changedOilChange(
              vehicleId: samples.fourRunner.id,
            );
          case 'duplicate':
            harness.repo.operations[samples.oilChangeOperation.id] = samples.oilChangeOperation;
        }
        final before = Map.of(harness.repo.operations);

        await selection.saveForm(pump: .settle);

        expect(findOperationFormScreen, findsOneWidget);
        expect(selection.findSaveError, findsOneWidget);
        expect(selection.saveButton.enabled, isTrue);
        expect(harness.repo.operations, equals(before));
        harness.serviceRepo.services[samples.santaFeOilService.id] = samples.santaFeOilService;
        harness.scheduleRepo.schedules[samples.oilChange.id] = samples.oilChange;
        if (scenario == 'duplicate') harness.repo.operations.clear();

        await selection.saveForm(pump: .settle);

        expect(await harness.result, isTrue);
        expect(findOperationFormScreen, findsNothing);
        expect(harness.repo.operations.values.single.scheduleId, equals(samples.oilChange.id));
      });
    }

    testWidgets('the same schedule may be recorded for a different service', (tester) async {
      final service = Service(
        'second-service',
        vehicleId: samples.santaFe.id,
        date: DateTime(2026, 11, 4),
        odometer: 121000,
        details: '',
      );
      final harness = Harness(
        vehicleService: VehicleService(vehicle: samples.santaFe, service: service),
        initialSchedules: samples.sampleSchedules,
        initialOperations: [samples.oilChangeOperation],
      );
      harness.serviceRepo.services[service.id] = service;
      final selection = OperationFormRobot(tester);
      await harness.pumpForm(tester);
      await selection.focusName();
      await selection.selectSchedule(samples.oilChange.id);

      await selection.saveForm(pump: .settle);

      expect(await harness.result, isTrue);
      expect(harness.repo.operations, hasLength(2));
      expect(
        harness.repo.operations[samples.oilChangeOperation.id],
        same(samples.oilChangeOperation),
      );
      final created = harness.repo.operations.values.singleWhere(
        (operation) => operation.serviceId == service.id,
      );
      expect(created.scheduleId, equals(samples.oilChange.id));
    });

    testWidgets('editing a selection clears summary and saves custom work with retained details', (
      tester,
    ) async {
      final harness = Harness(initialSchedules: [samples.oilChange]);
      final form = OperationFormRobot(tester);
      await harness.pumpForm(tester);
      await form.focusName();
      await form.selectSchedule(samples.oilChange.id);
      await form.enterDetails('  My operation notes  ');
      await form.enterName('  Custom oil work  ');
      expect(form.findScheduleSummary, findsNothing);
      expect(form.details, equals('  My operation notes  '));
      await form.saveForm(pump: .settle);
      final operation = harness.repo.operations.values.single;
      expect(operation.scheduleId, isNull);
      expect(operation.name, equals('Custom oil work'));
      expect(operation.details, equals('My operation notes'));
    });

    testWidgets('typing a schedule name without selecting keeps work custom', (tester) async {
      final harness = Harness(initialSchedules: [samples.oilChange]);
      final form = OperationFormRobot(tester);
      await harness.pumpForm(tester);
      await form.enterName(samples.oilChange.name);
      await form.enterDetails('Independent notes');
      await form.saveForm(pump: .settle);
      expect(harness.repo.operations.values.single.scheduleId, isNull);
      expect(form.findScheduleSummary, findsNothing);
    });

    testWidgets('schedule loading failure can retry without losing operation inputs', (
      tester,
    ) async {
      final harness = Harness(initialSchedules: [samples.oilChange]);
      final pending = harness.scheduleRepo.pauseNextList();
      final form = OperationFormRobot(tester);
      await harness.pumpForm(tester, pump: .frame);
      await tester.pump(const Duration(seconds: 1));
      expect(form.findSuggestionsLoading, findsOneWidget);
      await form.enterDetails('My notes');
      pending.completeError(Exception('Network error'));
      await tester.pumpAndSettle();
      expect(form.findSuggestionsError, findsOneWidget);
      expect(form.details, equals('My notes'));
      await form.retrySuggestions();
      expect(form.findSuggestionsError, findsNothing);
      await form.focusName();
      await form.selectSchedule(samples.oilChange.id);
      expect(form.details, equals('My notes'));
    });

    testWidgets('suggestion failure still allows custom creation', (tester) async {
      final harness = Harness();
      final pending = harness.scheduleRepo.pauseNextList();
      final form = OperationFormRobot(tester);
      await harness.pumpForm(tester, pump: .frame);
      pending.completeError(Exception('Network error'));
      await tester.pumpAndSettle();
      await form.enterName('Custom work');
      await form.enterDetails('My notes');
      await form.saveForm(pump: .settle);
      expect(await harness.result, isTrue);
      expect(harness.repo.operations.values.single.details, equals('My notes'));
    });

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

    for (final loading in [false, true]) {
      for (final fails in [false, true]) {
        testWidgets(
          'can leave while ${loading ? 'loading schedules' : 'saving scheduled work'} later ${fails ? 'fails' : 'succeeds'}',
          (tester) async {
            final harness = Harness(initialSchedules: samples.sampleSchedules);
            final selection = OperationFormRobot(tester);
            final pending = loading
                ? harness.scheduleRepo.pauseNextList()
                : harness.repo.pauseNextCreate();
            if (loading) {
              await harness.pumpForm(tester, pump: .frame);
              await tester.pump(const Duration(seconds: 1));
            } else {
              await harness.pumpForm(tester);
              await selection.focusName();
              await selection.selectSchedule(samples.oilChange.id);
              await selection.saveForm();
            }
            await tester.pageBack();
            // Remove the route while its progress indicator is still animating.
            await tester.pumpAndSettle();
            expect(await harness.result, isNull);
            if (fails) {
              pending.completeError(Exception('Network error'));
            } else {
              pending.complete();
            }
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
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

Schedule changedOilChange({String? vehicleId}) => Schedule(
  id: samples.oilChange.id,
  vehicleId: vehicleId ?? samples.oilChange.vehicleId,
  name: samples.oilChange.name,
  details: samples.oilChange.details,
  intervalDistance: samples.oilChange.intervalDistance,
  intervalMonths: samples.oilChange.intervalMonths,
);

class Harness({
  final VehicleService? vehicleService,
  final Iterable<Operation> initialOperations = const [],
  Iterable<Schedule> initialSchedules = const [],
}) {
  final scheduleRepo = InMemoryScheduleRepo(initialSchedules: initialSchedules);
  final serviceRepo = InMemoryServiceRepo(initialServices: samples.sampleServices);
  late final repo = InMemoryOperationRepo(
    initialOperations: initialOperations,
    scheduleRepo: scheduleRepo,
    serviceRepo: serviceRepo,
  );
  final _navigatorKey = GlobalKey<NavigatorState>();
  late Future<bool?> result;

  Future<void> rebuild(WidgetTester tester) => tester.pumpWidget(
    RepositoryProvider(
      vehicleRepo: InMemoryVehicleRepo(),
      scheduleRepo: scheduleRepo,
      serviceRepo: serviceRepo,
      operationRepo: repo,
      child: MaterialApp(navigatorKey: _navigatorKey, home: const Scaffold()),
    ),
  );

  Future<void> pumpForm(WidgetTester tester, {PumpMode pump = .settle}) async {
    await rebuild(tester);
    result = _navigatorKey.currentState!.push<bool>(
      MaterialPageRoute(
        builder: (_) => OperationFormScreen(
          vehicleService:
              vehicleService ??
              VehicleService(vehicle: samples.santaFe, service: samples.santaFeOilService),
        ),
      ),
    );
    await OperationFormRobot(tester).pumpAfterAction(pump);
  }
}
