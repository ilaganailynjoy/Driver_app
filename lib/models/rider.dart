/// Rider profile as returned by `/api/rider/profile` and `/api/login`.
class Rider {
  const Rider({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.vehicleType,
    this.licensePlate,
    this.status,
    this.isOnline = false,
    this.avatar,
    this.totalDeliveries = 0,
    this.completedDeliveries = 0,
    this.failedDeliveries = 0,
  });

  final int id;
  final String name;
  final String email;
  final String phone;
  final String? vehicleType;
  final String? licensePlate;
  final String? status;
  final bool isOnline;
  final String? avatar;
  final int totalDeliveries;
  final int completedDeliveries;
  final int failedDeliveries;

  factory Rider.fromJson(Map<String, dynamic> json) {
    return Rider(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      vehicleType: json['vehicle_type'] as String?,
      licensePlate: json['license_plate'] as String?,
      status: json['status'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
      avatar: json['avatar'] as String?,
      totalDeliveries: (json['total_deliveries'] as num?)?.toInt() ?? 0,
      completedDeliveries:
          (json['completed_deliveries'] as num?)?.toInt() ?? 0,
      failedDeliveries: (json['failed_deliveries'] as num?)?.toInt() ?? 0,
    );
  }

  Rider copyWith({bool? isOnline, String? phone, String? vehicleType, String? licensePlate}) {
    return Rider(
      id: id,
      name: name,
      email: email,
      phone: phone ?? this.phone,
      vehicleType: vehicleType ?? this.vehicleType,
      licensePlate: licensePlate ?? this.licensePlate,
      status: status,
      isOnline: isOnline ?? this.isOnline,
      avatar: avatar,
      totalDeliveries: totalDeliveries,
      completedDeliveries: completedDeliveries,
      failedDeliveries: failedDeliveries,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'vehicle_type': vehicleType,
        'license_plate': licensePlate,
        'status': status,
        'is_online': isOnline,
        'avatar': avatar,
        'total_deliveries': totalDeliveries,
        'completed_deliveries': completedDeliveries,
        'failed_deliveries': failedDeliveries,
      };
}