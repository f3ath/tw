import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tw_app/testing/samples.dart' as samples;
import 'package:tw_app/testing/stub.dart';
import 'package:tw_app/ui/schedules/schedule_screen.dart';

void main() {
  group('ScheduleScreen', () {
    testWidgets('loads only the selected vehicle schedules and does not reload on rebuild', (
      tester,
    ) async {
      final repo = InMemorySchedulesRepo(initialSchedules: samples.sampleSchedules);
      final pending = repo.pauseNextList();
      await tester.pumpWidget(
        MaterialApp(
          home: ScheduleScreen(vehicle: samples.santaFe, repo: repo),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(samples.santaFe.name), findsOneWidget);
      expect(find.text(samples.oilChange.name), findsNothing);

      pending.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(ScheduleScreen.scheduleKey(samples.oilChange.id)), findsOneWidget);
      expect(find.text(samples.oilChange.name), findsOneWidget);
      expect(find.text(samples.oilChange.details), findsOneWidget);
      expect(find.text(samples.tireRotation.name), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: ScheduleScreen(vehicle: samples.santaFe, repo: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.listCalls, equals(1));
      expect(find.text(samples.oilChange.name), findsOneWidget);
    });

    testWidgets('shows an empty state when the vehicle has no schedules', (tester) async {
      final repo = InMemorySchedulesRepo(initialSchedules: [samples.tireRotation]);
      await tester.pumpWidget(
        MaterialApp(
          home: ScheduleScreen(vehicle: samples.santaFe, repo: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No schedules yet'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('failed loading shows an error and can be retried', (tester) async {
      final repo = InMemorySchedulesRepo(initialSchedules: samples.sampleSchedules);
      final pending = repo.pauseNextList();
      await tester.pumpWidget(
        MaterialApp(
          home: ScheduleScreen(vehicle: samples.fourRunner, repo: repo),
        ),
      );

      pending.completeError(Exception('Network error'));
      await tester.pumpAndSettle();

      expect(find.text('Error loading schedules'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No schedules yet'), findsNothing);

      final retry = repo.pauseNextList();
      await tester.tap(find.byKey(ScheduleScreen.retryButtonKey));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      retry.complete();
      await tester.pumpAndSettle();

      expect(find.text('Error loading schedules'), findsNothing);
      expect(find.text(samples.tireRotation.name), findsOneWidget);
      expect(find.text(samples.oilChange.name), findsNothing);
      expect(repo.listCalls, equals(2));
    });

    testWidgets('can leave while a request is pending', (tester) async {
      final repo = InMemorySchedulesRepo();
      final pending = repo.pauseNextList();
      await tester.pumpWidget(
        MaterialApp(
          home: ScheduleScreen(vehicle: samples.santaFe, repo: repo),
        ),
      );

      await tester.pumpWidget(const SizedBox());
      pending.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
