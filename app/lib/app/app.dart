import 'package:material_ui/material_ui.dart';
import 'package:app/app/auth_service.dart';
import 'package:app/app/vehicle_repo.dart';
import 'package:app/app/schedule_repo.dart';
import 'package:app/app/service_repo.dart';
import 'package:app/app/repository_provider.dart';
import 'package:app/app/operation_repo.dart';
import 'package:shared/model.dart';
import 'package:app/ui/garage/garage_screen.dart';
import 'package:app/ui/welcome/welcome_screen.dart';

class const TwApp({
  super.key,
  required final AuthService authService,
  required final VehicleRepo vehicleRepo,
  required final ScheduleRepo scheduleRepo,
  required final ServiceRepo serviceRepo,
  required final OperationRepo operationRepo,
}) extends StatefulWidget {
  @override
  State<TwApp> createState() => _TwAppState();
}

class _TwAppState() extends State<TwApp> {
  User? _user;

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return RepositoryProvider(
      vehicleRepo: widget.vehicleRepo,
      scheduleRepo: widget.scheduleRepo,
      serviceRepo: widget.serviceRepo,
      operationRepo: widget.operationRepo,
      child: MaterialApp(
        title: 'Torque Wrench',
        theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
        home: user != null
            ? GarageScreen(onLogout: logout, userName: user.name)
            : WelcomeScreen(onLogin: login),
      ),
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
