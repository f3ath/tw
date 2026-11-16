import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:app/app/repository_provider.dart';
import 'package:shared/model.dart';
import 'package:app/testing/samples.dart' as samples;
import 'package:app/testing/stub.dart';
import 'package:app/ui/schedules/schedule_form_screen.dart';

import '../../robots.dart';

void main() {
  group('ScheduleFormScreen', () {
    group('Editing', () {
      for (final scenario in [
        (
          name: 'clears the distance interval',
          distance: '',
          months: '9',
          expectedDistance: null,
          expectedMonths: 9,
        ),
        (
          name: 'clears the time interval',
          distance: '7500',
          months: '',
          expectedDistance: 7500,
          expectedMonths: null,
        ),
      ]) {
        testWidgets(scenario.name, (tester) async {
          final harness = Harness(
            vehicle: samples.santaFe,
            initialSchedules: samples.sampleSchedules,
            schedule: samples.oilChange,
          );
          final form = ScheduleFormRobot(tester);
          await harness.pumpForm(tester);

          await form.fill(
            name: '  Updated inspection  ',
            distance: scenario.distance,
            months: scenario.months,
            details: '',
          );
          final pending = harness.repo.pauseNextUpdate();

          await form.saveForm();

          expect(form.saveButton.enabled, isFalse);
          expect(harness.repo.schedules[samples.oilChange.id], same(samples.oilChange));
          pending.complete();
          await tester.pumpAndSettle();

          expect(findScheduleFormScreen, findsNothing);
          expect(await harness.result, isTrue);
          final updated = harness.repo.schedules[samples.oilChange.id]!;
          expect(harness.repo.schedules, hasLength(2));
          expect(updated.id, equals(samples.oilChange.id));
          expect(updated.vehicleId, equals(samples.santaFe.id));
          expect(updated.name, equals('Updated inspection'));
          expect(updated.intervalDistance, equals(scenario.expectedDistance));
          expect(updated.intervalMonths, equals(scenario.expectedMonths));
          expect(updated.details, isEmpty);
          expect(updated.isArchived, equals(samples.oilChange.isArchived));
          expect(harness.repo.schedules[samples.tireRotation.id], same(samples.tireRotation));
        });
      }

      testWidgets('failed update retains edits and can be retried', (tester) async {
        final harness = Harness(
          vehicle: samples.santaFe,
          initialSchedules: samples.sampleSchedules,
          schedule: samples.oilChange,
        );
        final form = ScheduleFormRobot(tester);
        await harness.pumpForm(tester);

        await form.fill(
          name: 'Updated inspection',
          distance: '7500',
          months: '9',
          details: 'Updated details',
        );
        final pending = harness.repo.pauseNextUpdate();
        await form.saveForm();
        expect(form.saveButton.enabled, isFalse);
        await form.saveForm(pump: .none);

        pending.completeError(Exception('Network error'));
        await tester.pumpAndSettle();

        expect(find.byKey(ScheduleFormScreen.errorSnackBarKey), findsOneWidget);
        expect(form.saveButton.enabled, isTrue);
        expect(form.name, equals('Updated inspection'));
        expect(form.intervalDistance, equals('7500'));
        expect(form.intervalMonths, equals('9'));
        expect(form.details, equals('Updated details'));
        expect(harness.repo.schedules[samples.oilChange.id], same(samples.oilChange));

        await form.saveForm(pump: .settle);

        expect(findScheduleFormScreen, findsNothing);
        expect(await harness.result, isTrue);
        expect(harness.repo.schedules, hasLength(2));

        final updated = harness.repo.schedules[samples.oilChange.id]!;
        expect(updated.name, equals('Updated inspection'));
      });
    });

    group('Creation', () {
      for (final scenario in [
        (
          name: 'creates a schedule with both intervals',
          distance: '7500',
          months: '6',
          expectedDistance: 7500,
          expectedMonths: 6,
        ),
        (
          name: 'creates a schedule with only a distance interval',
          distance: '7500',
          months: '',
          expectedDistance: 7500,
          expectedMonths: null,
        ),
        (
          name: 'creates a schedule with only a time interval',
          distance: '',
          months: '6',
          expectedDistance: null,
          expectedMonths: 6,
        ),
      ]) {
        testWidgets(scenario.name, (tester) async {
          final harness = Harness(
            vehicle: samples.santaFe,
            initialSchedules: samples.sampleSchedules,
          );
          final form = ScheduleFormRobot(tester);
          await harness.pumpForm(tester);

          await form.fill(
            name: '  Inspection  ',
            distance: scenario.distance,
            months: scenario.months,
            details: '  Check brakes  ',
          );

          final pending = harness.repo.pauseNextCreate();
          await form.saveForm();
          expect(form.saveButton.enabled, isFalse);
          expect(findScheduleFormScreen, findsOneWidget);
          expect(harness.repo.schedules.length, equals(2));

          pending.complete();
          await tester.pumpAndSettle();

          expect(findScheduleFormScreen, findsNothing);
          expect(await harness.result, isTrue);

          final created = harness.repo.schedules.values.singleWhere((s) => s.name == 'Inspection');
          expect(created.vehicleId, equals(samples.santaFe.id));
          expect(created.intervalDistance, equals(scenario.expectedDistance));
          expect(created.intervalMonths, equals(scenario.expectedMonths));
          expect(created.details, equals('Check brakes'));
        });
      }

      group('Validation', () {
        testWidgets('rejects a blank name with an otherwise valid interval', (tester) async {
          final harness = Harness(vehicle: samples.santaFe);
          final form = ScheduleFormRobot(tester);
          await harness.pumpForm(tester);
          await form.enterName('  ');
          await form.enterMonths('6');

          await form.saveForm();

          expect(form.nameError, isNotEmpty);
          expect(form.distanceError, isNull);
          expect(form.monthsError, isNull);
          expect(findScheduleFormScreen, findsOneWidget);
          expect(harness.repo.schedules, isEmpty);
        });

        testWidgets('requires at least one interval', (tester) async {
          final harness = Harness(vehicle: samples.santaFe);
          final form = ScheduleFormRobot(tester);
          await harness.pumpForm(tester);
          await form.enterName('Inspection');

          await form.saveForm();

          expect(form.nameError, isNull);
          expect(form.distanceError, isNotEmpty);
          expect(form.monthsError, isNotEmpty);
          expect(findScheduleFormScreen, findsOneWidget);
          expect(harness.repo.schedules, isEmpty);
        });

        for (final scenario in [
          (name: 'zero', value: '0'),
          (name: 'negative', value: '-1'),
          (name: 'fractional', value: '1.5'),
          (name: 'nonnumeric', value: 'abc'),
        ]) {
          testWidgets('rejects a ${scenario.name} distance interval', (tester) async {
            final harness = Harness(vehicle: samples.santaFe);
            final form = ScheduleFormRobot(tester);
            await harness.pumpForm(tester);
            await form.enterName('Inspection');
            await form.enterDistance(scenario.value);
            await form.enterMonths('6');

            await form.saveForm();

            expect(form.nameError, isNull);
            expect(form.distanceError, isNotEmpty);
            expect(form.monthsError, isNull);
            expect(findScheduleFormScreen, findsOneWidget);
            expect(harness.repo.schedules, isEmpty);
          });

          testWidgets('rejects a ${scenario.name} time interval', (tester) async {
            final harness = Harness(vehicle: samples.santaFe);
            final form = ScheduleFormRobot(tester);
            await harness.pumpForm(tester);
            await form.enterName('Inspection');
            await form.enterDistance('7500');
            await form.enterMonths(scenario.value);

            await form.saveForm();

            expect(form.nameError, isNull);
            expect(form.distanceError, isNull);
            expect(form.monthsError, isNotEmpty);
            expect(findScheduleFormScreen, findsOneWidget);
            expect(harness.repo.schedules, isEmpty);
          });
        }
      });

      testWidgets('failed save preserves inputs and enables a successful retry', (tester) async {
        final harness = Harness(vehicle: samples.santaFe);
        final form = ScheduleFormRobot(tester);
        await harness.pumpForm(tester);

        await form.fill(name: 'Inspection', distance: '7500', months: '6', details: 'Check brakes');
        final pending = harness.repo.pauseNextCreate();
        await form.saveForm();
        expect(form.saveButton.enabled, isFalse);
        await form.saveForm(pump: .none);

        pending.completeError(Exception('Network error'));
        await tester.pumpAndSettle();

        expect(find.byKey(ScheduleFormScreen.errorSnackBarKey), findsOneWidget);
        expect(findScheduleFormScreen, findsOneWidget);
        expect(form.saveButton.enabled, isTrue);
        expect(form.name, equals('Inspection'));
        expect(form.intervalDistance, equals('7500'));
        expect(form.intervalMonths, equals('6'));
        expect(form.details, equals('Check brakes'));
        expect(harness.repo.schedules, isEmpty);

        await form.saveForm(pump: .settle);

        expect(findScheduleFormScreen, findsNothing);
        expect(await harness.result, isTrue);
        expect(harness.repo.schedules, hasLength(1));
      });
    });
  });
}

class Harness({
  required final Vehicle vehicle,
  final Schedule? schedule,
  Iterable<Schedule> initialSchedules = const [],
}) {
  final repo = InMemoryScheduleRepo(initialSchedules: initialSchedules);
  final _navigatorKey = GlobalKey<NavigatorState>();
  late Future<bool?> result;

  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      RepositoryProvider(
        vehicleRepo: InMemoryVehicleRepo(),
        scheduleRepo: repo,
        serviceRepo: InMemoryServiceRepo(),
        operationRepo: InMemoryOperationRepo(),
        child: MaterialApp(navigatorKey: _navigatorKey, home: const Scaffold()),
      ),
    );
    result = _navigatorKey.currentState!.push<bool>(
      MaterialPageRoute(
        builder: (_) => ScheduleFormScreen(vehicle: vehicle, schedule: schedule),
      ),
    );
    await tester.pumpAndSettle();
  }
}
