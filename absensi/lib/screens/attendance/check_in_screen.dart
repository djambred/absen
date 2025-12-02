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
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
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
      appBar: AppBar(
        title: Text(widget.isCheckIn ? 'Check In' : 'Check Out'),
      ),
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _photoPath == null
                      ? CameraPreview(_controller!)
                      : Image.file(File(_photoPath!)),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      if (_locationProvider.isLoading)
                        const CircularProgressIndicator()
                      else if (_locationProvider.isValidLocation)
                        Card(
                          color: Colors.green.shade50,
                          child: ListTile(
                            leading: const Icon(Icons.location_on, color: Colors.green),
                            title: Text(_locationProvider.locationCheck!.locationName),
                            subtitle: Text(
                              '${_locationProvider.locationCheck!.distance.toStringAsFixed(0)}m dari lokasi',
                            ),
                          ),
                        )
                      else
                        Card(
                          color: Colors.red.shade50,
                          child: ListTile(
                            leading: const Icon(Icons.location_off, color: Colors.red),
                            title: const Text('Lokasi tidak valid'),
                            subtitle: Text(
                              _locationProvider.locationCheck?.message ?? 'Di luar jangkauan',
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (_photoPath == null)
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _takePicture,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Ambil Foto'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isProcessing
                                    ? null
                                    : () => setState(() => _photoPath = null),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Ulangi'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isProcessing ||
                                        !_locationProvider.isValidLocation
                                    ? null
                                    : _submit,
                                icon: _isProcessing
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.check),
                                label: Text(
                                  widget.isCheckIn ? 'Check In' : 'Check Out',
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
