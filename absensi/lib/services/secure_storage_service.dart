import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  
  SharedPreferences? _prefs;
  bool _initialized = false;
  
  SecureStorageService._internal();
  
  Future<void> init() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }
  
  Future<void> write({required String key, required String value}) async {
    if (_prefs == null) await init();
    await _prefs!.setString(key, value);
  }
  
  Future<String?> read({required String key}) async {
    if (_prefs == null) await init();
    return _prefs!.getString(key);
  }
  
  Future<void> delete({required String key}) async {
    if (_prefs == null) await init();
    await _prefs!.remove(key);
  }
  
  Future<void> deleteAll() async {
    if (_prefs == null) await init();
    await _prefs!.clear();
  }
}
