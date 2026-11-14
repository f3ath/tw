import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/testing/samples.dart' as samples;
import 'package:tw_app/testing/stub.dart';
import 'package:tw_app/ui/schedules/schedule_screen.dart';

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
      expect(form.saveButton.enabled, isTrue);
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

    testWidgets('saving a new schedule refreshes the selected vehicle list', (tester) async {
      final harness = Harness(vehicle: samples.santaFe, initialSchedules: samples.sampleSchedules);
      final schedules = ScheduleRobot(tester);
      final form = ScheduleFormRobot(tester);
      await harness.pumpLoadedScreen(tester);
      await schedules.tapNewSchedule();
      await form.enterName('Inspection');
      await form.enterMonths('6');

      await form.saveForm(pump: .settle);

      expect(findScheduleFormScreen, findsNothing);
      expect(findScheduleScreen, findsOneWidget);
      expect(harness.repo.listCalls, equals(2));
      final created = harness.repo.schedules.values.singleWhere((s) => s.name == 'Inspection');
      expectSchedulesVisible([samples.oilChange, created]);
      expect(find.text(samples.tireRotation.name), findsNothing);
    });

    testWidgets('Delete opens confirmation and Cancel preserves the list', (tester) async {
      final inspection = Schedule(
        id: 'inspection',
        vehicleId: samples.santaFe.id,
        name: 'Inspection',
        intervalDistance: null,
        intervalMonths: 6,
        details: '',
      );
      final harness = Harness(
        vehicle: samples.santaFe,
        initialSchedules: [samples.oilChange, inspection],
      );
      final schedules = ScheduleRobot(tester);
      await harness.pumpLoadedScreen(tester);

      await schedules.tapScheduleMenuDelete(inspection.id);

      final dialog = find.byKey(ScheduleScreen.deleteConfirmation);
      expect(dialog, findsOneWidget);
      expect(harness.repo.schedules, hasLength(2));

      await tester.tap(find.byKey(ScheduleScreen.cancelButton));
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expectSchedulesVisible([samples.oilChange, inspection]);
      expect(harness.repo.schedules, hasLength(2));
      expect(harness.repo.listCalls, equals(1));
    });

    testWidgets('dismissing deletion confirmation preserves the schedule without reloading', (
      tester,
    ) async {
      final harness = Harness(vehicle: samples.santaFe, initialSchedules: [samples.oilChange]);
      final schedules = ScheduleRobot(tester);
      await harness.pumpLoadedScreen(tester);
      await schedules.tapScheduleMenuDelete(samples.oilChange.id);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(ScheduleScreen.deleteConfirmation), findsNothing);
      expectSchedulesVisible([samples.oilChange]);
      expect(harness.repo.schedules[samples.oilChange.id], same(samples.oilChange));
      expect(harness.repo.listCalls, equals(1));
    });

    testWidgets('deleting the selected schedule preserves the other schedules', (tester) async {
      final inspection = Schedule(
        id: 'inspection',
        vehicleId: samples.santaFe.id,
        name: 'Inspection',
        intervalDistance: null,
        intervalMonths: 6,
        details: '',
      );
      final harness = Harness(
        vehicle: samples.santaFe,
        initialSchedules: [samples.oilChange, inspection, samples.tireRotation],
      );
      final schedules = ScheduleRobot(tester);
      final pending = harness.repo.pauseNextDelete();
      await harness.pumpLoadedScreen(tester);
      await schedules.tapScheduleMenuDelete(inspection.id);
      await tester.tap(find.byKey(ScheduleScreen.deleteButton));
      await tester.pump();

      expect(harness.repo.schedules, hasLength(3));
      expect(harness.repo.listCalls, equals(1));

      pending.complete();
      await tester.pumpAndSettle();

      expect(schedules.findScheduleCard(inspection.id), findsNothing);
      expectSchedulesVisible([samples.oilChange]);
      expect(harness.repo.schedules, hasLength(2));
      expect(harness.repo.schedules[samples.oilChange.id], same(samples.oilChange));
      expect(harness.repo.schedules[samples.tireRotation.id], same(samples.tireRotation));
      expect(harness.repo.listCalls, equals(2));
      expect(find.byKey(ScheduleScreen.emptyTextKey), findsNothing);
    });

    testWidgets('confirmed deletion removes the schedule and refreshes the list', (tester) async {
      final harness = Harness(vehicle: samples.santaFe, initialSchedules: [samples.oilChange]);
      await harness.pumpLoadedScreen(tester);
      await ScheduleRobot(tester).tapScheduleMenuDelete(samples.oilChange.id);

      await tester.tap(find.byKey(ScheduleScreen.deleteButton));
      await tester.pumpAndSettle();

      expect(find.byKey(ScheduleScreen.deleteConfirmation), findsNothing);
      expect(findScheduleScreen, findsOneWidget);
      expect(harness.repo.schedules, isEmpty);
      expect(find.byKey(ScheduleScreen.scheduleKey(samples.oilChange.id)), findsNothing);
      expect(find.byKey(ScheduleScreen.emptyTextKey), findsOneWidget);
      expect(harness.repo.listCalls, equals(2));
    });

    for (final scenario in [
      (name: 'retained', deleted: false),
      (name: 'deleted before the response fails', deleted: true),
    ]) {
      testWidgets('reloads after a deletion error when the schedule was ${scenario.name}', (
        tester,
      ) async {
        final harness = Harness(vehicle: samples.santaFe, initialSchedules: [samples.oilChange]);
        final schedules = ScheduleRobot(tester);
        final pending = harness.repo.pauseNextDelete();
        await harness.pumpLoadedScreen(tester);
        await schedules.tapScheduleMenuDelete(samples.oilChange.id);
        await tester.tap(find.byKey(ScheduleScreen.deleteButton));
        await tester.pump();
        expect(harness.repo.listCalls, equals(1));

        if (scenario.deleted) {
          // Simulate the server committing deletion before losing its response.
          harness.repo.schedules.remove(samples.oilChange.id);
        }
        pending.completeError(Exception('Network error'));
        await tester.pump();

        expect(find.byKey(ScheduleScreen.deleteErrorSnackBarKey), findsOneWidget);
        await tester.pumpAndSettle();

        expect(harness.repo.listCalls, equals(2));
        if (scenario.deleted) {
          expect(schedules.findScheduleCard(samples.oilChange.id), findsNothing);
          expect(find.byKey(ScheduleScreen.emptyTextKey), findsOneWidget);
        } else {
          expectSchedulesVisible([samples.oilChange]);
          expect(find.byKey(ScheduleScreen.emptyTextKey), findsNothing);
        }
      });
    }

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
  final repo = InMemoryScheduleRepo(initialSchedules: initialSchedules);

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
