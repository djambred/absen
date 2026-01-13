import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';
import 'secure_storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  
  late Dio _dio;
  final _storage = SecureStorageService();
  
  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: '${AppConstants.baseUrl}/api',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.keyAccessToken);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        debugPrint('Request: ${options.method} ${options.uri}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint('Response: ${response.statusCode} from ${response.requestOptions.uri}');
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        debugPrint('Error: ${e.response?.statusCode} - ${e.message}');
        if (e.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            return handler.resolve(await _dio.fetch(e.requestOptions));
          }
        }
        return handler.next(e);
      },
    ));
  }
  
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: AppConstants.keyRefreshToken);
      if (refreshToken == null) return false;
      
      final response = await _dio.post(
        '/auth/refresh',
        options: Options(
          headers: {'Authorization': 'Bearer $refreshToken'},
        ),
      );
      
      if (response.statusCode == 200) {
        await _storage.write(
          key: AppConstants.keyAccessToken,
          value: response.data['access_token'],
        );
        return true;
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
    }
    return false;
  }
  
  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      debugPrint('Login attempt: $email');
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      debugPrint('Login response: ${response.statusCode}');
      final data = Map<String, dynamic>.from(response.data);
      if (data['user'] != null) {
        final user = data['user'];
        data.addAll(user);
      }
      return data;
    } on DioException catch (e) {
      debugPrint('Login DioException: ${e.response?.statusCode} - ${e.response?.data}');
      if (e.response?.statusCode == 401) {
        throw Exception('Email atau password salah');
      } else if (e.response?.data != null && e.response?.data is Map) {
        final detail = e.response?.data['detail'];
        throw Exception(detail ?? 'Login gagal');
      }
      throw Exception('Tidak dapat terhubung ke server: ${e.message}');
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get('/users/profile');
    return response.data;
  }
  
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }
  
  // Attendance
  Future<Map<String, dynamic>> checkIn({
    required double latitude,
    required double longitude,
    required String location,
    required String photoPath,
  }) async {
    try {
      final now = DateTime.now();
      final formData = FormData.fromMap({
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'location': location,
        'timestamp': now.toIso8601String(),
        'photo': await MultipartFile.fromFile(
          photoPath,
          filename: 'photo.jpg',
        ),
      });
      
      debugPrint('Check-in request: lat=$latitude, lng=$longitude, loc=$location, time=$now');
      final response = await _dio.post('/attendance/check-in', data: formData);
      debugPrint('Check-in response: ${response.statusCode}');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      debugPrint('Check-in DioException: ${e.response?.statusCode} - ${e.response?.data}');
      if (e.response?.data != null && e.response?.data is Map) {
        final detail = e.response?.data['detail'];
        throw Exception(detail ?? 'Gagal check-in');
      }
      throw Exception('Koneksi ke server gagal: ${e.message}');
    } catch (e) {
      debugPrint('Check-in error: $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> checkOut({
    required double latitude,
    required double longitude,
    required String location,
    required String photoPath,
  }) async {
    try {
      final now = DateTime.now();
      final formData = FormData.fromMap({
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'location': location,
        'timestamp': now.toIso8601String(),
        'photo': await MultipartFile.fromFile(
          photoPath,
          filename: 'photo.jpg',
        ),
      });
      
      debugPrint('Check-out request: lat=$latitude, lng=$longitude, loc=$location, time=$now');
      final response = await _dio.post('/attendance/check-out', data: formData);
      debugPrint('Check-out response: ${response.statusCode}');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      debugPrint('Check-out DioException: ${e.response?.statusCode} - ${e.response?.data}');
      if (e.response?.data != null && e.response?.data is Map) {
        final detail = e.response?.data['detail'];
        throw Exception(detail ?? 'Gagal check-out');
      }
      throw Exception('Koneksi ke server gagal: ${e.message}');
    } catch (e) {
      debugPrint('Check-out error: $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>?> getTodayAttendance() async {
    try {
      final response = await _dio.get('/attendance/today');
      return response.data;
    } on DioException catch (e) {
      // 404 means no attendance today - not an error
      if (e.response?.statusCode == 404) {
        return null;
      }
      debugPrint('Get today attendance error: ${e.response?.statusCode} - ${e.response?.data}');
      rethrow;
    }
  }
  
  Future<List<dynamic>> getAttendanceHistory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate.toIso8601String();
    if (endDate != null) params['end_date'] = endDate.toIso8601String();
    
    final response = await _dio.get('/attendance/history', queryParameters: params);
    return response.data['data'];
  }
  
  // Leave/Cuti
  Future<Map<String, dynamic>?> getLeaveQuota() async {
    try {
      final response = await _dio.get('/leave/quota');
      return response.data;
    } catch (e) {
      debugPrint('Get leave quota error: $e');
      return null;
    }
  }
  
  Future<List<dynamic>> getLeaves() async {
    try {
      final response = await _dio.get('/leave/list');
      return response.data['leaves'] ?? [];
    } catch (e) {
      debugPrint('Get leaves error: $e');
      return [];
    }
  }
  
  Future<List<dynamic>> getSupervisors() async {
    try {
      final response = await _dio.get('/leave/supervisors');
      return response.data['supervisors'] ?? [];
    } catch (e) {
      debugPrint('Get supervisors error: $e');
      return [];
    }
  }
  
  Future<Map<String, dynamic>> submitLeave({
    required String leaveType,
    required String category,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    String? supervisorId,
    String? attachmentPath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'type': leaveType,
        'category': category,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'reason': reason,
      });
      
      if (supervisorId != null) {
        formData.fields.add(MapEntry('supervisor_id', supervisorId));
      }
      
      if (attachmentPath != null) {
        formData.files.add(
          MapEntry(
            'attachment',
            await MultipartFile.fromFile(
              attachmentPath,
              filename: 'attachment.jpg',
            ),
          ),
        );
      }
      
      debugPrint('Submit leave request: type=$leaveType, category=$category, supervisor=$supervisorId');
      final response = await _dio.post('/leave/submit', data: formData);
      debugPrint('Submit leave response: ${response.statusCode}');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      debugPrint('Submit leave DioException: ${e.response?.statusCode} - ${e.response?.data}');
      if (e.response?.data != null && e.response?.data is Map) {
        final detail = e.response?.data['detail'];
        throw Exception(detail ?? 'Gagal mengajukan cuti/izin');
      }
      throw Exception('Koneksi ke server gagal: ${e.message}');
    } catch (e) {
      debugPrint('Submit leave error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getPendingApprovals() async {
    try {
      final response = await _dio.get('/leave/pending-approvals');
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      debugPrint('Get pending approvals error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> approveLeave(String leaveId, {required int level, String? notes}) async {
    try {
      final response = await _dio.post(
        '/leave/$leaveId/approve',
        data: {
          'level': level,
          if (notes != null) 'notes': notes,
        },
      );
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      debugPrint('Approve leave error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> rejectLeave(String leaveId, {required String notes}) async {
    try {
      final response = await _dio.post(
        '/leave/$leaveId/reject',
        data: {'notes': notes},
      );
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      debugPrint('Reject leave error: $e');
      rethrow;
    }
  }
}
