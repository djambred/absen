import 'package:flutter/material.dart';
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
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    setState(() {
      _statusMessage = 'Memeriksa izin lokasi...';
    });

    // Check location permission
    bool locationGranted = await _requestLocationPermission();
    
    if (!locationGranted) {
      _showPermissionDialog(
        'Izin Lokasi Diperlukan',
        'Aplikasi memerlukan akses lokasi untuk mencatat kehadiran Anda.',
        () => _requestLocationPermission(),
      );
      return;
    }

    setState(() {
      _statusMessage = 'Memeriksa izin kamera...';
    });

    // Check camera permission
    bool cameraGranted = await _requestCameraPermission();
    
    if (!cameraGranted) {
      _showPermissionDialog(
        'Izin Kamera Diperlukan',
        'Aplikasi memerlukan akses kamera untuk mengambil foto selfie saat absen.',
        () => _requestCameraPermission(),
      );
      return;
    }

    setState(() {
      _statusMessage = 'Semua izin diberikan!';
      _permissionsGranted = true;
    });

    // Wait a bit before completing
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      widget.onComplete();
    }
  }

  Future<bool> _requestLocationPermission() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        _showEnableLocationDialog();
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showOpenSettingsDialog('Lokasi');
      }
      return false;
    }

    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  }

  Future<bool> _requestCameraPermission() async {
    PermissionStatus status = await Permission.camera.status;
    
    if (status.isDenied) {
      status = await Permission.camera.request();
    }
    
    if (status.isPermanentlyDenied) {
      if (mounted) {
        _showOpenSettingsDialog('Kamera');
      }
      return false;
    }

    return status.isGranted;
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
