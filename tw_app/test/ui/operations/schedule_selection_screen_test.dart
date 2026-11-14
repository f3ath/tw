import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/repository_provider.dart';
import 'package:tw_app/app/vehicle_service.dart';
import 'package:tw_app/testing/samples.dart' as samples;
import 'package:tw_app/testing/stub.dart';
import 'package:tw_app/ui/operations/schedule_selection_screen.dart';

import '../../robots.dart';

void main() {
  group('ScheduleSelectionScreen', () {
    testWidgets('loads only schedules for the selected vehicle', (tester) async {
      final harness = Harness(initialSchedules: samples.sampleSchedules);
      final selection = ScheduleSelectionRobot(tester);
      final pending = harness.scheduleRepo.pauseNextList();
      await harness.pumpScreen(tester);
      expect(find.byKey(ScheduleSelectionScreen.loadingIndicatorKey), findsOneWidget);

      pending.complete();
      await tester.pumpAndSettle();

      expect(selection.findScheduleCard(samples.oilChange.id), findsOneWidget);
      expect(selection.findScheduleCard(samples.tireRotation.id), findsNothing);
      expect(find.text(samples.santaFe.name), findsOneWidget);
      expect(find.text(samples.oilChange.details), findsOneWidget);
      expect(harness.scheduleRepo.listCalls, equals(1));
    });

    for (final schedules in [
      <Schedule>[],
      [samples.tireRotation],
    ]) {
      testWidgets(
        'shows empty state when ${schedules.map((s) => s.id).join(',')} has no eligible schedules',
        (tester) async {
          final harness = Harness(initialSchedules: schedules);
          await harness.pumpLoadedScreen(tester);

          expect(find.byKey(ScheduleSelectionScreen.emptyTextKey), findsOneWidget);
          expect(find.byType(ListTile), findsNothing);
        },
      );
    }

    testWidgets('load failure can be retried', (tester) async {
      final harness = Harness();
      final selection = ScheduleSelectionRobot(tester);
      final pending = harness.scheduleRepo.pauseNextList();
      await harness.pumpScreen(tester);
      pending.completeError(Exception('Network error'));
      await tester.pumpAndSettle();
      expect(find.byKey(ScheduleSelectionScreen.errorTextKey), findsOneWidget);
      final retry = harness.scheduleRepo.pauseNextList();

      await selection.tapRetry();

      expect(find.byKey(ScheduleSelectionScreen.loadingIndicatorKey), findsOneWidget);
      retry.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(ScheduleSelectionScreen.errorTextKey), findsNothing);
      expect(selection.findScheduleCard(samples.oilChange.id), findsOneWidget);
      expect(harness.scheduleRepo.listCalls, equals(2));
    });

    testWidgets('rebuilding does not reload schedules', (tester) async {
      final harness = Harness();
      await harness.pumpLoadedScreen(tester);

      await harness.rebuild(tester);
      await tester.pumpAndSettle();

      expect(harness.scheduleRepo.listCalls, equals(1));
    });

    testWidgets('selection disables rows, guards repeated taps, and returns success', (
      tester,
    ) async {
      final inspection = Schedule(
        id: 'inspection',
        vehicleId: samples.santaFe.id,
        name: 'Inspection',
        details: '',
        intervalDistance: null,
        intervalMonths: 6,
      );
      final harness = Harness(initialSchedules: [samples.oilChange, inspection]);
      final selection = ScheduleSelectionRobot(tester);
      await harness.pumpLoadedScreen(tester);
      final pending = harness.operationRepo.pauseNextCreate();

      await selection.selectSchedule(samples.oilChange.id, pump: .none);
      await selection.selectSchedule(samples.oilChange.id);

      expect(selection.findSavingIndicator, findsOneWidget);
      expect(selection.scheduleTile(samples.oilChange.id).enabled, isFalse);
      expect(selection.scheduleTile(inspection.id).enabled, isFalse);
      expect(harness.operationRepo.operations, isEmpty);
      pending.complete();
      await tester.pumpAndSettle();

      expect(await harness.result, isTrue);
      expect(findScheduleSelectionScreen, findsNothing);
      final operation = harness.operationRepo.operations.values.single;
      expect(operation.serviceId, equals(samples.santaFeOilService.id));
      expect(operation.scheduleId, equals(samples.oilChange.id));
      expect(operation.name, equals(samples.oilChange.name));
      expect(operation.details, isEmpty);
    });

    testWidgets('Back returns without creating work', (tester) async {
      final harness = Harness();
      await harness.pumpLoadedScreen(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(await harness.result, isNull);
      expect(harness.operationRepo.operations, isEmpty);
    });

    for (final scenario in ['missing service', 'missing schedule', 'wrong vehicle', 'duplicate']) {
      testWidgets('a stale $scenario choice shows failure and allows retry', (tester) async {
        final harness = Harness();
        final selection = ScheduleSelectionRobot(tester);
        await harness.pumpLoadedScreen(tester);
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
            harness.operationRepo.operations[samples.oilChangeOperation.id] =
                samples.oilChangeOperation;
        }
        final before = Map.of(harness.operationRepo.operations);

        await selection.selectSchedule(samples.oilChange.id, pump: .settle);

        expect(findScheduleSelectionScreen, findsOneWidget);
        expect(selection.findSaveError, findsOneWidget);
        expect(selection.findSavingIndicator, findsNothing);
        expect(selection.scheduleTile(samples.oilChange.id).enabled, isTrue);
        expect(harness.operationRepo.operations, equals(before));
        harness.serviceRepo.services[samples.santaFeOilService.id] = samples.santaFeOilService;
        harness.scheduleRepo.schedules[samples.oilChange.id] = samples.oilChange;
        if (scenario == 'duplicate') harness.operationRepo.operations.clear();

        await selection.selectSchedule(samples.oilChange.id, pump: .settle);

        expect(await harness.result, isTrue);
        expect(findScheduleSelectionScreen, findsNothing);
        expect(
          harness.operationRepo.operations.values.single.scheduleId,
          equals(samples.oilChange.id),
        );
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
      final harness = Harness(service: service, initialOperations: [samples.oilChangeOperation]);
      final selection = ScheduleSelectionRobot(tester);
      await harness.pumpLoadedScreen(tester);

      await selection.selectSchedule(samples.oilChange.id, pump: .settle);

      expect(await harness.result, isTrue);
      expect(harness.operationRepo.operations, hasLength(2));
      expect(
        harness.operationRepo.operations[samples.oilChangeOperation.id],
        same(samples.oilChangeOperation),
      );
      final created = harness.operationRepo.operations.values.singleWhere(
        (operation) => operation.serviceId == service.id,
      );
      expect(created.scheduleId, equals(samples.oilChange.id));
    });

    testWidgets('network failure during submission keeps the screen open and permits retry', (
      tester,
    ) async {
      final harness = Harness();
      final selection = ScheduleSelectionRobot(tester);
      await harness.pumpLoadedScreen(tester);
      final pending = harness.operationRepo.pauseNextCreate();
      await selection.selectSchedule(samples.oilChange.id);
      pending.completeError(Exception('Network error'));
      await tester.pumpAndSettle();

      expect(selection.findSaveError, findsOneWidget);
      expect(findScheduleSelectionScreen, findsOneWidget);
      expect(harness.operationRepo.operations, isEmpty);

      await selection.selectSchedule(samples.oilChange.id, pump: .settle);
      expect(await harness.result, isTrue);
    });

    for (final loading in [false, true]) {
      for (final fails in [false, true]) {
        testWidgets(
          'can leave while ${loading ? 'loading' : 'saving'} later ${fails ? 'fails' : 'succeeds'}',
          (tester) async {
            final harness = Harness();
            final selection = ScheduleSelectionRobot(tester);
            final pending = loading
                ? harness.scheduleRepo.pauseNextList()
                : harness.operationRepo.pauseNextCreate();
            if (loading) {
              await harness.pumpScreen(tester);
            } else {
              await harness.pumpLoadedScreen(tester);
              await selection.selectSchedule(samples.oilChange.id);
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
  Service? service,
  Iterable<Schedule>? initialSchedules,
  final Iterable<Operation> initialOperations = const [],
}) {
  final selectedService = service ?? samples.santaFeOilService;
  late final serviceRepo = InMemoryServiceRepo(initialServices: [selectedService]);
  final scheduleRepo = InMemoryScheduleRepo(
    initialSchedules: initialSchedules ?? samples.sampleSchedules,
  );
  late final operationRepo = InMemoryOperationRepo(
    serviceRepo: serviceRepo,
    scheduleRepo: scheduleRepo,
    initialOperations: initialOperations,
  );
  final _navigatorKey = GlobalKey<NavigatorState>();
  late Future<bool?> result;

  Widget _app() => RepositoryProvider(
    vehicleRepo: InMemoryVehicleRepo(),
    scheduleRepo: scheduleRepo,
    serviceRepo: serviceRepo,
    operationRepo: operationRepo,
    child: MaterialApp(navigatorKey: _navigatorKey, home: const Scaffold()),
  );

  Future<void> rebuild(WidgetTester tester) => tester.pumpWidget(_app());

  Future<void> pumpScreen(WidgetTester tester) async {
    await rebuild(tester);
    result = _navigatorKey.currentState!.push<bool>(
      MaterialPageRoute(
        builder: (_) => ScheduleSelectionScreen(
          vehicleService: VehicleService(vehicle: samples.santaFe, service: selectedService),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> pumpLoadedScreen(WidgetTester tester) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();
  }
}
