import 'dart:typed_data';

import '../core/network/api_client.dart';
import '../models/delivery.dart';

/// Result of the delivery list (items + pagination).
class DeliveryPage {
  const DeliveryPage({required this.deliveries, required this.total});

  final List<Delivery> deliveries;
  final int total;
}

/// Delivery workflow service. All calls are authenticated as the rider and
/// the backend enforces ownership + the state machine.
class DeliveryService {
  DeliveryService(this._api);

  final ApiClient _api;

  /// List the rider's deliveries. [filter] can be:
  /// all | new | accepted | pickup | in_transit | delivered | failed | cancelled
  Future<DeliveryPage> list({String filter = 'all', int page = 1}) async {
    final data = await _api.get('/rider/deliveries', query: {
      'status': filter,
      'page': page,
    });

    List<Delivery> list = [];
    if (data['deliveries'] is List) {
      list = (data['deliveries'] as List)
          .whereType<Map<String, dynamic>>()
          .map(Delivery.fromJson)
          .toList();
    }

    final total = (data['pagination']?['total'] as num?)?.toInt() ?? list.length;

    return DeliveryPage(deliveries: list, total: total);
  }

  Future<Delivery> detail(int id) async {
    final data = await _api.get('/rider/deliveries/$id');
    return Delivery.fromJson(
        Map<String, dynamic>.from(data['delivery'] as Map? ?? {}));
  }

  Future<Delivery> accept(int id) async {
    final data = await _api.post('/rider/deliveries/$id/accept');
    return Delivery.fromJson(
        Map<String, dynamic>.from(data['delivery'] as Map? ?? {}));
  }

  Future<Delivery> updateStatus(int id, String status) async {
    final data = await _api.patch('/rider/deliveries/$id/status', body: {
      'status': status,
    });
    return Delivery.fromJson(
        Map<String, dynamic>.from(data['delivery'] as Map? ?? {}));
  }

  Future<Delivery> pickup(int id, {String? pickupPin}) async {
    final data = await _api.post('/rider/deliveries/$id/pickup', body: {
      'pickup_pin': ?pickupPin,
    });
    return Delivery.fromJson(
        Map<String, dynamic>.from(data['delivery'] as Map? ?? {}));
  }

  /// Complete a delivery. Supports photo proof via [photoBytes] and COD
  /// settlement via [amountReceived].
  Future<Delivery> complete(
    int id, {
    String proofType = 'signature',
    Uint8List? photoBytes,
    String? photoFilename,
    String? signatureName,
    String? otp,
    double? amountReceived,
    double? latitude,
    double? longitude,
  }) async {
    final fields = <String, String>{
      'proof_type': proofType,
      'signature_name': ?signatureName,
      'otp': ?otp,
      if (amountReceived != null)
        'amount_received': amountReceived.toStringAsFixed(2),
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
    };

    final dynamic data;
    if (photoBytes != null) {
      data = await _api.postMultipart(
        '/rider/deliveries/$id/complete',
        fileField: 'photo',
        fileBytes: photoBytes,
        filename: photoFilename ?? 'proof.jpg',
        fields: fields,
      );
    } else {
      data = await _api.post('/rider/deliveries/$id/complete', body: fields);
    }

    return Delivery.fromJson(
        Map<String, dynamic>.from(data['delivery'] as Map? ?? {}));
  }

  Future<Delivery> failed(
    int id, {
    required String reason,
    String? notes,
  }) async {
    final data = await _api.post('/rider/deliveries/$id/failed', body: {
      'reason': reason,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return Delivery.fromJson(
        Map<String, dynamic>.from(data['delivery'] as Map? ?? {}));
  }
}