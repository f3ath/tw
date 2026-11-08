import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tw_app/app/auth/auth_exceptions.dart';
import 'package:tw_app/data/auth/auth_api.dart';
import 'package:tw_app/data/auth/backend_auth_service.dart';
import 'package:tw_app/data/auth/login_window.dart';
import 'package:shared/model.dart';
import 'package:tw_app/time/clock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(Duration());
  });
  group('AuthService', () {
    final oauthUri = Uri.parse('https://example.com');
    final user = User('id', name: 'name', email: 'email');
    late AuthApi authApi;
    late LoginWindow window;

    setUp(() {
      authApi = AuthApiMock();
      window = LoginWindowMock();
      // Default behavior, gets overridden in some tests
      when(() => window.isClosed).thenReturn(false);
      when(() => authApi.startLogin()).thenAnswer((_) async => oauthUri);
      when(() => window.navigate(oauthUri)).thenAnswer((_) async {});
    });

    group('login()', () {
      test('successful', () async {
        var newWindowCalled = false;

        final service = BackendAuthService(
          authApi: authApi,
          newWindow: () {
            newWindowCalled = true;
            return window;
          },
        );

        var calls = 0;
        when(() => authApi.getCurrentUser()).thenAnswer((_) async => calls++ > 4 ? user : null);

        final result = service.login(pollInterval: Duration(milliseconds: 10));
        expect(newWindowCalled, isTrue); // window opened synchronously

        expect(await result, same(user));
        verifyInOrder([
          () => authApi.startLogin(),
          () => window.navigate(oauthUri),
          () => authApi.getCurrentUser(),
          () => window.close(),
        ]);
      });

      for (final sync in [true, false]) {
        test('closes the window when startLogin fails ${sync ? 'sync' : 'async'}', () async {
          final service = BackendAuthService(authApi: authApi, newWindow: () => window);

          final error = Exception('Network error');
          if (sync) {
            when(() => authApi.startLogin()).thenThrow(error);
          } else {
            when(() => authApi.startLogin()).thenAnswer((_) async => throw error);
          }

          await expectLater(service.login(), throwsA(same(error)));

          verifyInOrder([() => authApi.startLogin(), () => window.close()]);
          verifyNever(() => window.navigate(any()));
          verifyNever(() => authApi.getCurrentUser());
        });
      }

      test('closes the window when getCurrentUser fails', () async {
        final service = BackendAuthService(authApi: authApi, newWindow: () => window);
        final error = Exception('Network error');

        when(() => authApi.getCurrentUser()).thenAnswer((_) async => throw error);

        await expectLater(service.login(), throwsA(same(error)));

        verifyInOrder([
          () => authApi.startLogin(),
          () => window.navigate(oauthUri),
          () => authApi.getCurrentUser(),
          () => window.close(),
        ]);
      });

      test('throws TimeoutException if user never completes login', () async {
        final clock = ClockMock();
        final service = BackendAuthService(authApi: authApi, newWindow: () => window, clock: clock);

        var inDelay = false;

        when(() => authApi.getCurrentUser()).thenAnswer((_) {
          expect(inDelay, isFalse);
          return Future.value(null);
        });

        const tenSeconds = Duration(seconds: 10);

        final time = DateTime.utc(2026);
        var elapsed = 0;
        when(() => clock.now()).thenAnswer((_) => time.add(Duration(seconds: elapsed)));

        when(() => clock.delayed<void>(any())).thenAnswer((i) {
          expect(inDelay, isFalse);
          inDelay = true;
          expect(
            i.positionalArguments[0],
            equals(tenSeconds),
            reason: 'Provided pollInterval must be used',
          );
          return Future(() {
            elapsed += 10;
            inDelay = false;
          });
        });

        final result = service.login(pollInterval: tenSeconds, pollTimeout: Duration(seconds: 30));

        await expectLater(result, throwsA(isA<TimeoutException>()));

        verifyInOrder([
          () => authApi.startLogin(),
          () => window.navigate(oauthUri),
          () => authApi.getCurrentUser(),
          () => window.close(),
        ]);
        verify(() => clock.delayed<void>(any())).called(3); // pollTimeout / pollInterval
      });

      test('aborts polling when user closes the window', () async {
        final service = BackendAuthService(authApi: authApi, newWindow: () => window);

        when(() => authApi.getCurrentUser()).thenAnswer((_) async {
          // user closes the window!
          when(() => window.isClosed).thenReturn(true);
          return null;
        });

        await expectLater(
          service.login(pollInterval: Duration(milliseconds: 10)),
          throwsA(isA<UserCancelledException>()),
        );
        verifyNever(() => window.close()); // already closed
        verify(() => authApi.getCurrentUser()).called(1); // loop breaks
      });
    });
  });
}

class LoginWindowMock extends Mock implements LoginWindow;

class AuthApiMock extends Mock implements AuthApi;

class ClockMock extends Mock implements Clock;
