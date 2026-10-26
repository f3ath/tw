import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/composition.dart';
import 'package:app/app/torque_wrench_app.dart';
import 'package:app/data/repositories/local_repositories.dart';
import 'package:app/data/services/services.dart';
import 'package:app/ui/forms/form_view_models.dart';
import 'package:app/ui/forms/form_views.dart';

import 'support/fakes.dart';

Composition app(MemoryStorage store) {
  final simulation = DemoSimulation(delay: Duration.zero);
  var id = 0;
  return Composition(
    demo: simulation,
    auth: LocalAuthRepository(store, const MockAuthService(), simulation),
    maintenance: LocalMaintenanceRepository(
      store,
      simulation,
      clock: () => DateTime(2026, 10, 25),
      idGenerator: () => 'id-${id++}',
    ),
    settings: LocalSettingsRepository(store),
    clock: () => DateTime(2026, 10, 25),
  );
}

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('TW_CAPTURE')) {
      const fonts = String.fromEnvironment('TW_FONT_DIR');
      if (fonts.isNotEmpty) {
        for (final entry in {
          'Roboto': 'Roboto-Regular.ttf',
          'MaterialIcons': 'MaterialIcons-Regular.otf',
        }.entries) {
          final loader = FontLoader(entry.key);
          loader.addFont(
            File('$fonts/${entry.value}').readAsBytes().then((b) => ByteData.sublistView(b)),
          );
          await loader.load();
        }
      }
    }
  });
  for (final width in [390.0, 1100.0]) {
    testWidgets('login, preview/more, responsive navigation and mileage save at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = app(MemoryStorage());
      await tester.pumpWidget(TorqueWrenchApp(composition: c));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('2 more...'), findsOneWidget);
      await tester.tap(find.text('2 more...'));
      await tester.pumpAndSettle();
      expect(find.text('Maintenance due'), findsNothing);
      expect(find.text('Log service'), findsOneWidget);
      if (const bool.fromEnvironment('TW_CAPTURE')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${Directory.systemTemp.path}/torquewrench-$width.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(find.byType(NavigationRail), width >= 840 ? findsOneWidget : findsNothing);
      await tester.tap(find.text('Log service'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Overdue suggestions'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Odometer'), '91500');
      await tester.scrollUntilVisible(
        find.text('Save').last,
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(find.text('No maintenance operations recorded.'), findsOneWidget);
      final router =
          Router.of(tester.element(find.byType(NavigationBar))).routerDelegate as TorqueRouter;
      expect(router.currentConfiguration.path, startsWith('/service/'));
      expect(c.garage.data.history('runner').first.mileage, 91500);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
  testWidgets('past date removes suggestions and dirty navigation prompts before leaving', (
    tester,
  ) async {
    final c = app(MemoryStorage());
    await tester.pumpWidget(TorqueWrenchApp(composition: c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 more...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log service'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Date'), '2026-10-24');
    await tester.pumpAndSettle();
    expect(find.text('Overdue suggestions'), findsNothing);
    expect(find.text('Scheduled maintenance'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Log service'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('200 percent text scale form remains scrollable without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeMaintenanceRepository();
    final vm = ServiceFormViewModel(repo, repo.data.vehicle('v'), DateTime(2026, 10, 25));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: ServiceFormView(model: vm, onSave: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
  testWidgets('deep link waits for login; expiry preserves draft; missing IDs stay unavailable', (
    tester,
  ) async {
    final c = app(MemoryStorage());
    final router = TorqueRouter(c);
    await c.session.restore();
    await tester.pumpWidget(
      MaterialApp.router(routerDelegate: router, routeInformationParser: TorqueRouteParser()),
    );
    await tester.pumpAndSettle();
    await router.setNewRoutePath(Uri.parse('/vehicle/runner'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.text('Log service'), findsOneWidget);
    await tester.tap(find.text('Log service'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Odometer'), '91500');
    c.toggleOffline();
    await tester.pumpAndSettle();
    expect(find.textContaining('Offline · showing saved data'), findsOneWidget);
    expect(find.text('91500'), findsOneWidget);
    c.toggleOffline();
    await tester.pumpAndSettle();
    c.session.expire();
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar).hitTestable(), findsNothing);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.text('91500'), findsOneWidget);
    final navigation = router.setNewRoutePath(Uri.parse('/vehicle/unknown'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    await navigation;
    expect(find.text('Not found or unavailable. Back to vehicles'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    c.dispose();
  });
}
