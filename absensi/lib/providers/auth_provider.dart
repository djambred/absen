import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/constants.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isAuthenticated = false;
  bool _isLoading = false;

  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  final _apiService = ApiService();
  final _storage = SecureStorageService();

  AuthProvider() {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await _storage.read(key: AppConstants.keyAccessToken);
    if (token != null) {
      try {
        final profile = await _apiService.getProfile();
        _user = User.fromJson(profile);
        _isAuthenticated = true;
        notifyListeners();
      } catch (e) {
        await logout();
      }
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.login(email, password);
      
      await _storage.write(
        key: AppConstants.keyAccessToken,
        value: response['access_token'],
      );
      await _storage.write(
        key: AppConstants.keyRefreshToken,
        value: response['refresh_token'],
      );
      
      final userData = response['user'] as Map<String, dynamic>;
      await _storage.write(
        key: AppConstants.keyUserId,
        value: userData['id'],
      );

      _user = User.fromJson(userData);
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (e) {
      debugPrint('Logout error: $e');
    }

    await _storage.deleteAll();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
