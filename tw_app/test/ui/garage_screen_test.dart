import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tw_app/testing/stub.dart' as stub;
import 'package:tw_app/ui/garage/garage_screen.dart';

void main() {
  group('GarageScreen', () {
    testWidgets('shows user name', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GarageScreen(onLogout: () async {}, userName: 'Begelme', vehicles: []),
        ),
      );
      expect(tester.widget<Text>(find.byKey(GarageScreen.userNameTextKey)).data, equals('Begelme'));
    });

    testWidgets('empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GarageScreen(onLogout: () async {}, userName: 'Begelme', vehicles: []),
        ),
      );
      expect(find.textContaining('Nothing'), findsOne);
      expect(find.text(stub.vehicle1.name), findsNothing);
    });

    testWidgets('non empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GarageScreen(onLogout: () async {}, userName: 'Begelme', vehicles: stub.vehicles),
        ),
      );
      expect(find.textContaining('Nothing'), findsNothing);
      expect(find.text(stub.vehicle1.name), findsOne);
      expect(find.text(stub.vehicle2.name), findsOne);
    });
  });
}
