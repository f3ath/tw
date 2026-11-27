import 'package:material_ui/material_ui.dart';
import 'package:app/app/auth_service.dart';
import 'package:app/app/vehicle_repo.dart';
import 'package:app/app/schedule_repo.dart';
import 'package:app/app/service_repo.dart';
import 'package:app/app/repository_provider.dart';
import 'package:app/app/operation_repo.dart';
import 'package:shared/model.dart';
import 'package:app/ui/error_retry_view.dart';
import 'package:app/ui/garage/garage_screen.dart';
import 'package:app/ui/loading_view.dart';
import 'package:app/ui/theme/app_theme.dart';
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
  Future<User?>? _restoration;
  User? _user;

  @override
  void initState() {
    super.initState();
    _restoration = widget.authService.restoreSession();
  }

  @override
  Widget build(BuildContext context) => RepositoryProvider(
    vehicleRepo: widget.vehicleRepo,
    scheduleRepo: widget.scheduleRepo,
    serviceRepo: widget.serviceRepo,
    operationRepo: widget.operationRepo,
    child: MaterialApp(
      title: 'TorqueWrench DIY',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: FutureBuilder<User?>(future: _restoration, builder: (_, snapshot) => _home(snapshot)),
    ),
  );

  Widget _home(AsyncSnapshot<User?> snapshot) {
    if (snapshot.connectionState == .waiting) {
      return const Scaffold(body: LoadingView(indicatorKey: ValueKey('session-loading')));
    }
    if (snapshot.hasError) {
      return Scaffold(
        body: ErrorRetryView(
          message: 'Could not restore your session.',
          errorTextKey: const ValueKey('session-restore-error'),
          retryButtonKey: const ValueKey('session-restore-retry'),
          onRetry: () => setState(() => _restoration = widget.authService.restoreSession()),
        ),
      );
    }
    final user = _restoration == null ? _user : snapshot.data;
    return user != null
        ? GarageScreen(onLogout: logout, userName: user.name)
        : WelcomeScreen(onLogin: login);
  }

  Future<void> login() async {
    final user = await widget.authService.login();
    if (!mounted) return;
    setState(() {
      _restoration = null;
      _user = user;
    });
  }

  Future<void> logout() async {
    setState(() {
      _restoration = null;
      _user = null;
    });
    await widget.authService.logout();
  }
}
