import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Memeriksa izin...';
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    debugPrint('=== SPLASH SCREEN INIT START ===');
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      debugPrint('Splash: Starting permission check');
      
      // Skip permission checks on desktop platforms (Linux, Windows, macOS)
      if (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        debugPrint('Splash: Desktop platform detected, skipping permission checks');
        setState(() {
          _statusMessage = 'Memuat aplikasi...';
          _permissionsGranted = true;
        });
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          widget.onComplete();
        }
        return;
      }
      
      if (!mounted) {
        debugPrint('Splash: Widget not mounted, aborting');
        return;
      }
      
      setState(() {
        _statusMessage = 'Memeriksa izin lokasi...';
      });

      // Check location permission with timeout
      debugPrint('Splash: Checking location permission...');
      bool locationGranted = false;
      try {
        locationGranted = await _requestLocationPermission()
            .timeout(const Duration(seconds: 10));
        debugPrint('Splash: Location permission result: $locationGranted');
      } catch (e) {
        debugPrint('Splash: Location permission error/timeout: $e');
        // Continue anyway - permission can be requested later
      }
      
      if (!mounted) {
        debugPrint('Splash: Widget unmounted after location check');
        return;
      }
      
      if (!locationGranted) {
        debugPrint('Splash: Location not granted, showing dialog');
        _showPermissionDialog(
          'Izin Lokasi Diperlukan',
          'Aplikasi memerlukan akses lokasi untuk mencatat kehadiran Anda.',
          () => _checkAndRequestPermissions(),
        );
        return;
      }

      setState(() {
        _statusMessage = 'Memeriksa izin kamera...';
      });

      // Check camera permission with timeout
      debugPrint('Splash: Checking camera permission...');
      bool cameraGranted = false;
      try {
        cameraGranted = await _requestCameraPermission()
            .timeout(const Duration(seconds: 10));
        debugPrint('Splash: Camera permission result: $cameraGranted');
      } catch (e) {
        debugPrint('Splash: Camera permission error/timeout: $e');
        // Continue anyway
      }
      
      if (!mounted) {
        debugPrint('Splash: Widget unmounted after camera check');
        return;
      }
      
      if (!cameraGranted) {
        debugPrint('Splash: Camera not granted, showing dialog');
        _showPermissionDialog(
          'Izin Kamera Diperlukan',
          'Aplikasi memerlukan akses kamera untuk mengambil foto selfie saat absen.',
          () => _checkAndRequestPermissions(),
        );
        return;
      }

      setState(() {
        _statusMessage = 'Semua izin diberikan!';
        _permissionsGranted = true;
      });

      debugPrint('Splash: All permissions granted, completing in 500ms');
      // Wait a bit before completing
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        debugPrint('Splash: Calling onComplete callback');
        widget.onComplete();
        debugPrint('=== SPLASH SCREEN COMPLETE ===');
      } else {
        debugPrint('Splash: Widget unmounted, cannot complete');
      }
    } catch (e, stackTrace) {
      debugPrint('Splash: Fatal error in _checkAndRequestPermissions: $e');
      debugPrint('Splash: StackTrace: $stackTrace');
      
      // On error, still try to complete to avoid stuck screen
      if (mounted) {
        setState(() {
          _statusMessage = 'Terjadi kesalahan, melanjutkan...';
        });
        
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          debugPrint('Splash: Completing despite error');
          widget.onComplete();
        }
      }
    }
  }

  Future<bool> _requestLocationPermission() async {
    try {
      debugPrint('Splash: Checking location service enabled...');
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('Splash: Location service enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        if (mounted) {
          debugPrint('Splash: Showing enable location dialog');
          _showEnableLocationDialog();
        }
        return false;
      }

      debugPrint('Splash: Checking location permission...');
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('Splash: Current location permission: $permission');
      
      if (permission == LocationPermission.denied) {
        debugPrint('Splash: Requesting location permission...');
        permission = await Geolocator.requestPermission();
        debugPrint('Splash: Location permission after request: $permission');
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('Splash: Location permission denied forever');
        if (mounted) {
          _showOpenSettingsDialog('Lokasi');
        }
        return false;
      }

      final granted = permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
      debugPrint('Splash: Location permission granted: $granted');
      return granted;
    } catch (e) {
      debugPrint('Splash: Error in _requestLocationPermission: $e');
      return false;
    }
  }

  Future<bool> _requestCameraPermission() async {
    try {
      debugPrint('Splash: Checking camera permission status...');
      PermissionStatus status = await Permission.camera.status;
      debugPrint('Splash: Current camera status: $status');
      
      if (status.isDenied) {
        debugPrint('Splash: Requesting camera permission...');
        status = await Permission.camera.request();
        debugPrint('Splash: Camera status after request: $status');
      }
      
      if (status.isPermanentlyDenied) {
        debugPrint('Splash: Camera permission permanently denied');
        if (mounted) {
          _showOpenSettingsDialog('Kamera');
        }
        return false;
      }

      final granted = status.isGranted;
      debugPrint('Splash: Camera permission granted: $granted');
      return granted;
    } catch (e) {
      debugPrint('Splash: Error in _requestCameraPermission: $e');
      return false;
    }
  }

  void _showEnableLocationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Aktifkan Lokasi'),
        content: const Text(
          'Layanan lokasi tidak aktif. Silakan aktifkan lokasi di pengaturan perangkat Anda.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _checkAndRequestPermissions();
            },
            child: const Text('Coba Lagi'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await Geolocator.openLocationSettings();
              await Future.delayed(const Duration(seconds: 1));
              _checkAndRequestPermissions();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  void _showOpenSettingsDialog(String permissionName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Izin $permissionName'),
        content: Text(
          'Izin $permissionName telah ditolak secara permanen. Silakan aktifkan di pengaturan aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _checkAndRequestPermissions();
            },
            child: const Text('Coba Lagi'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
              await Future.delayed(const Duration(seconds: 1));
              _checkAndRequestPermissions();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog(String title, String message, VoidCallback onRetry) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry();
            },
            child: const Text('Berikan Izin'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.fingerprint,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              const Text(
                'Absen MNC University',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 48),
              if (!_permissionsGranted) ...[
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.check_circle,
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Siap digunakan!',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
