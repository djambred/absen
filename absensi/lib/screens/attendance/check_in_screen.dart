import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/camera_service.dart';
import '../../utils/error_handler.dart';
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
  bool _faceHintShown = false;

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
      if (mounted) {
        ErrorHandler.showErrorDialog(
          context,
          'Gagal menginisialisasi kamera. Pastikan aplikasi memiliki izin kamera.',
          onRetry: _initCamera,
        );
      }
    }
  }

  Future<void> _checkLocation() async {
    try {
      await _locationProvider.checkLocation();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorDialog(
          context,
          e,
          onRetry: _checkLocation,
        );
      }
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      ErrorHandler.showErrorSnackBar(context, 'Kamera belum siap');
      return;
    }

    try {
      setState(() => _isProcessing = true);

      final imagePath = await _cameraService.takePicture(_controller!);
      // Crop captured image to guide box
      final croppedPath = await _cropToGuide(imagePath);
      setState(() {
        _photoPath = croppedPath ?? imagePath;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ErrorHandler.showErrorDialog(
          context,
          e,
          onRetry: _takePicture,
        );
      }
    }
  }

  // Crop the captured image to the guide box proportions
  Future<String?> _cropToGuide(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) return null;

      // Define guide box as centered with 95% width and 90% height of the image (more zoom out)
      final guideW = (original.width * 0.95).round();
      final guideH = (original.height * 0.90).round();
      final left = ((original.width - guideW) / 2).round();
      final top = ((original.height - guideH) / 2).round();

      final cropped = img.copyCrop(
        original,
        x: left,
        y: top,
        width: guideW,
        height: guideH,
      );

      final outBytes = img.encodeJpg(cropped, quality: 90);
      final outFile = File(path);
      await outFile.writeAsBytes(outBytes, flush: true);
      return outFile.path;
    } catch (e) {
      debugPrint('Crop error: $e');
      return null;
    }
  }

  Future<void> _submit() async {
    if (_photoPath == null) {
      ErrorHandler.showErrorSnackBar(context, 'Silakan ambil foto terlebih dahulu');
      return;
    }
    
    if (!_locationProvider.isValidLocation) {
      ErrorHandler.showErrorDialog(
        context,
        'Lokasi Anda tidak valid untuk absensi. Pastikan Anda berada di area kantor.',
        onRetry: () async {
          await _checkLocation();
          if (_locationProvider.isValidLocation) {
            _submit();
          }
        },
      );
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
      if (mounted) {
        ErrorHandler.showErrorDialog(
          context,
          e,
          onRetry: _submit,
        );
      }
      debugPrint('Submit error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenHeight = media.size.height;
    // Dynamic camera height: 30% of screen, clamped between 220 and 320
    final cameraHeight = screenHeight * 0.3;
    final effectiveCameraHeight = cameraHeight.clamp(220.0, 320.0);

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
          : Column(
              children: [
                // Camera Preview - compact size
                Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: effectiveCameraHeight,
                      width: double.infinity,
                      child: _photoPath == null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                CameraPreview(_controller!),
                                // Guide box overlay
                                Positioned.fill(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final w = constraints.maxWidth;
                                      final h = constraints.maxHeight;
                                      // Responsive guide box: larger for zoom out effect
                                      final isCompact = h < 260;
                                      final boxW = w * (isCompact ? 0.88 : 0.95);
                                      final boxH = h * (isCompact ? 0.80 : 0.90);
                                      final left = (w - boxW) / 2;
                                      final top = (h - boxH) / 2;
                                      return Stack(
                                        children: [
                                          // Dim overlay with hole where the guide box is
                                          CustomPaint(
                                            size: Size(w, h),
                                            painter: FaceGuideOverlayPainter(
                                              holeRect: Rect.fromLTWH(left, top, boxW, boxH),
                                              holeRadius: 16,
                                              overlayColor: Colors.black.withValues(alpha: 0.45),
                                              borderColor: Colors.white,
                                              borderWidth: 2,
                                            ),
                                          ),
                                          // Face alignment icon inside the box
                                          Positioned(
                                            left: left + boxW / 2 - 12,
                                            top: top + 8,
                                            child: Icon(
                                              Icons.face_retouching_natural,
                                              color: Colors.white.withValues(alpha: 0.85),
                                              size: 24,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Posisikan wajah di tengah',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // One-time helper tooltip under the guide box
                                if (!_faceHintShown)
                                  Positioned(
                                    bottom: 10,
                                    left: 12,
                                    right: 12,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _faceHintShown = true);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.08),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.info_outline, size: 16, color: Colors.black87),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Pastikan kepala masuk di dalam kotak sebelum mengambil foto',
                                                style: TextStyle(fontSize: 12, color: Colors.black87),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Tutup',
                                              style: TextStyle(fontSize: 12, color: Colors.blue),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : Image.file(
                              File(_photoPath!),
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                ),
                  // Location Status Section - Compact (no scroll)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Location Status - Compact
                        if (_locationProvider.isLoading)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Memeriksa lokasi...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Location status with name and nearest location
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _locationProvider.isValidLocation ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _locationProvider.isValidLocation ? Colors.green.shade300 : Colors.red.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _locationProvider.isValidLocation ? Colors.green : Colors.red,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _locationProvider.isValidLocation ? Icons.check_circle : Icons.location_off,
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
                                          _locationProvider.isValidLocation ? 'Lokasi Valid' : 'Lokasi Tidak Valid',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: _locationProvider.isValidLocation ? Colors.green.shade900 : Colors.red.shade900,
                                          ),
                                        ),
                                        if (_locationProvider.locationCheck != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            _locationProvider.locationCheck!.locationName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '${_locationProvider.locationCheck!.distance.toStringAsFixed(0)}m dari ${_locationProvider.isValidLocation ? 'titik' : 'posisi Anda'}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (!_locationProvider.isValidLocation)
                                    IconButton(
                                      onPressed: _checkLocation,
                                      icon: const Icon(Icons.refresh, size: 20),
                                      style: IconButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        backgroundColor: Colors.white,
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Action Buttons - Fixed at bottom with SafeArea
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: _photoPath == null
                        ? SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _isProcessing ? null : _takePicture,
                              icon: const Icon(Icons.camera_alt, size: 20),
                              label: const Text(
                                'Ambil Foto Selfie',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 50,
                                  child: OutlinedButton.icon(
                                    onPressed: _isProcessing
                                        ? null
                                        : () => setState(() => _photoPath = null),
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text(
                                      'Ulangi',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.grey[700],
                                      side: BorderSide(color: Colors.grey.shade300),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: _isProcessing ||
                                            !_locationProvider.isValidLocation
                                        ? null
                                        : _submit,
                                    icon: _isProcessing
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.check_circle, size: 18),
                                    label: Text(
                                      widget.isCheckIn ? 'Check In' : 'Check Out',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: widget.isCheckIn 
                                          ? Colors.green 
                                          : Colors.orange,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                    ),
                  ),
                ],
              ),
    );
  }
}

// Painter that draws a dim overlay with a rounded-rect hole and border
class FaceGuideOverlayPainter extends CustomPainter {
  final Rect holeRect;
  final double holeRadius;
  final Color overlayColor;
  final Color borderColor;
  final double borderWidth;

  FaceGuideOverlayPainter({
    required this.holeRect,
    this.holeRadius = 16,
    this.overlayColor = const Color(0x73000000),
    this.borderColor = const Color(0xFFFFFFFF),
    this.borderWidth = 2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = overlayColor;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Full-screen path
    final fullPath = Path()..addRect(Offset.zero & size);
    // Hole path (rounded rect)
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(holeRect, Radius.circular(holeRadius)));

    // Create overlay with hole using even-odd fill type
    final overlayPath = Path.combine(PathOperation.difference, fullPath, holePath);
    canvas.drawPath(overlayPath, overlayPaint);

    // Draw border around the hole
    canvas.drawRRect(
      RRect.fromRectAndRadius(holeRect, Radius.circular(holeRadius)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant FaceGuideOverlayPainter oldDelegate) {
    return holeRect != oldDelegate.holeRect ||
        holeRadius != oldDelegate.holeRadius ||
        overlayColor != oldDelegate.overlayColor ||
        borderColor != oldDelegate.borderColor ||
        borderWidth != oldDelegate.borderWidth;
  }
}
