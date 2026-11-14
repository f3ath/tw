import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/testing/samples.dart' as samples;
import 'package:tw_app/testing/stub.dart';
import 'package:tw_app/ui/schedules/schedule_screen.dart';
import 'package:tw_app/ui/schedules/schedule_card.dart';
import 'package:tw_app/ui/schedules/schedule_form_screen.dart';

import '../../robots.dart';

void main() {
  group('ScheduleScreen', () {
    testWidgets('shows only the selected vehicle schedules after loading', (tester) async {
      final harness = Harness(vehicle: samples.santaFe, initialSchedules: samples.sampleSchedules);
      final pending = harness.repo.pauseNextList();
      await harness.pumpScreen(tester);

      expect(find.byKey(ScheduleScreen.loadingIndicatorKey), findsOneWidget);
      expect(find.text(samples.santaFe.name), findsOneWidget);
      expect(find.text(samples.oilChange.name), findsNothing);

      pending.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(ScheduleScreen.loadingIndicatorKey), findsNothing);
      expectSchedulesVisible([samples.oilChange]);
      expect(find.text('Every 10,000 km / 12 mo'), findsOneWidget);
      expect(find.text(samples.tireRotation.name), findsNothing);
    });

    testWidgets('rebuilding does not reload schedules', (tester) async {
      final harness = Harness(vehicle: samples.santaFe, initialSchedules: samples.sampleSchedules);
      await harness.pumpLoadedScreen(tester);
      expect(harness.repo.listCalls, equals(1));
      expectSchedulesVisible([samples.oilChange]);

      await harness.pumpLoadedScreen(tester);

      expect(harness.repo.listCalls, equals(1));
      expectSchedulesVisible([samples.oilChange]);
    });

    testWidgets('shows an empty state when the vehicle has no schedules', (tester) async {
      final harness = Harness(vehicle: samples.santaFe, initialSchedules: [samples.tireRotation]);
      await harness.pumpLoadedScreen(tester);

      expect(find.byKey(ScheduleScreen.emptyTextKey), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byKey(ScheduleScreen.loadingIndicatorKey), findsNothing);
    });

    testWidgets('failed loading shows an error and can be retried', (tester) async {
      final harness = Harness(
        vehicle: samples.fourRunner,
        initialSchedules: samples.sampleSchedules,
      );
      final schedules = ScheduleRobot(tester);
      final pending = harness.repo.pauseNextList();
      await harness.pumpScreen(tester);

      pending.completeError(Exception('Network error'));
      await tester.pumpAndSettle();

      expect(find.byKey(ScheduleScreen.errorTextKey), findsOneWidget);
      expect(find.byKey(ScheduleScreen.loadingIndicatorKey), findsNothing);
      expect(find.byKey(ScheduleScreen.emptyTextKey), findsNothing);

      final retry = harness.repo.pauseNextList();
      await schedules.tapRetry();
      expect(find.byKey(ScheduleScreen.loadingIndicatorKey), findsOneWidget);

      retry.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(ScheduleScreen.errorTextKey), findsNothing);
      expectSchedulesVisible([samples.tireRotation]);
      expect(find.text(samples.oilChange.name), findsNothing);
      expect(harness.repo.listCalls, equals(2));
    });

    for (final scenario in [
      (distance: 5000, months: null, expected: 'Every 5,000 mi'),
      (distance: null, months: 6, expected: 'Every 6 mo'),
    ]) {
      testWidgets('formats a single interval as "${scenario.expected}"', (tester) async {
        final vehicle = samples.fourRunner;
        final schedule = Schedule(
          id: 'single-interval',
          vehicleId: vehicle.id,
          name: 'Inspection',
          intervalDistance: scenario.distance,
          intervalMonths: scenario.months,
          details: '',
        );
        final harness = Harness(vehicle: vehicle, initialSchedules: [schedule]);
        await harness.pumpLoadedScreen(tester);

        final card = find.byKey(ScheduleScreen.scheduleKey(schedule.id));
        expect(find.descendant(of: card, matching: find.text(scenario.expected)), findsOneWidget);
      });
    }

    testWidgets('New Schedule opens the form for the vehicle and Back preserves the list', (
      tester,
    ) async {
      final harness = Harness(
        vehicle: samples.fourRunner,
        initialSchedules: samples.sampleSchedules,
      );
      final schedules = ScheduleRobot(tester);
      await harness.pumpLoadedScreen(tester);

      await schedules.tapNewSchedule();

      expect(findScheduleFormScreen, findsOneWidget);
      expect(findScheduleScreen, findsNothing);
      expect(find.text(samples.fourRunner.name), findsOneWidget);
      expect(find.text('mi'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(findScheduleFormScreen, findsNothing);
      expect(findScheduleScreen, findsOneWidget);
      expectSchedulesVisible([samples.tireRotation]);
      expect(harness.repo.listCalls, equals(1));
    });

    testWidgets('Edit opens the selected schedule prefilled and Back preserves the list', (
      tester,
    ) async {
      final vehicle = samples.santaFe;
      final inspection = Schedule(
        id: 'inspection',
        vehicleId: vehicle.id,
        name: 'Inspection',
        intervalDistance: 7500,
        intervalMonths: 9,
        details: 'Check brakes and tires',
      );
      final harness = Harness(vehicle: vehicle, initialSchedules: [samples.oilChange, inspection]);
      final schedules = ScheduleRobot(tester);
      final form = ScheduleFormRobot(tester);
      await harness.pumpLoadedScreen(tester);

      await schedules.tapScheduleMenuEdit(inspection.id);

      expect(findScheduleFormScreen, findsOneWidget);
      expect(findScheduleScreen, findsNothing);
      expect(find.text('Edit Schedule'), findsOneWidget);
      expect(form.saveButton.enabled, isFalse);
      expect(form.name, equals(inspection.name));
      expect(form.intervalDistance, equals('7500'));
      expect(form.intervalMonths, equals('9'));
      expect(form.details, equals(inspection.details));
      expect(find.text('km'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(findScheduleFormScreen, findsNothing);
      expectSchedulesVisible([samples.oilChange, inspection]);
      expect(harness.repo.listCalls, equals(1));
    });

    group('Creation', () {
      for (final scenario in [
        (distance: '7500', months: '6', expectedDistance: 7500, expectedMonths: 6),
        (distance: '7500', months: '', expectedDistance: 7500, expectedMonths: null),
        (distance: '', months: '6', expectedDistance: null, expectedMonths: 6),
      ]) {
        testWidgets(
          'saves distance "${scenario.distance}" and months "${scenario.months}" and refreshes',
          (tester) async {
            final harness = Harness(
              vehicle: samples.santaFe,
              initialSchedules: samples.sampleSchedules,
            );
            final schedules = ScheduleRobot(tester);
            final form = ScheduleFormRobot(tester);
            await harness.pumpLoadedScreen(tester);
            await schedules.tapNewSchedule();
            await form.enterName('  Inspection  ');
            await form.enterDistance(scenario.distance);
            await form.enterMonths(scenario.months);
            await form.enterDetails('  Check brakes  ');

            final pending = harness.repo.pauseNextCreate();
            await form.saveForm();
            expect(form.saveButton.enabled, isFalse);
            expect(findScheduleFormScreen, findsOneWidget);
            expect(harness.repo.schedules.length, equals(2));

            pending.complete();
            await tester.pumpAndSettle();

            expect(findScheduleFormScreen, findsNothing);
            expect(findScheduleScreen, findsOneWidget);
            expect(harness.repo.listCalls, equals(2));
            final created = harness.repo.schedules.values.singleWhere(
              (s) => s.name == 'Inspection',
            );
            expect(created.vehicleId, equals(samples.santaFe.id));
            expect(created.intervalDistance, equals(scenario.expectedDistance));
            expect(created.intervalMonths, equals(scenario.expectedMonths));
            expect(created.details, equals('Check brakes'));
            expectSchedulesVisible([samples.oilChange, created]);
            expect(find.text(samples.tireRotation.name), findsNothing);
          },
        );
      }

      testWidgets(
        'rejects blank names, missing intervals, and nonpositive or noninteger intervals',
        (tester) async {
          final harness = Harness(vehicle: samples.santaFe);
          final form = ScheduleFormRobot(tester);
          await harness.pumpLoadedScreen(tester);
          await ScheduleRobot(tester).tapNewSchedule();
          await form.enterName('  ');
          await form.saveForm();

          expect(form.nameError, isNotEmpty);
          expect(form.distanceError, isNotEmpty);
          expect(form.monthsError, isNotEmpty);
          expect(harness.repo.schedules, isEmpty);

          await form.enterName('Inspection');
          for (final invalid in ['0', '-1', '1.5', 'abc']) {
            await form.enterDistance(invalid);
            await form.enterMonths('6');
            await form.saveForm();
            expect(form.distanceError, isNotEmpty);
            expect(harness.repo.schedules, isEmpty);

            await form.enterDistance('7500');
            await form.enterMonths(invalid);
            await form.saveForm();
            expect(form.monthsError, isNotEmpty);
            expect(harness.repo.schedules, isEmpty);
          }
        },
      );

      testWidgets('failed save preserves inputs and enables a successful retry', (tester) async {
        final harness = Harness(vehicle: samples.santaFe);
        final form = ScheduleFormRobot(tester);
        await harness.pumpLoadedScreen(tester);
        await ScheduleRobot(tester).tapNewSchedule();
        await form.enterName('Inspection');
        await form.enterDistance('7500');
        await form.enterMonths('6');
        await form.enterDetails('Check brakes');
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
        expect(harness.repo.listCalls, equals(1));

        await form.saveForm(pump: .settle);

        expect(findScheduleFormScreen, findsNothing);
        expect(harness.repo.schedules, hasLength(1));
        expect(harness.repo.listCalls, equals(2));
        expectSchedulesVisible(harness.repo.schedules.values.toList());
      });
    });

    testWidgets('Delete is disabled until schedule deletion is implemented', (tester) async {
      final harness = Harness(vehicle: samples.santaFe, initialSchedules: [samples.oilChange]);
      final schedules = ScheduleRobot(tester);
      await harness.pumpLoadedScreen(tester);

      await schedules.tapScheduleMenu(samples.oilChange.id);

      final delete = find.byWidgetPredicate(
        (widget) => widget is PopupMenuItem<ScheduleAction> && widget.value == .delete,
      );
      expect(delete, findsOneWidget);
      expect(tester.widget<PopupMenuItem<ScheduleAction>>(delete).enabled, isFalse);
    });

    testWidgets('can leave while a request is pending', (tester) async {
      final harness = Harness(vehicle: samples.santaFe);
      final pending = harness.repo.pauseNextList();
      await harness.pumpScreen(tester);

      await tester.pumpWidget(const SizedBox());
      pending.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}

void expectSchedulesVisible(List<Schedule> schedules) {
  for (final schedule in schedules) {
    final row = find.byKey(ScheduleScreen.scheduleKey(schedule.id));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text(schedule.name)), findsOneWidget);
    if (schedule.details.isNotEmpty) {
      expect(find.descendant(of: row, matching: find.text(schedule.details)), findsOneWidget);
    }
  }
}

class Harness({required final Vehicle vehicle, Iterable<Schedule> initialSchedules = const []}) {
  final repo = InMemorySchedulesRepo(initialSchedules: initialSchedules);

  Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: ScheduleScreen(vehicle: vehicle, repo: repo),
    ),
  );

  Future<void> pumpLoadedScreen(WidgetTester tester) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();
  }
}
