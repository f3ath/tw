import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:app/app/repository_provider.dart';
import 'package:shared/model.dart';
import 'package:app/testing/fixed_clock.dart';
import 'package:app/testing/samples.dart' as samples;
import 'package:app/testing/stub.dart';
import 'package:app/ui/services/service_form_screen.dart';

import '../../robots.dart';

void main() {
  group('ServiceFormScreen validation', () {
    for (final input in ['', '   ', '-1', '1.5', 'abc']) {
      testWidgets('rejects invalid odometer "$input"', (tester) async {
        final harness = Harness();
        final form = ServiceFormRobot(tester);
        await harness.pumpForm(tester);
        await form.enterOdometer(input);

        await form.saveForm();

        expect(form.odometerError, isNotEmpty);
        expect(form.dateError, isNull);
        expect(harness.repo.services, isEmpty);
      });
    }

    for (final input in ['0', '12345', ' 42 ']) {
      testWidgets('accepts odometer "$input"', (tester) async {
        final harness = Harness();
        final form = ServiceFormRobot(tester);
        await harness.pumpForm(tester);
        await form.enterOdometer(input);

        await form.saveForm(pump: .settle);

        expect(await harness.result, same(harness.repo.services.values.single));
        expect(harness.repo.services.values.single.odometer, equals(int.parse(input.trim())));
      });
    }

    testWidgets('requires a date', (tester) async {
      final harness = Harness();
      final form = ServiceFormRobot(tester);
      await harness.pumpForm(tester);
      await form.enterOdometer('0');
      await form.setDateValue(null);

      await form.saveForm();

      expect(form.dateError, isNotEmpty);
      expect(form.odometerError, isNull);
      expect(harness.repo.services, isEmpty);
    });

    for (final date in [DateTime(2020), DateTime(2026, 12, 6), DateTime(2099, 12, 31)]) {
      testWidgets('accepts date $date without a seven-day limit', (tester) async {
        final harness = Harness();
        final form = ServiceFormRobot(tester);
        await harness.pumpForm(tester);
        await form.enterOdometer('0');
        await form.setDateValue(date);

        await form.saveForm(pump: .settle);

        expect(await harness.result, same(harness.repo.services.values.single));
        expect(harness.repo.services.values.single.date, equals(date));
      });
    }

    testWidgets('date picker uses the shared date range', (tester) async {
      final harness = Harness();
      final form = ServiceFormRobot(tester);
      await harness.pumpForm(tester);
      await form.openDatePicker();

      expect(form.datePicker.firstDate, equals(DateTime(1900)));
      expect(form.datePicker.lastDate, equals(DateTime(2100)));
    });

    for (final scenario in [
      (input: '', expected: ''),
      (input: '   ', expected: ''),
      (input: '  Oil change\nChecked brakes  ', expected: 'Oil change\nChecked brakes'),
    ]) {
      testWidgets('allows optional details and trims "${scenario.input}" on save', (tester) async {
        final harness = Harness();
        final form = ServiceFormRobot(tester);
        await harness.pumpForm(tester);
        await form.enterOdometer('0');
        await form.enterDetails(scenario.input);

        await form.saveForm(pump: .settle);

        expect(await harness.result, same(harness.repo.services.values.single));
        expect(harness.repo.services.values.single.details, equals(scenario.expected));
      });
    }
  });

  group('ServiceFormScreen submission', () {
    testWidgets('creates a service for the selected vehicle and returns success', (tester) async {
      final harness = Harness();
      final form = ServiceFormRobot(tester);
      await harness.pumpForm(tester);
      await form.selectDayAndConfirm('13');
      await form.enterOdometer(' 12345 ');
      await form.enterDetails('  Oil change  ');

      await form.saveForm(pump: .settle);

      expect(await harness.result, same(harness.repo.services.values.single));
      expect(findServiceFormScreen, findsNothing);
      final service = harness.repo.services.values.single;
      expect(service.vehicleId, equals(samples.santaFe.id));
      expect(service.date, equals(DateTime(2026, 11, 13)));
      expect(service.odometer, equals(12345));
      expect(service.details, equals('Oil change'));
    });

    testWidgets('disables fields, guards repeat saves, and retains inputs for retry', (
      tester,
    ) async {
      final harness = Harness();
      final form = ServiceFormRobot(tester);
      await harness.pumpForm(tester);
      final selectedDate = DateTime(2026, 11, 14);
      await form.selectDayAndConfirm('14');
      await form.enterOdometer(' 42 ');
      await form.enterDetails('  Oil change  ');
      final pending = harness.repo.pauseNextCreate();

      await form.saveForm(pump: .none);
      await form.saveForm();

      expect(form.saveButton.enabled, isFalse);
      expect(form.odometerEnabled, isFalse);
      expect(form.detailsEnabled, isFalse);
      expect(form.dateEnabled, isFalse);
      await form.openDatePicker();
      expect(form.findDatePickerDialog, findsNothing);
      expect(harness.repo.services, isEmpty);

      pending.completeError(Exception('Network error'));
      await tester.pumpAndSettle();

      expect(form.findSaveError, findsOneWidget);
      expect(form.saveButton.enabled, isTrue);
      expect(form.odometerEnabled, isTrue);
      expect(form.detailsEnabled, isTrue);
      expect(form.dateEnabled, isTrue);
      expect(form.odometer, equals(' 42 '));
      expect(form.details, equals('  Oil change  '));
      expect(form.selectedDate, equals(selectedDate));
      expect(harness.repo.services, isEmpty);

      final retry = harness.repo.pauseNextCreate();
      await form.saveForm(pump: .none);
      await form.saveForm();
      retry.complete();
      await tester.pumpAndSettle();

      expect(await harness.result, same(harness.repo.services.values.single));
      final created = harness.repo.services.values.single;
      expect(created.odometer, equals(42));
      expect(created.date, equals(selectedDate));
      expect(created.details, equals('Oil change'));
    });

    testWidgets('Back returns without creating a service', (tester) async {
      final harness = Harness();
      final form = ServiceFormRobot(tester);
      await harness.pumpForm(tester);
      await form.enterOdometer('42');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(await harness.result, isNull);
      expect(harness.repo.services, isEmpty);
    });

    for (final fails in [false, true]) {
      testWidgets('can leave while creation later ${fails ? 'fails' : 'succeeds'}', (tester) async {
        final harness = Harness();
        final form = ServiceFormRobot(tester);
        await harness.pumpForm(tester);
        await form.enterOdometer('0');
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

  group('ServiceFormScreen editing', () {
    for (final (vehicle, service) in [
      (samples.santaFe, samples.santaFeOilService),
      (samples.fourRunner, samples.fourRunnerTireService),
    ]) {
      testWidgets('prefills ${vehicle.name} service values', (tester) async {
        final harness = Harness(vehicle: vehicle, service: service);
        final form = ServiceFormRobot(tester);
        await harness.pumpForm(tester);

        expect(find.text('Edit Service'), findsOneWidget);
        expect(form.selectedDate, equals(service.date));
        expect(form.odometer, equals(service.odometer.toString()));
        expect(form.details, equals(service.details));
        expect(form.distanceUnitLabel, equals(vehicle.distanceUnit.name));
      });
    }

    testWidgets('updates the original service, clears details, and returns success', (
      tester,
    ) async {
      final service = samples.santaFeOilService;
      final harness = Harness(service: service, initialServices: samples.sampleServices);
      final form = ServiceFormRobot(tester);
      await harness.pumpForm(tester);
      await form.selectDayAndConfirm('13');
      await form.enterOdometer(' 123456 ');
      await form.enterDetails('   ');
      final pending = harness.repo.pauseNextUpdate();

      await form.saveForm(pump: .none);
      await form.saveForm(); // validated by updateCalls==1

      expect(form.saveButton.enabled, isFalse);
      expect(form.dateEnabled, isFalse);
      expect(form.odometerEnabled, isFalse);
      expect(form.detailsEnabled, isFalse);
      expect(harness.repo.services[service.id], same(service));
      expect(harness.repo.updateCalls, equals(1));
      pending.complete();
      await tester.pumpAndSettle();

      final result = await harness.result;
      expect(result, isA<Service>());
      expect(result!.id, equals(service.id));
      expect(result.vehicleId, equals(service.vehicleId));
      expect(findServiceFormScreen, findsNothing);
      expect(harness.repo.services, hasLength(2));
      final updated = harness.repo.services[service.id]!;
      expect(updated.id, equals(service.id));
      expect(updated.vehicleId, equals(service.vehicleId));
      expect(updated.date, equals(DateTime(2026, 11, 13)));
      expect(updated.odometer, equals(123456));
      expect(updated.details, isEmpty);
      expect(result.date, equals(updated.date));
      expect(result.odometer, equals(updated.odometer));
      expect(result.details, equals(updated.details));
      expect(
        harness.repo.services[samples.fourRunnerTireService.id],
        same(samples.fourRunnerTireService),
      );
    });

    testWidgets('failed update retains edits and permits retry without creating another service', (
      tester,
    ) async {
      final service = samples.santaFeOilService;
      final harness = Harness(service: service, initialServices: samples.sampleServices);
      final form = ServiceFormRobot(tester);
      await harness.pumpForm(tester);
      await form.selectDayAndConfirm('14');
      await form.enterOdometer(' 123456 ');
      await form.enterDetails('  Inspection  ');
      final pending = harness.repo.pauseNextUpdate();

      await form.saveForm();
      pending.completeError(Exception('Network error'));
      await tester.pumpAndSettle();

      expect(form.findSaveError, findsOneWidget);
      expect(form.saveButton.enabled, isTrue);
      expect(form.dateEnabled, isTrue);
      expect(form.odometerEnabled, isTrue);
      expect(form.detailsEnabled, isTrue);
      expect(form.selectedDate, equals(DateTime(2026, 11, 14)));
      expect(form.odometer, equals(' 123456 '));
      expect(form.details, equals('  Inspection  '));
      expect(harness.repo.services[service.id], same(service));
      expect(harness.repo.services, hasLength(2));

      await form.saveForm(pump: .settle);

      final result = await harness.result;
      expect(result, isA<Service>());
      expect(result!.id, equals(service.id));
      expect(result.vehicleId, equals(service.vehicleId));
      expect(harness.repo.services, hasLength(2));
      final updated = harness.repo.services[service.id]!;
      expect(updated.date, equals(DateTime(2026, 11, 14)));
      expect(updated.odometer, equals(123456));
      expect(updated.details, equals('Inspection'));
      expect(result.date, equals(updated.date));
      expect(result.odometer, equals(updated.odometer));
      expect(result.details, equals(updated.details));
    });

    testWidgets('invalid edits do not update the service', (tester) async {
      final service = samples.santaFeOilService;
      final harness = Harness(service: service, initialServices: [service]);
      final form = ServiceFormRobot(tester);
      await harness.pumpForm(tester);
      await form.enterOdometer('-1');
      await form.setDateValue(null);

      await form.saveForm();

      expect(form.odometerError, isNotEmpty);
      expect(form.dateError, isNotEmpty);
      expect(findServiceFormScreen, findsOneWidget);
      expect(harness.repo.services.values.single, same(service));
    });

    testWidgets('Back discards edits without updating the service', (tester) async {
      final service = samples.santaFeOilService;
      final harness = Harness(service: service, initialServices: [service]);
      final form = ServiceFormRobot(tester);
      await harness.pumpForm(tester);
      await form.enterOdometer('999');
      await form.enterDetails('Changed');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(await harness.result, isNull);
      expect(harness.repo.services.values.single, same(service));
    });
  });
}

class Harness({
  final Vehicle? vehicle,
  final Service? service,
  Iterable<Service> initialServices = const [],
}) {
  final repo = InMemoryServiceRepo(initialServices: initialServices);
  final _navigatorKey = GlobalKey<NavigatorState>();
  late Future<Service?> result;

  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      RepositoryProvider(
        vehicleRepo: InMemoryVehicleRepo(),
        scheduleRepo: InMemoryScheduleRepo(),
        serviceRepo: repo,
        operationRepo: InMemoryOperationRepo(),
        child: MaterialApp(navigatorKey: _navigatorKey, home: const Scaffold()),
      ),
    );
    result = _navigatorKey.currentState!.push<Service>(
      MaterialPageRoute(
        builder: (_) => ServiceFormScreen(
          vehicle: vehicle ?? samples.santaFe,
          service: service,
          clock: FixedClock(DateTime(2026, 11, 28, 15, 30)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}
