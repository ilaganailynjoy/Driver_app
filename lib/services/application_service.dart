import 'dart:typed_data';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';

class RiderApplicationStatus {
  const RiderApplicationStatus({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    this.submittedVia,
    this.createdAt,
    this.reviewedAt,
    this.notes,
  });
  final int id;
  final String name;
  final String email;
  final String status;
  final String? submittedVia;
  final String? createdAt;
  final String? reviewedAt;
  final String? notes;
  factory RiderApplicationStatus.fromJson(Map<String, dynamic> j) => RiderApplicationStatus(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        status: j['status'] as String? ?? 'pending',
        submittedVia: j['submitted_via'] as String?,
        createdAt: j['created_at'] as String?,
        reviewedAt: j['reviewed_at'] as String?,
        notes: j['notes'] as String?,
      );
}

class ApplicationService {
  ApplicationService(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> submit({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String vehicleType,
    required String licensePlate,
    required String licenseNumber,
    required String vehicleRegistration,
    required Map<String, ({Uint8List bytes, String filename})> documents,
  }) async {
    final fields = {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'vehicle_type': vehicleType,
      'license_plate': licensePlate,
      'license_number': licenseNumber,
      'vehicle_registration': vehicleRegistration,
    };
    final files = <String, ({Uint8List bytes, String filename})>{};
    documents.forEach((k, v) => files['documents[$k]'] = v);
    return await _api.postMultipartMany('/rider/apply', files: files, fields: fields) as Map<String, dynamic>;
  }

  Future<RiderApplicationStatus?> getStatus(String email) async {
    try {
      final data = await _api.get('/rider/application-status', query: {'email': email});
      final app = data['application'] as Map?;
      if (app == null) return null;
      return RiderApplicationStatus.fromJson(Map<String, dynamic>.from(app));
    } on ApiException catch (e) {
      if (e.type == ApiErrorType.notFound) return null;
      rethrow;
    }
  }
}
