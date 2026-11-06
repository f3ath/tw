import 'package:flutter/material.dart';
import 'package:tw_app/domain/user.dart';
import 'package:tw_app/ui/garage/garage_screen.dart';
import 'package:tw_app/ui/welcome/welcome_screen.dart';

class const TwApp({super.key, required final AuthServicePort _authService}) extends StatefulWidget {
  @override
  State<TwApp> createState() => _TwAppState();
}

class _TwAppState() extends State<TwApp> {
  var _isLoggedIn = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Torque Wrench',
    theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
    home: _isLoggedIn ? GarageScreen(onLogout: logout) : WelcomeScreen(onLogin: login),
  );

  Future<void> login() async {
    await widget._authService.login();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = true;
    });
  }

  Future<void> logout() async {
    await widget._authService.logout();
    setState(() {
      _isLoggedIn = false;
    });
  }
}

/// Authentication handling
abstract interface class AuthServicePort {
  Future<User> login({Duration pollInterval, Duration pollTimeout});

  Future<void> logout();
}
