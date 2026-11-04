import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tw_app/app/tw_app.dart';
import 'package:tw_app/ui/garage/garage_screen.dart';
import 'package:tw_app/ui/welcome/welcome_screen.dart';

void main() {
  testWidgets('Login opens Garage, Logout returns to Welcome', (WidgetTester tester) async {
    final findWelcomeScreen = find.byType(WelcomeScreen);
    final findGarageScreen = find.byType(GarageScreen);
    final findLoginButton = find.byKey(WelcomeScreen.loginButtonKey);
    final findLogoutButton = find.byKey(GarageScreen.logoutButtonKey);

    await tester.pumpWidget(const TwApp());

    expect(findWelcomeScreen, findsOneWidget);
    expect(findGarageScreen, findsNothing);

    expect(tester.widget<FilledButton>(findLoginButton).onPressed, isNotNull);

    await tester.tap(findLoginButton);
    await tester.pump();

    expect(tester.widget<FilledButton>(findLoginButton).onPressed, isNull);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(findWelcomeScreen, findsNothing);
    expect(findGarageScreen, findsOneWidget);

    await tester.tap(findLogoutButton);
    await tester.pumpAndSettle();

    expect(findWelcomeScreen, findsOneWidget);
    expect(findGarageScreen, findsNothing);
  });
}
