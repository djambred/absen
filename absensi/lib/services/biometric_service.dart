import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();
  
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _savedEmailKey = 'saved_email';
  static const String _savedPasswordKey = 'saved_password';
  
  // Check if device supports biometric
  Future<bool> canUseBiometric() async {
    // Skip on desktop platforms
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      debugPrint('BiometricService: Desktop platform - biometric not supported');
      return false;
    }
    
    try {
      debugPrint('BiometricService: Checking if device can use biometric...');
      final canCheck = await _localAuth.canCheckBiometrics;
      debugPrint('BiometricService: canCheckBiometrics = $canCheck');
      
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      debugPrint('BiometricService: isDeviceSupported = $isDeviceSupported');
      
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      debugPrint('BiometricService: availableBiometrics = $availableBiometrics');
      
      final result = canCheck && isDeviceSupported;
      debugPrint('BiometricService: canUseBiometric result = $result');
      return result;
    } catch (e) {
      debugPrint('BiometricService: canUseBiometric error: $e');
      return false;
    }
  }
  
  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }
  
  // Authenticate with biometric
  Future<bool> authenticate({String reason = 'Silakan verifikasi untuk login'}) async {
    try {
      debugPrint('=== BiometricService.authenticate START ===');
      debugPrint('Reason: $reason');
      
      // First check if biometric is available
      final canCheck = await _localAuth.canCheckBiometrics;
      debugPrint('canCheckBiometrics: $canCheck');
      
      if (!canCheck) {
        debugPrint('Biometric check not available on this device');
        return false;
      }
      
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      debugPrint('Available biometrics: $availableBiometrics');
      
      if (availableBiometrics.isEmpty) {
        debugPrint('No biometric types available');
        return false;
      }
      
      debugPrint('Calling _localAuth.authenticate()...');
      
      final result = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true, // Force biometric only to ensure popup appears
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
      
      debugPrint('=== BiometricService.authenticate END - result: $result ===');
      return result;
    } on PlatformException catch (e) {
      debugPrint('=== BiometricService.authenticate EXCEPTION ===');
      debugPrint('Code: ${e.code}');
      debugPrint('Message: ${e.message}');
      debugPrint('Details: ${e.details}');
      
      // Handle specific error codes
      if (e.code == 'NotAvailable') {
        debugPrint('ERROR: Biometric not available on device');
      } else if (e.code == 'NotEnrolled') {
        debugPrint('ERROR: No biometric enrolled - user needs to set up fingerprint/face in Settings');
      } else if (e.code == 'LockedOut') {
        debugPrint('ERROR: Biometric locked out due to too many attempts');
      } else if (e.code == 'PermanentlyLockedOut') {
        debugPrint('ERROR: Biometric permanently locked out');
      } else if (e.code == 'PasscodeNotSet') {
        debugPrint('ERROR: Device passcode not set');
      }
      
      return false;
    } catch (e, stackTrace) {
      debugPrint('=== BiometricService.authenticate UNEXPECTED ERROR ===');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
  }
  
  // Check if biometric login is enabled
  Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _storage.read(key: _biometricEnabledKey);
      return enabled == 'true';
    } catch (e) {
      debugPrint('BiometricService: Error reading biometric enabled status: $e');
      return false;
    }
  }
  
  // Enable biometric login and save credentials
  Future<void> enableBiometric({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('BiometricService.enableBiometric START - email: $email');
      
      debugPrint('Writing biometric_enabled = true');
      await _storage.write(key: _biometricEnabledKey, value: 'true');
      
      debugPrint('Writing saved_email = $email');
      await _storage.write(key: _savedEmailKey, value: email);
      
      debugPrint('Writing saved_password (length: ${password.length})');
      await _storage.write(key: _savedPasswordKey, value: password);
      
      // Verify immediately
      final enabledCheck = await _storage.read(key: _biometricEnabledKey);
      final emailCheck = await _storage.read(key: _savedEmailKey);
      final passCheck = await _storage.read(key: _savedPasswordKey);
      
      debugPrint('BiometricService.enableBiometric VERIFY:');
      debugPrint('  - enabled: $enabledCheck');
      debugPrint('  - email: $emailCheck');
      debugPrint('  - password exists: ${passCheck != null}');
      
      debugPrint('BiometricService.enableBiometric SUCCESS');
    } catch (e) {
      debugPrint('BiometricService.enableBiometric ERROR: $e');
      rethrow;
    }
  }
  
  // Disable biometric login
  Future<void> disableBiometric() async {
    await _storage.delete(key: _biometricEnabledKey);
    await _storage.delete(key: _savedEmailKey);
    await _storage.delete(key: _savedPasswordKey);
  }
  
  // Get saved credentials
  Future<Map<String, String>?> getSavedCredentials() async {
    final email = await _storage.read(key: _savedEmailKey);
    final password = await _storage.read(key: _savedPasswordKey);
    
    debugPrint('Getting saved credentials - Email: $email, Password exists: ${password != null}');
    
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }
}
