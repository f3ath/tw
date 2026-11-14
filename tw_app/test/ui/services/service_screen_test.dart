import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/testing/samples.dart' as samples;
import 'package:tw_app/testing/stub.dart';
import 'package:tw_app/ui/services/service_screen.dart';

import '../../robots.dart';

void main() {
  group('ServiceScreen', () {
    testWidgets('shows only the selected vehicle services after loading', (tester) async {
      final harness = Harness(vehicle: samples.santaFe, initialServices: samples.sampleServices);
      final pending = harness.repo.pauseNextList();
      await harness.pumpScreen(tester);

      expect(find.byKey(ServiceScreen.loadingIndicatorKey), findsOneWidget);
      expect(find.text(samples.santaFe.name), findsOneWidget);
      expect(find.byKey(ServiceScreen.serviceKey(samples.santaFeOilService.id)), findsNothing);

      pending.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(ServiceScreen.loadingIndicatorKey), findsNothing);
      expectServicesVisible(tester, [samples.santaFeOilService]);
      expect(find.text('120,000 km'), findsOneWidget);
      expect(find.byKey(ServiceScreen.serviceKey(samples.fourRunnerTireService.id)), findsNothing);
    });

    testWidgets('rebuilding does not reload services', (tester) async {
      final harness = Harness(vehicle: samples.santaFe, initialServices: samples.sampleServices);
      await harness.pumpLoadedScreen(tester);
      expect(harness.repo.listCalls, equals(1));

      await harness.pumpLoadedScreen(tester);

      expect(harness.repo.listCalls, equals(1));
      expectServicesVisible(tester, [samples.santaFeOilService]);
    });

    testWidgets('shows an empty state when the vehicle has no services', (tester) async {
      final harness = Harness(
        vehicle: samples.santaFe,
        initialServices: [samples.fourRunnerTireService],
      );
      await harness.pumpLoadedScreen(tester);

      expect(find.byKey(ServiceScreen.emptyTextKey), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byKey(ServiceScreen.loadingIndicatorKey), findsNothing);
    });

    testWidgets('failed loading shows an error and can be retried', (tester) async {
      final harness = Harness(vehicle: samples.fourRunner, initialServices: samples.sampleServices);
      final services = ServiceRobot(tester);
      final pending = harness.repo.pauseNextList();
      await harness.pumpScreen(tester);

      pending.completeError(Exception('Network error'));
      await tester.pumpAndSettle();

      expect(find.byKey(ServiceScreen.errorTextKey), findsOneWidget);
      expect(find.byKey(ServiceScreen.loadingIndicatorKey), findsNothing);
      expect(find.byKey(ServiceScreen.emptyTextKey), findsNothing);

      final retry = harness.repo.pauseNextList();
      await services.tapRetry();
      expect(find.byKey(ServiceScreen.loadingIndicatorKey), findsOneWidget);

      retry.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(ServiceScreen.errorTextKey), findsNothing);
      expectServicesVisible(tester, [samples.fourRunnerTireService]);
      expect(find.text('45,000 mi'), findsOneWidget);
      expect(services.findServiceCard(samples.santaFeOilService.id), findsNothing);
      expect(harness.repo.listCalls, equals(2));
    });

    for (final vehicle in samples.sampleVehicles) {
      testWidgets('New Service opens the form for ${vehicle.name} and Back preserves the list', (
        tester,
      ) async {
        final harness = Harness(vehicle: vehicle, initialServices: samples.sampleServices);
        final services = ServiceRobot(tester);
        final form = ServiceFormRobot(tester);
        await harness.pumpLoadedScreen(tester);

        await services.tapNewService();

        expect(findServiceFormScreen, findsOneWidget);
        expect(findServiceScreen, findsNothing);
        expect(find.text(vehicle.name), findsOneWidget);
        expect(form.distanceUnitLabel, equals(vehicle.distanceUnit.name));
        expect(form.saveButton.enabled, isTrue);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(findServiceFormScreen, findsNothing);
        expect(findServiceScreen, findsOneWidget);
        expectServicesVisible(
          tester,
          samples.sampleServices.where((service) => service.vehicleId == vehicle.id).toList(),
        );
        expect(harness.repo.listCalls, equals(1));
      });
    }

    testWidgets('successful creation refreshes the selected vehicle history', (tester) async {
      final harness = Harness(vehicle: samples.santaFe, initialServices: samples.sampleServices);
      final services = ServiceRobot(tester);
      final form = ServiceFormRobot(tester);
      await harness.pumpLoadedScreen(tester);
      await services.tapNewService();
      await form.enterOdometer('123456');
      await form.enterDetails('New service');

      await form.saveForm(pump: .settle);

      expect(findServiceFormScreen, findsNothing);
      expect(findServiceScreen, findsOneWidget);
      expect(harness.repo.listCalls, equals(2));
      final created = harness.repo.services.values.singleWhere(
        (service) => service.details == 'New service',
      );
      expect(created.vehicleId, equals(samples.santaFe.id));
      expect(created.odometer, equals(123456));
      expectServicesVisible(tester, [samples.santaFeOilService, created]);
      expect(services.findServiceCard(samples.fourRunnerTireService.id), findsNothing);
    });

    for (final fails in [false, true]) {
      testWidgets('can leave while a request later ${fails ? 'fails' : 'succeeds'}', (
        tester,
      ) async {
        final harness = Harness(vehicle: samples.santaFe);
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

void expectServicesVisible(WidgetTester tester, List<Service> services) {
  for (final service in services) {
    final card = find.byKey(ServiceScreen.serviceKey(service.id));
    expect(card, findsOneWidget);
    final localizations = MaterialLocalizations.of(tester.element(card));
    expect(
      find.descendant(of: card, matching: find.text(localizations.formatShortDate(service.date))),
      findsOneWidget,
    );
    if (service.details.isNotEmpty) {
      expect(find.descendant(of: card, matching: find.text(service.details)), findsOneWidget);
    }
  }
}

class Harness({required final Vehicle vehicle, Iterable<Service> initialServices = const []}) {
  final repo = InMemoryServiceRepo(initialServices: initialServices);

  Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: ServiceScreen(vehicle: vehicle, repo: repo),
    ),
  );

  Future<void> pumpLoadedScreen(WidgetTester tester) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();
  }
}
