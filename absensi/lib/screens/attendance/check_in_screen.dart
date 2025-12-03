import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/camera_service.dart';
import 'dart:io';

class CheckInScreen extends StatefulWidget {
  final bool isCheckIn;

  const CheckInScreen({super.key, required this.isCheckIn});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _cameraService = CameraService();
  final _locationProvider = LocationProvider();
  bool _isProcessing = false;
  String? _photoPath;
  CameraController? _controller;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _checkLocation();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _controller = await _cameraService.initializeCamera();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showError('Gagal menginisialisasi kamera: $e');
    }
  }

  Future<void> _checkLocation() async {
    await _locationProvider.checkLocation();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      _showError('Kamera belum siap');
      return;
    }

    try {
      setState(() => _isProcessing = true);

      final imagePath = await _cameraService.takePicture(_controller!);
      
      setState(() {
        _photoPath = imagePath;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Gagal mengambil foto: $e');
    }
  }

  Future<void> _submit() async {
    if (_photoPath == null) {
      _showError('Silakan ambil foto terlebih dahulu');
      return;
    }
    
    if (!_locationProvider.isValidLocation) {
      _showError('Lokasi Anda tidak valid untuk absensi');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final attendanceProvider = context.read<AttendanceProvider>();
      final locationCheck = _locationProvider.locationCheck!;

      bool success;
      if (widget.isCheckIn) {
        success = await attendanceProvider.checkIn(
          latitude: locationCheck.latitude,
          longitude: locationCheck.longitude,
          location: locationCheck.locationName,
          photoPath: _photoPath!,
        );
      } else {
        success = await attendanceProvider.checkOut(
          latitude: locationCheck.latitude,
          longitude: locationCheck.longitude,
          location: locationCheck.locationName,
          photoPath: _photoPath!,
        );
      }

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isCheckIn ? 'Check-in berhasil!' : 'Check-out berhasil!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      _showError('Gagal ${widget.isCheckIn ? "check-in" : "check-out"}: $errorMessage');
      debugPrint('Submit error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.isCheckIn ? 'Check In' : 'Check Out',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _controller == null || !_controller!.value.isInitialized
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Memuat kamera...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Camera Preview - professional card style
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 400,
                        width: double.infinity,
                        child: _photoPath == null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  CameraPreview(_controller!),
                                  Positioned(
                                    top: 16,
                                    left: 16,
                                    right: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.camera_alt,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Posisikan wajah Anda di tengah',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Image.file(
                                File(_photoPath!),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                  // Location Status Section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status Lokasi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Location Status
                        if (_locationProvider.isLoading)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Mengecek Lokasi GPS',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Mohon tunggu beberapa saat...',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_locationProvider.isValidLocation)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.green.shade50, Colors.green.shade100],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Lokasi Valid',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _locationProvider.locationCheck!.locationName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_locationProvider.locationCheck!.distance.toStringAsFixed(0)}m dari titik absensi',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.red.shade50, Colors.red.shade100],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.location_off,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Lokasi Tidak Valid',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.red,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _locationProvider.locationCheck?.message ?? 
                                                'Anda berada di luar area absensi',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _checkLocation,
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Cek Ulang Lokasi'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_locationProvider.locationCheck != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.amber.shade300),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.info_outline, color: Colors.amber[800]),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Lokasi Terdekat',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.amber,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.place,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _locationProvider.locationCheck!.locationName,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${_locationProvider.locationCheck!.distance.toStringAsFixed(0)} meter dari posisi Anda',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.directions_walk, size: 16, color: Colors.grey),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Silakan menuju lokasi tersebut untuk melakukan absensi',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        const SizedBox(height: 24),
                        // Action Buttons
                        if (_photoPath == null)
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _isProcessing ? null : _takePicture,
                              icon: const Icon(Icons.camera_alt, size: 24),
                              label: const Text(
                                'Ambil Foto Selfie',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 56,
                                  child: OutlinedButton.icon(
                                    onPressed: _isProcessing
                                        ? null
                                        : () => setState(() => _photoPath = null),
                                    icon: const Icon(Icons.refresh, size: 22),
                                    label: const Text(
                                      'Ulangi',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.grey[700],
                                      side: BorderSide(color: Colors.grey.shade400),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  height: 56,
                                  child: ElevatedButton.icon(
                                    onPressed: _isProcessing ||
                                            !_locationProvider.isValidLocation
                                        ? null
                                        : _submit,
                                    icon: _isProcessing
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.check_circle, size: 22),
                                    label: Text(
                                      widget.isCheckIn ? 'Check In' : 'Check Out',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: widget.isCheckIn 
                                          ? Colors.green 
                                          : Colors.orange,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
