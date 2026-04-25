import 'package:flutter/widgets.dart';
import 'api_service.dart';

class DeviceHealthService with WidgetsBindingObserver {
  final ApiService _apiService;

  DeviceHealthService(this._apiService) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _log('app_resume');
    }
  }

  Future<void> logConnectivityDrop() async => _log('connectivity_drop');

  Future<void> _log(String eventType) async {
    try {
      await _apiService.logDeviceHealth(eventType: eventType);
    } catch (_) {}
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
