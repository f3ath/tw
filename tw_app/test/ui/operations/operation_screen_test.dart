import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/testing/samples.dart' as samples;
import 'package:tw_app/testing/stub.dart';
import 'package:tw_app/ui/operations/operation_screen.dart';

import '../../robots.dart';

void main() {
  group('OperationScreen', () {
    for (final service in samples.sampleServices) {
      testWidgets('shows only ${service.id} operations after loading', (tester) async {
        final harness = Harness(service: service, initialOperations: samples.sampleOperations);
        final operations = OperationRobot(tester);
        final pending = harness.repo.pauseNextList();
        await harness.pumpScreen(tester);

        expect(find.byKey(OperationScreen.loadingIndicatorKey), findsOneWidget);
        expect(find.byKey(OperationScreen.emptyTextKey), findsNothing);
        expect(find.byType(ListTile), findsNothing);
        final localizations = MaterialLocalizations.of(tester.element(findOperationScreen));
        expect(find.textContaining(localizations.formatShortDate(service.date)), findsOneWidget);

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
        service: samples.fourRunnerTireService,
        initialOperations: samples.sampleOperations,
      );
      await harness.pumpLoadedScreen(tester);
      expect(harness.repo.listCalls, equals(1));

      await harness.pumpLoadedScreen(tester);

      expect(harness.repo.listCalls, equals(1));
      expectOperationsVisible(tester, [samples.tireRotationOperation]);
    });

    for (final fails in [false, true]) {
      testWidgets('can leave while a request later ${fails ? 'fails' : 'succeeds'}', (
        tester,
      ) async {
        final harness = Harness(service: samples.santaFeOilService);
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

class Harness({required final Service service, Iterable<Operation> initialOperations = const []}) {
  final repo = InMemoryOperationRepo(initialOperations: initialOperations);

  Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: OperationScreen(service: service, repo: repo),
    ),
  );

  Future<void> pumpLoadedScreen(WidgetTester tester) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();
  }
}
