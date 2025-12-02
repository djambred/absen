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
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
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
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = Map<String, dynamic>.from(response.data);
    if (data['user'] != null) {
      final user = data['user'];
      data.addAll(user);
    }
    return data;
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
    final formData = FormData.fromMap({
      'latitude': latitude,
      'longitude': longitude,
      'location': location,
      'photo': await MultipartFile.fromFile(photoPath),
    });
    
    final response = await _dio.post('/attendance/check-in', data: formData);
    return response.data;
  }
  
  Future<Map<String, dynamic>> checkOut({
    required double latitude,
    required double longitude,
    required String location,
    required String photoPath,
  }) async {
    final formData = FormData.fromMap({
      'latitude': latitude,
      'longitude': longitude,
      'location': location,
      'photo': await MultipartFile.fromFile(photoPath),
    });
    
    final response = await _dio.post('/attendance/check-out', data: formData);
    return response.data;
  }
  
  Future<Map<String, dynamic>?> getTodayAttendance() async {
    final response = await _dio.get('/attendance/today');
    return response.data;
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
}
