import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';

/// Thin wrapper around the Xray core plugin.
class VpnService extends ChangeNotifier {
  VpnService() {
    _v2ray = V2ray(onStatusChanged: _onStatus);
  }

  late final V2ray _v2ray;
  V2RayStatus status = V2RayStatus();
  bool ready = false;
  String coreVersion = '';
  bool busy = false;

  String get state => status.state;
  bool get connected => status.state == 'CONNECTED';
  bool get connecting => busy || status.state == 'CONNECTING';

  void _onStatus(V2RayStatus s) {
    status = s;
    if (s.state == 'CONNECTED' || s.state == 'DISCONNECTED') busy = false;
    notifyListeners();
  }

  Future<void> init() async {
    try {
      await _v2ray.initialize(
        notificationIconResourceType: 'mipmap',
        notificationIconResourceName: 'ic_launcher',
      );
      ready = true;
      coreVersion = await _v2ray.getCoreVersion();
    } catch (e) {
      debugPrint('core init failed: $e');
    }
    notifyListeners();
  }

  /// Real (through-the-proxy) delay in ms, -1 on failure.
  Future<int> realDelay(String json, String url, {Duration timeout = const Duration(seconds: 12)}) async {
    if (!ready) return -1;
    try {
      final d = await _v2ray.getServerDelay(config: json, url: url).timeout(timeout);
      return d > 0 ? d : -1;
    } catch (_) {
      return -1;
    }
  }

  Future<int> connectedDelay(String url) async {
    try {
      final d = await _v2ray.getConnectedServerDelay(url: url).timeout(const Duration(seconds: 12));
      return d > 0 ? d : -1;
    } catch (_) {
      return -1;
    }
  }

  /// Returns an error message or null on success.
  Future<String?> start({
    required String remark,
    required String json,
    required bool proxyOnly,
    List<String>? blockedApps,
  }) async {
    if (!ready) return 'هسته Xray آماده نیست';
    busy = true;
    notifyListeners();
    try {
      if (!proxyOnly) {
        final ok = await _v2ray.requestPermission();
        if (!ok) {
          busy = false;
          notifyListeners();
          return 'اجازه VPN داده نشد';
        }
      }
      await _v2ray.startV2Ray(
        remark: remark,
        config: json,
        blockedApps: (blockedApps == null || blockedApps.isEmpty) ? null : blockedApps,
        proxyOnly: proxyOnly,
        notificationDisconnectButtonName: 'قطع اتصال',
      );
      // Safety: clear busy flag if no status arrives.
      Timer(const Duration(seconds: 15), () {
        if (busy) {
          busy = false;
          notifyListeners();
        }
      });
      return null;
    } catch (e) {
      busy = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> stop() async {
    try {
      await _v2ray.stopV2Ray();
    } catch (_) {}
    busy = false;
    notifyListeners();
  }
}
