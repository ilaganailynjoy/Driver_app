import '../core/network/api_client.dart';
import '../models/rider.dart';

/// Authentication service (login / logout / session).
class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  Future<({String token, Rider rider})> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post('/login', body: {
      'email': email,
      'password': password,
    });

    final token = data['token'] as String? ?? '';
    if (token.isEmpty) {
      throw Exception('Login failed: no token returned.');
    }

    final riderMap =
        Map<String, dynamic>.from((data['user'] as Map?)?['rider'] as Map? ?? {});
    final rider = Rider.fromJson(riderMap);

    return (token: token, rider: rider);
  }

  Future<void> logout() async {
    await _api.post('/logout');
  }
}