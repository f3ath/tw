import 'package:flutter/material.dart';
import 'package:tw_app/domain/user.dart';
import 'package:tw_app/ui/garage/garage_screen.dart';
import 'package:tw_app/ui/welcome/welcome_screen.dart';

class const TwApp({super.key, required final AuthServicePort _authService}) extends StatefulWidget {
  @override
  State<TwApp> createState() => _TwAppState();
}

class _TwAppState() extends State<TwApp> {
  User? _user;

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return MaterialApp(
      title: 'Torque Wrench',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: user != null
          ? GarageScreen(onLogout: logout, userName: user.name)
          : WelcomeScreen(onLogin: login),
    );
  }

  Future<void> login() async {
    final user = await widget._authService.login();
    if (!mounted) return;
    setState(() {
      _user = user;
    });
  }

  Future<void> logout() async {
    setState(() {
      _user = null;
    });
    await widget._authService.logout();
  }
}

/// Authentication handling
abstract interface class AuthServicePort {
  Future<User> login({Duration pollInterval, Duration pollTimeout});

  Future<void> logout();
}
