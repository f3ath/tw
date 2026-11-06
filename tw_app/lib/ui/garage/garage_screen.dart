import 'package:flutter/material.dart';

class const GarageScreen({super.key, required final Future<void> Function() onLogout})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Garage'),
      actions: [
        IconButton(
          key: logoutButtonKey,
          onPressed: onLogout,
          icon: Icon(Icons.logout),
          tooltip: 'Logout',
        ),
      ],
    ),
    body: Center(child: Text('Nothing yet LMAO')),
  );
  static const logoutButtonKey = ValueKey('logout-button');
}
