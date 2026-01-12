import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

enum ErrorType {
  network,
  authentication,
  biometric,
  permission,
  location,
  camera,
  server,
  validation,
  timeout,
  unknown,
}

class AppError {
  final ErrorType type;
  final String title;
  final String message;
  final String? technicalDetails;
  final IconData icon;
  final Color color;

  AppError({
    required this.type,
    required this.title,
    required this.message,
    this.technicalDetails,
    required this.icon,
    required this.color,
  });
}

class ErrorHandler {
  static AppError mapError(dynamic error) {
    String errorString = error.toString();
    
    // DioException handling
    if (error is DioException) {
      return _mapDioError(error);
    }
    
    // String error messages
    if (error is String || error is Exception) {
      final message = errorString.toLowerCase();
      
      // Network errors
      if (message.contains('tidak dapat terhubung') ||
          message.contains('connection') ||
          message.contains('network') ||
          message.contains('koneksi')) {
        return AppError(
          type: ErrorType.network,
          title: 'Tidak Ada Koneksi',
          message: 'Pastikan perangkat Anda terhubung ke internet dan coba lagi.',
          technicalDetails: errorString,
          icon: Icons.wifi_off,
          color: Colors.orange,
        );
      }
      
      // Biometric errors
      if (message.contains('biometric') ||
          message.contains('fingerprint') ||
          message.contains('face') ||
          message.contains('authentication') ||
          message.contains('wajah tidak cocok') ||
          message.contains('face mismatch')) {
        return AppError(
          type: ErrorType.biometric,
          title: 'Verifikasi Biometrik Gagal',
          message: 'Wajah tidak cocok dengan data yang terdaftar. Pastikan wajah terlihat jelas dan coba lagi.',
          technicalDetails: errorString,
          icon: Icons.face_retouching_off,
          color: Colors.red,
        );
      }
      
      // Permission errors
      if (message.contains('permission') ||
          message.contains('izin') ||
          message.contains('akses')) {
        return AppError(
          type: ErrorType.permission,
          title: 'Izin Diperlukan',
          message: 'Aplikasi memerlukan izin untuk mengakses kamera, lokasi, atau fitur lainnya. Berikan izin di pengaturan aplikasi.',
          technicalDetails: errorString,
          icon: Icons.lock,
          color: Colors.amber,
        );
      }
      
      // Location errors
      if (message.contains('lokasi') ||
          message.contains('location') ||
          message.contains('gps')) {
        return AppError(
          type: ErrorType.location,
          title: 'Lokasi Tidak Valid',
          message: 'Anda berada di luar area yang diizinkan untuk absensi. Pastikan Anda berada di lokasi kantor.',
          technicalDetails: errorString,
          icon: Icons.location_off,
          color: Colors.deepOrange,
        );
      }
      
      // Camera errors
      if (message.contains('kamera') ||
          message.contains('camera') ||
          message.contains('foto')) {
        return AppError(
          type: ErrorType.camera,
          title: 'Masalah Kamera',
          message: 'Gagal mengakses atau menggunakan kamera. Pastikan kamera berfungsi dengan baik.',
          technicalDetails: errorString,
          icon: Icons.camera_alt,
          color: Colors.red,
        );
      }
      
      // Validation errors
      if (message.contains('sudah') ||
          message.contains('belum') ||
          message.contains('tidak boleh') ||
          message.contains('wajib') ||
          message.contains('required')) {
        return AppError(
          type: ErrorType.validation,
          title: 'Data Tidak Valid',
          message: errorString.replaceAll('Exception: ', ''),
          technicalDetails: errorString,
          icon: Icons.error_outline,
          color: Colors.orange,
        );
      }
      
      // Authentication errors
      if (message.contains('token') ||
          message.contains('unauthorized') ||
          message.contains('login') ||
          message.contains('password')) {
        return AppError(
          type: ErrorType.authentication,
          title: 'Sesi Berakhir',
          message: 'Sesi Anda telah berakhir. Silakan login kembali.',
          technicalDetails: errorString,
          icon: Icons.lock_clock,
          color: Colors.red,
        );
      }
      
      // Timeout errors
      if (message.contains('timeout') ||
          message.contains('timed out')) {
        return AppError(
          type: ErrorType.timeout,
          title: 'Waktu Habis',
          message: 'Permintaan memakan waktu terlalu lama. Periksa koneksi internet Anda dan coba lagi.',
          technicalDetails: errorString,
          icon: Icons.timer_off,
          color: Colors.orange,
        );
      }
    }
    
    // Default error
    return AppError(
      type: ErrorType.unknown,
      title: 'Terjadi Kesalahan',
      message: errorString.replaceAll('Exception: ', ''),
      technicalDetails: errorString,
      icon: Icons.error,
      color: Colors.red,
    );
  }
  
  static AppError _mapDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppError(
          type: ErrorType.timeout,
          title: 'Waktu Habis',
          message: 'Koneksi ke server memakan waktu terlalu lama. Periksa koneksi internet Anda.',
          technicalDetails: error.toString(),
          icon: Icons.timer_off,
          color: Colors.orange,
        );
        
      case DioExceptionType.connectionError:
        return AppError(
          type: ErrorType.network,
          title: 'Tidak Terhubung ke Server',
          message: 'Tidak dapat terhubung ke server. Pastikan koneksi internet Anda aktif dan stabil.',
          technicalDetails: error.toString(),
          icon: Icons.cloud_off,
          color: Colors.red,
        );
        
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;
        
        if (statusCode == 401) {
          return AppError(
            type: ErrorType.authentication,
            title: 'Sesi Berakhir',
            message: 'Sesi Anda telah berakhir. Silakan login kembali.',
            technicalDetails: error.toString(),
            icon: Icons.lock_clock,
            color: Colors.red,
          );
        } else if (statusCode == 403) {
          return AppError(
            type: ErrorType.authentication,
            title: 'Akses Ditolak',
            message: 'Anda tidak memiliki izin untuk melakukan aksi ini.',
            technicalDetails: error.toString(),
            icon: Icons.block,
            color: Colors.red,
          );
        } else if (statusCode == 404) {
          return AppError(
            type: ErrorType.server,
            title: 'Data Tidak Ditemukan',
            message: 'Data yang Anda cari tidak ditemukan di server.',
            technicalDetails: error.toString(),
            icon: Icons.search_off,
            color: Colors.orange,
          );
        } else if (statusCode == 422) {
          String message = 'Data yang Anda kirim tidak valid.';
          if (data is Map && data['detail'] != null) {
            message = data['detail'].toString();
          }
          return AppError(
            type: ErrorType.validation,
            title: 'Data Tidak Valid',
            message: message,
            technicalDetails: error.toString(),
            icon: Icons.error_outline,
            color: Colors.orange,
          );
        } else if (statusCode != null && statusCode >= 500) {
          return AppError(
            type: ErrorType.server,
            title: 'Server Bermasalah',
            message: 'Terjadi kesalahan di server. Tim kami sedang menanganinya. Silakan coba lagi nanti.',
            technicalDetails: error.toString(),
            icon: Icons.dns,
            color: Colors.red,
          );
        }
        
        // Try to get detail from response
        if (data is Map && data['detail'] != null) {
          final detail = data['detail'].toString();
          final lowerDetail = detail.toLowerCase();
          
          if (lowerDetail.contains('wajah') || lowerDetail.contains('face')) {
            return AppError(
              type: ErrorType.biometric,
              title: 'Verifikasi Wajah Gagal',
              message: detail,
              technicalDetails: error.toString(),
              icon: Icons.face_retouching_off,
              color: Colors.red,
            );
          }
        }
        
        break;
        
      case DioExceptionType.cancel:
        return AppError(
          type: ErrorType.unknown,
          title: 'Dibatalkan',
          message: 'Permintaan dibatalkan.',
          technicalDetails: error.toString(),
          icon: Icons.cancel,
          color: Colors.grey,
        );
        
      default:
        break;
    }
    
    return AppError(
      type: ErrorType.unknown,
      title: 'Terjadi Kesalahan',
      message: 'Terjadi kesalahan yang tidak diketahui. Silakan coba lagi.',
      technicalDetails: error.toString(),
      icon: Icons.error,
      color: Colors.red,
    );
  }
  
  static void showErrorDialog(BuildContext context, dynamic error, {VoidCallback? onRetry}) {
    final appError = mapError(error);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(appError.icon, color: appError.color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                appError.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: appError.color,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appError.message,
              style: const TextStyle(fontSize: 15),
            ),
            if (appError.technicalDetails != null) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Detail Teknis',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      appError.technicalDetails!,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          if (onRetry != null)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: TextButton.styleFrom(
                foregroundColor: appError.color,
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              onRetry != null ? 'Tutup' : 'OK',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
  
  static void showErrorSnackBar(BuildContext context, dynamic error) {
    final appError = mapError(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(appError.icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    appError.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    appError.message,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: appError.color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Detail',
          textColor: Colors.white,
          onPressed: () {
            showErrorDialog(context, error);
          },
        ),
      ),
    );
  }
}
