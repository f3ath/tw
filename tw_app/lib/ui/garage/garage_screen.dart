import 'package:flutter/material.dart';

class const GarageScreen({
  super.key,
  required final Future<void> Function() onLogout,
  required final String userName,
}) extends StatelessWidget {
  static const userNameTextKey = ValueKey('user-name-text');
  static const logoutButtonKey = ValueKey('logout-button');

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Garage'),
      actions: [
        Text(userName, key: userNameTextKey, maxLines: 1, overflow: TextOverflow.ellipsis),
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
}
