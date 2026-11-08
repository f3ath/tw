import 'package:flutter/material.dart';
import 'package:tw_app/application/vehicle_repo.dart';
import 'package:tw_app/ui/garage/garage_view_model.dart';

class const GarageScreen({
  super.key,
  required final Future<void> Function() onLogout,
  required final String userName,
  required final VehicleRepo repo,
}) extends StatefulWidget {
  static const userNameTextKey = ValueKey('user-name-text');
  static const logoutButtonKey = ValueKey('logout-button');
  static const retryButtonKey = ValueKey('retry-button');

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  late final GarageViewModel model;

  @override
  void initState() {
    super.initState();
    model = GarageViewModel(vehicleRepository: widget.repo);
    model.load();
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Garage'),
      actions: [
        Text(
          widget.userName,
          key: GarageScreen.userNameTextKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        IconButton(
          key: GarageScreen.logoutButtonKey,
          onPressed: widget.onLogout,
          icon: Icon(Icons.logout),
          tooltip: 'Logout',
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: model,
      builder: (_, _) {
        if (model.isLoading) {
          return Center(child: CircularProgressIndicator());
        }
        if (model.hasError) {
          return Center(
            child: Column(
              children: [
                Text('Error loading vehicles :('),
                FilledButton(
                  key: GarageScreen.retryButtonKey,
                  onPressed: model.load,
                  child: Text('Retry.'),
                ),
              ],
            ),
          );
        }
        if (model.vehicles.isEmpty) {
          return Center(child: Text('Nothing yet LMAO 2'));
        }
        return ListView.builder(
          itemCount: model.vehicles.length,
          itemBuilder: (BuildContext context, int index) => ListTile(
            key: ValueKey(model.vehicles[index].id),
            title: Text(model.vehicles[index].name),
          ),
        );
      },
    ),
  );
}
