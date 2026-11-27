import 'package:material_ui/material_ui.dart';
import 'package:app/app/auth/auth_exceptions.dart';

class const WelcomeScreen({super.key, required final Future<void> Function() onLogin})
    extends StatefulWidget {
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();

  static const errorSnackBarKey = ValueKey('welcome-error-snackbar');
  static const loginButtonKey = ValueKey('google-login-button');
}

class _WelcomeScreenState() extends State<WelcomeScreen> {
  var _isLoggingIn = false;

  Future<void> _login() async {
    setState(() {
      _isLoggingIn = true;
    });
    try {
      await widget.onLogin();
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    } on UserCancelledException {
      // no error
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              key: WelcomeScreen.errorSnackBarKey,
              content: Text('Login failed. Please try again.'),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 317,
                child: AspectRatio(
                  aspectRatio: 317 / 66,
                  child: Image.asset(
                    'assets/brand/torquewrench-logo-dark.png',
                    semanticLabel: 'TorqueWrench',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: WelcomeScreen.loginButtonKey,
                onPressed: _isLoggingIn ? null : _login,
                child: Text(_isLoggingIn ? 'Logging in...' : 'Login with Google'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
