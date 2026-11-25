import 'dart:async';
import 'package:flutter/services.dart';
import 'acoustic_sentinel_service.dart';

class HardwareSosService {
  static final HardwareSosService _instance = HardwareSosService._internal();
  factory HardwareSosService() => _instance;
  HardwareSosService._internal();

  static const MethodChannel _channel = MethodChannel('com.vinkiar.os/hardware_sos');

  Function()? onEmergencyTriggered;

  void initialize({Function()? onEmergency}) {
    if (onEmergency != null) {
      onEmergencyTriggered = onEmergency;
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSosTriggered') {
        _detonateEmergency();
      }
    });
  }

  void _detonateEmergency() {
    _channel.invokeMethod('vibrateEmergencyPattern');

    if (onEmergencyTriggered != null) {
      onEmergencyTriggered!();
    } else {
      AcousticSentinelService().triggerEmergencyProtocol();
    }
  }

  /// Minimiza la aplicación al escritorio sin destruir el motor de Flutter en memoria
  Future<void> exitToHome() async {
    try {
      await _channel.invokeMethod('exitToHome');
    } catch (_) {}
  }

  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final res = await _channel.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  void simulateHardwarePanic() {
    _detonateEmergency();
  }
}