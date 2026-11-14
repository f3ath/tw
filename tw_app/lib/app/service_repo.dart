import 'package:shared/model.dart';

abstract interface class ServiceRepo {
  Future<List<Service>> list(String vehicleId);
}
