import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'env_config.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  // Optimistic startup — corrected immediately by _initConnectivity.
  // Keeping true means screens attempt API on first load; if actually offline
  // the HTTP timeout (10s) will fail fast and fall back to cache.
  bool _isConnected = true;
  Timer? _debounceTimer;

  bool get isConnected => _isConnected;

  ConnectivityService() {
    _initConnectivity();
    _connectivity.onConnectivityChanged.listen(_scheduleCheck);
  }

  Future<void> _initConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    await _checkAndUpdate(results);
  }

  // Debounce rapid adapter flaps (e.g. wifi switching) before doing DNS probe.
  void _scheduleCheck(List<ConnectivityResult> results) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _checkAndUpdate(results);
    });
  }

  Future<void> _checkAndUpdate(List<ConnectivityResult> results) async {
    final hasAdapter =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    final wasConnected = _isConnected;

    _isConnected = hasAdapter ? await _isReachable() : false;

    if (wasConnected != _isConnected) {
      _connectionStatusController.add(_isConnected);
    }
  }

  /// DNS lookup on the API host to verify actual internet reachability, not
  /// just adapter state. Skips for localhost / IP addresses (dev mode).
  Future<bool> _isReachable() async {
    try {
      final uri = Uri.tryParse(EnvConfig.apiBaseUrl);
      final host = uri?.host ?? 'google.com';

      // Local dev: trust adapter state — no DNS probe needed.
      if (host == 'localhost' ||
          host == '127.0.0.1' ||
          RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host)) {
        return true;
      }

      final result =
          await InternetAddress.lookup(host).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    final hasAdapter =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    _isConnected = hasAdapter ? await _isReachable() : false;
    return _isConnected;
  }

  void dispose() {
    _debounceTimer?.cancel();
    _connectionStatusController.close();
  }
}
