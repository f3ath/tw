import 'package:flutter/material.dart';
import 'package:tw_app/domain/vehicle.dart';

class const GarageScreen({
  super.key,
  required final Future<void> Function() onLogout,
  required final String userName,
  required final List<Vehicle> vehicles,
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
    body: vehicles.isEmpty
        ? Center(child: Text('Nothing yet LMAO'))
        : ListView.builder(
            itemCount: vehicles.length,
            itemBuilder: (BuildContext context, int index) =>
                ListTile(key: ValueKey(vehicles[index].id), title: Text(vehicles[index].name)),
          ),
  );
}
