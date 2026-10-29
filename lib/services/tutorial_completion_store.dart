import 'package:shared_preferences/shared_preferences.dart';

/// Stores tutorial completion independently for each rider on this device.
/// This is local-only state and may be cleared when the app is reinstalled.
class TutorialCompletionStore {
  const TutorialCompletionStore();

  String _keyFor(int riderId) => 'invoiz_rider_tutorial_completed_$riderId';

  Future<bool> isCompleted(int riderId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_keyFor(riderId)) ?? false;
  }

  Future<void> markCompleted(int riderId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_keyFor(riderId), true);
  }
}
