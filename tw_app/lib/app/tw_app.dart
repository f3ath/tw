import 'package:material_ui/material_ui.dart';
import 'package:tw_app/app/auth_service.dart';
import 'package:tw_app/app/vehicle_repo.dart';
import 'package:shared/model.dart';
import 'package:tw_app/ui/garage/garage_screen.dart';
import 'package:tw_app/ui/welcome/welcome_screen.dart';

class const TwApp({
  super.key,
  required final AuthService authService,
  required final VehicleRepo vehicleRepo,
}) extends StatefulWidget {
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
          ? GarageScreen(onLogout: logout, userName: user.name, repo: widget.vehicleRepo)
          : WelcomeScreen(onLogin: login),
    );
  }

  Future<void> login() async {
    final user = await widget.authService.login();
    if (!mounted) return;
    setState(() {
      _user = user;
    });
  }

  Future<void> logout() async {
    setState(() {
      _user = null;
    });
    await widget.authService.logout();
  }
}
