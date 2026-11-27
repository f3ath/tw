import 'package:json_api/document.dart';
import 'package:server/src/services/operations_dao.dart';
import 'package:server/src/services/operation_resource.dart';
import 'package:server/src/services/services_dao.dart';
import 'package:shared/api.dart';

class ServiceResource(ServiceRecord record) extends Resource {
  this : super(ResourceType.services, record.id) {
    attributes.addAll({
      'date': record.date.toIsoDateString(),
      'odometer': record.odometer,
      'details': record.details,
    });
    relationships['vehicle'] = ToOne(Identifier(ResourceType.vehicles, record.vehicleId));
  }
}

class ServicesWithOperationsDocument(
  Iterable<ServiceRecord> services,
  List<OperationRecord>? operations,
) extends OutboundDataDocument {
  this
    : super.collection(
        operations == null
            ? services.map(ServiceResource.new)
            : _servicesWithLinkage(services, operations),
      ) {
    if (operations != null) included.addAll(operations.map(OperationResource.new));
  }

  static Iterable<ServiceResource> _servicesWithLinkage(
    Iterable<ServiceRecord> services,
    Iterable<OperationRecord> operations,
  ) {
    final identifiersByService = <String, List<Identifier>>{};
    for (final operation in operations) {
      (identifiersByService[operation.serviceId] ??= []).add(
        Identifier(ResourceType.operations, operation.id),
      );
    }
    return services.map(
      (service) =>
          ServiceResource(service)
            ..relationships['operations'] = ToMany(identifiersByService[service.id] ?? []),
    );
  }

  @override
  Map<String, Object?> toJson() => {...super.toJson(), 'included': included};
}
