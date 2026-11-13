import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tw_app/testing/stub.dart' as stub;
import 'package:tw_app/time/clock.dart';
import 'package:tw_app/ui/garage/garage_screen.dart';

import '../../use_case.dart';

void main() {
  group('GarageScreen', () {
    group('Loading', () {
      testWidgets('load and show empty', (WidgetTester tester) async {
        final h = Harness();
        h.repo.vehicles.clear();
        final completer = h.repo.lockList();
        await h.setup(tester);

        expect(find.byType(CircularProgressIndicator), findsOne);
        expectUserName(tester, 'Begelme');

        completer.complete();
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.textContaining('Nothing'), findsOne);
      });

      testWidgets('load and show vehicles', (WidgetTester tester) async {
        final h = Harness();
        final completer = h.repo.lockList();
        await h.setup(tester);

        expect(find.byType(CircularProgressIndicator), findsOne);
        expectUserName(tester, 'Begelme');

        completer.complete();
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);

        expectVehiclesLoaded();
      });

      testWidgets('load, error, restart', (WidgetTester tester) async {
        final h = Harness();
        var completer = h.repo.lockList();
        await h.setup(tester);

        expect(find.byType(CircularProgressIndicator), findsOne);
        expectUserName(tester, 'Begelme');
        expect(find.byType(CircularProgressIndicator), findsOne);

        completer.completeError(Exception('Network error'));
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.textContaining('Nothing'), findsNothing);

        completer = h.repo.lockList();
        await tester.tap(find.byKey(GarageScreen.retryButtonKey));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOne);

        completer.complete();
        await tester.pumpAndSettle();

        expectVehiclesLoaded();
      });

      testWidgets('repo is reused', (WidgetTester tester) async {
        final h = Harness();
        await h.setup(tester, userName: 'First');
        await tester.pumpAndSettle();

        expect(h.repo.listCalls, equals(1));
        expectUserName(tester, 'First');
        expectVehiclesLoaded();

        await h.setup(tester, userName: 'Second');
        await tester.pumpAndSettle();

        expectUserName(tester, 'Second');
        expectVehiclesLoaded();
        expect(h.repo.listCalls, equals(1));
      });
    });

    group('Add a Vehicle', () {
      testWidgets('open the form, navigate back', (WidgetTester tester) async {
        final useCase = GarageUC(tester);
        final h = Harness();
        await h.setup(tester);
        await tester.pumpAndSettle();
        await useCase.tapAddNewVehicleButton(settle: true);

        expect(findVehicleFormScreen, findsOne);
        expect(findGarageScreen, findsNothing);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(findVehicleFormScreen, findsNothing);
        expect(findGarageScreen, findsOne);
        expectVehiclesLoaded();
      });

      testWidgets('open the form, add a vehicle', (WidgetTester tester) async {
        final h = Harness();
        await h.setup(tester);
        await tester.pumpAndSettle();

        expect(h.repo.listCalls, equals(1));

        final uc = VehicleFormUC(tester);
        await uc.tapAddNewVehicleButton(settle: true);
        await uc.enterName('New Car');
        await uc.selectDistanceUnit('km');
        await uc.selectDayAndConfirm('2');
        await uc.saveForm(settle: true);

        expect(findGarageScreen, findsOne);
        expect(findVehicleFormScreen, findsNothing);
        expect(h.repo.listCalls, equals(2));
        expectVehiclesLoaded();
        expect(find.text('New Car'), findsOne);
      });
    });

    group('Edit a Vehicle', () {
      testWidgets('open the form, edit a vehicle', (WidgetTester tester) async {
        final h = Harness();
        await h.setup(tester);
        await tester.pumpAndSettle();

        final uc = VehicleFormUC(tester);
        await uc.tapVehicleMenuEdit(stub.vehicles.first.id);

        expect(findGarageScreen, findsNothing);
        expect(findVehicleFormScreen, findsOne);

        await uc.enterName('New Name');
        await uc.selectDayAndConfirm('13');
        await uc.saveForm(settle: true);

        expect(h.repo.vehicles[stub.vehicles.first.id]?.name, equals('New Name'));
        expect(h.repo.vehicles[stub.vehicles.first.id]?.manufactureDate.day, equals(13));
        expect(findGarageScreen, findsOne);
        expect(findVehicleFormScreen, findsNothing);
        expect(find.text(stub.vehicle1.name), findsNothing);
        expect(find.text('New Name'), findsOne);
      });
    });
  });
}

void expectUserName(WidgetTester tester, String name) =>
    expect(UseCase(tester).userNameText.data, equals(name));

void expectVehiclesLoaded() {
  expect(find.byType(CircularProgressIndicator), findsNothing);
  expect(find.textContaining('Nothing'), findsNothing);
  expect(find.text(stub.vehicle1.name), findsOne);
  expect(find.text(stub.vehicle2.name), findsOne);
}

class ClockMock extends Mock implements Clock;

class Harness {
  final repo = stub.InMemoryVehicleRepo();
  final clock = ClockMock();

  new() {
    when(() => clock.now()).thenReturn(DateTime(2009, 10, 15));
  }

  Future<void> setup(WidgetTester tester, {String userName = 'Begelme'}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GarageScreen(onLogout: () async {}, userName: userName, repo: repo, clock: clock),
      ),
    );
  }
}
