import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tw_app/ui/garage/garage_screen.dart';

void main() {
  group('GarageScreen', () {
    testWidgets('shows user name', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GarageScreen(onLogout: () async {}, userName: 'Begelme'),
        ),
      );
      expect(tester.widget<Text>(find.byKey(GarageScreen.userNameTextKey)).data, equals('Begelme'));
    });
  });
}
