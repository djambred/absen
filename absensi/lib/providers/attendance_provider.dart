import 'package:flutter/foundation.dart';
import '../models/attendance_model.dart';
import '../services/api_service.dart';
import '../services/holiday_service.dart';
import '../services/notification_service.dart';

class AttendanceProvider with ChangeNotifier {
  Attendance? _todayAttendance;
  List<Attendance> _history = [];
  bool _isLoading = false;
  final HolidayService _holidayService = HolidayService();
  final NotificationService _notificationService = NotificationService();

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
      
      // Show notification
      await _notificationService.showCheckOutNotification();
      
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
      
      // Load holidays for years in history
      final years = _history.map((a) => a.checkInTime.year).toSet();
      for (var year in years) {
        await _holidayService.getHolidays(year);
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Load history error: $e');
    }
  }
  
  /// Check if a date is a holiday
  Future<bool> isHoliday(DateTime date) async {
    return await _holidayService.isHoliday(date);
  }
  
  /// Get holiday name for a date
  Future<String?> getHolidayName(DateTime date) async {
    return await _holidayService.getHolidayName(date);
  }
  
  /// Check if date is weekend
  bool isWeekend(DateTime date) {
    return _holidayService.isWeekend(date);
  }
  
  /// Check if date is non-working day (weekend or holiday)
  Future<bool> isNonWorkingDay(DateTime date) async {
    return await _holidayService.isNonWorkingDay(date);
  }
  
  /// Clear all data (called on logout)
  void clear() {
    _todayAttendance = null;
    _history = [];
    _isLoading = false;
    notifyListeners();
  }
}
