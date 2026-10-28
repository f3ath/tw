import '../../domain/repositories.dart';
import '../services/api_auth_service.dart';

class ApiAuthRepository(final ApiAuthService service) implements AuthRepository {
  @override
  String? identity;

  @override
  Future<void> restore() async {
    identity = await service.restore();
  }

  @override
  Future<void> signIn() async {
    identity = await service.signIn();
  }

  @override
  Future<void> signOut() async {
    await service.signOut();
    identity = null;
  }
}
