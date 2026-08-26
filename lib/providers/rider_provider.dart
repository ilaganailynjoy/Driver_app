import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../models/delivery.dart';
import '../models/rider.dart';
import '../services/rider_service.dart';

/// Rider profile, availability and dashboard state.
class RiderProvider extends ChangeNotifier {
  RiderProvider(this._service);

  final RiderService _service;

  Rider? _rider;
  DashboardSummary? _dashboard;
  bool _loading = false;
  String? _error;
  bool _statusBusy = false;

  Rider? get rider => _rider;
  DashboardSummary? get dashboard => _dashboard;
  bool get loading => _loading;
  String? get error => _error;
  bool get statusBusy => _statusBusy;
  bool get isOnline => _rider?.isOnline ?? false;

  Future<void> loadProfile() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _rider = await _service.getProfile();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Unable to load profile. Please try again.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Refresh the dashboard. Returns `true` on success.
  Future<bool> loadDashboard() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _dashboard = await _service.getDashboard();
      _rider = _dashboard!.rider;
      _loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _loading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Unable to load dashboard. Please try again.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// Toggle the online/offline availability switch (synced with Laravel).
  Future<bool> toggleOnline() async {
    _statusBusy = true;
    notifyListeners();

    try {
      final target = _rider?.isOnline == true ? 'offline' : 'online';
      final updated = await _service.updateStatus(target);
      _rider = updated;
      if (_dashboard != null) {
        _dashboard = DashboardSummary(
          stats: _dashboard!.stats,
          todayEarnings: _dashboard!.todayEarnings,
          currentDelivery: _dashboard!.currentDelivery,
          upcomingPickup: _dashboard!.upcomingPickup,
          recentCompleted: _dashboard!.recentCompleted,
          unreadNotifications: _dashboard!.unreadNotifications,
          rider: updated,
        );
      }
      _statusBusy = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _statusBusy = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Unable to update your status. Please try again.';
      _statusBusy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    String? phone,
    String? vehicleType,
    String? licensePlate,
  }) async {
    _statusBusy = true;
    notifyListeners();

    try {
      final updated = await _service.updateProfile(
        phone: phone,
        vehicleType: vehicleType,
        licensePlate: licensePlate,
      );
      _rider = updated;
      _statusBusy = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _statusBusy = false;
      notifyListeners();
      return false;
    }
  }

  /// Called by the delivery provider when a delivery's status changes.
  void refreshDeliveryStatus(Delivery delivery) {
    if (_dashboard != null) {
      loadDashboard();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}