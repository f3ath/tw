import 'package:flutter/material.dart';
import 'package:tw_app/application/auth/auth_exceptions.dart';

class const WelcomeScreen({super.key, required final Future<void> Function() onLogin})
    extends StatefulWidget {
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();

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
            .showSnackBar(const SnackBar(content: Text('Login failed. Please try again.')));
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
        child: FilledButton(
          key: WelcomeScreen.loginButtonKey,
          onPressed: _isLoggingIn ? null : _login,
          child: Text(_isLoggingIn ? 'Logging in...' : 'Login with Google'),
        ),
      ),
    ),
  );
}
