import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps the app's process alive while a band is connected.
///
/// Android kills backgrounded processes under memory pressure and throttles
/// them in Doze, which drops the BLE link. A foreground service with an
/// ongoing notification exempts us from both. The service itself does no BLE
/// work — flutter_blue_plus keeps running on the main isolate; the service
/// exists purely to hold the process at foreground priority.
///
/// iOS has no equivalent call: background BLE is declarative, granted by the
/// `bluetooth-central` entry in UIBackgroundModes, so every method here is a
/// no-op on iOS.
class BleBackgroundService {
  static const MethodChannel _channel =
      MethodChannel('com.vital101.vital/ble_service');

  static bool _running = false;
  static bool get isRunning => _running;

  /// Starts the ongoing notification. Safe to call repeatedly — the platform
  /// side updates the existing notification rather than stacking new ones.
  static Future<void> start({
    String title = 'Vitals 101',
    String message = 'Connected to your device',
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('start', {
        'title': title,
        'message': message,
      });
      _running = true;
    } on PlatformException catch (e) {
      debugPrint('Foreground service start failed: ${e.message}');
    } on MissingPluginException {
      // Platform side not wired up yet (e.g. a hot restart after adding it).
      debugPrint('Foreground service channel unavailable');
    }
  }

  /// Updates the notification text without tearing the service down.
  static Future<void> update({
    String title = 'Vitals 101',
    required String message,
  }) async {
    if (!Platform.isAndroid || !_running) return;
    try {
      await _channel.invokeMethod<void>('update', {
        'title': title,
        'message': message,
      });
    } on PlatformException catch (e) {
      debugPrint('Foreground service update failed: ${e.message}');
    } on MissingPluginException {
      // Nothing to update if the platform side isn't there.
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException catch (e) {
      debugPrint('Foreground service stop failed: ${e.message}');
    } on MissingPluginException {
      // Already gone.
    } finally {
      _running = false;
    }
  }
}
