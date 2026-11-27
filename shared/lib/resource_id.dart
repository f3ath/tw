import 'package:uuid/uuid.dart';

abstract final class ResourceId {
  static const _uuid = Uuid();

  static String generate() => _uuid.v4();

  // The first digit of the third group is the version.
  static bool isValid(String id) => Uuid.isValidUUID(fromString: id) && id[14] == '4';
}
