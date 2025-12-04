import 'package:flutter/foundation.dart';
import '../models/attendance_model.dart';
import '../services/api_service.dart';

class AttendanceProvider with ChangeNotifier {
  Attendance? _todayAttendance;
  List<Attendance> _history = [];
  bool _isLoading = false;

  Attendance? get todayAttendance => _todayAttendance;
  List<Attendance> get history => _history;
  bool get isLoading => _isLoading;
  bool get hasCheckedIn => _todayAttendance != null;
  bool get hasCheckedOut => _todayAttendance?.checkOutTime != null;
  
  // Check if current time allows checkout based on check-in time
  bool get canCheckOutNow {
    if (_todayAttendance == null || hasCheckedOut) return false;
    final now = DateTime.now();
    return now.isAfter(_todayAttendance!.requiredCheckoutTime);
  }
  
  DateTime? get requiredCheckoutTime => _todayAttendance?.requiredCheckoutTime;

  final _apiService = ApiService();

  Future<void> loadTodayAttendance() async {
    try {
      final response = await _apiService.getTodayAttendance();
      if (response != null) {
        _todayAttendance = Attendance.fromJson(response);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Load today attendance error: $e');
    }
  }

  Future<bool> checkIn({
    required double latitude,
    required double longitude,
    required String location,
    required String photoPath,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.checkIn(
        latitude: latitude,
        longitude: longitude,
        location: location,
        photoPath: photoPath,
      );

      _todayAttendance = Attendance.fromJson(response);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> checkOut({
    required double latitude,
    required double longitude,
    required String location,
    required String photoPath,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.checkOut(
        latitude: latitude,
        longitude: longitude,
        location: location,
        photoPath: photoPath,
      );

      _todayAttendance = Attendance.fromJson(response);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.getAttendanceHistory();
      _history = response.map((e) => Attendance.fromJson(e)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Load history error: $e');
    }
  }
}
