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

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(samples.santaFe.name), findsOneWidget);
      expect(find.text(samples.oilChange.name), findsNothing);

      pending.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
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

      expect(find.text('No schedules yet'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
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

      expect(find.text('Error loading schedules'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No schedules yet'), findsNothing);

      final retry = harness.repo.pauseNextList();
      await schedules.tapRetry();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      retry.complete();
      await tester.pumpAndSettle();

      expect(find.text('Error loading schedules'), findsNothing);
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
