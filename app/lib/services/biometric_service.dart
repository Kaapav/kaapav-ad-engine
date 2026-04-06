import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check whether biometric or device auth is available
  static Future<bool> isAvailable() async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheckBiometrics || isSupported;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    } catch (_) {
      return <BiometricType>[];
    }
  }

  /// Whether strong biometric exists
  static Future<bool> hasStrongBiometric() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.strong) ||
        biometrics.contains(BiometricType.fingerprint) ||
        biometrics.contains(BiometricType.face);
  }

  /// Main authentication
  ///
  /// Compatible with your currently installed local_auth API.
  /// This version keeps proper auth flow without using unsupported params
  /// like `options`, `stickyAuth`, or `useErrorDialogs`.
  static Future<bool> authenticate({
    String reason = 'Unlock Kaapav Ad Engine',
  }) async {
    try {
      final available = await isAvailable();
      if (!available) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Helper for startup unlock
  static Future<bool> authenticateForAppUnlock() async {
    return authenticate(
      reason: 'Authenticate to open Kaapav Ad Engine',
    );
  }

  /// Helper for sensitive actions if needed later
  static Future<bool> authenticateForSensitiveAction({
    String action = 'continue',
  }) async {
    return authenticate(
      reason: 'Authenticate to $action',
    );
  }
}