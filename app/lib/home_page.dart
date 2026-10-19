import 'package:flutter/material.dart';
import 'package:app/auth/login_control.dart';
import 'package:app/auth/login_controller.dart';

class const HomePage({
  super.key,
  required final String title,
  required final LoginController loginController,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: Text(title),
      actions: [
        LoginControl(controller: loginController),
        const SizedBox(width: 8),
      ],
    ),
  );
}
