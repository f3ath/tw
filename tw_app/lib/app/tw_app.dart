import 'package:flutter/material.dart';
import 'package:tw_app/ui/garage/garage_screen.dart';
import 'package:tw_app/ui/welcome/welcome_screen.dart';

class const TwApp({super.key}) extends StatefulWidget {
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
    await Future<void>.delayed(Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _isLoggedIn = true;
    });
  }

  void logout() {
    setState(() {
      _isLoggedIn = false;
    });
  }
}
