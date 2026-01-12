import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Holiday {
  final DateTime date;
  final String name;
  final bool isNational;

  Holiday({
    required this.date,
    required this.name,
    required this.isNational,
  });

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      date: DateTime.parse(json['holiday_date']),
      name: json['holiday_name'],
      isNational: json['is_national_holiday'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'holiday_date': date.toIso8601String(),
      'holiday_name': name,
      'is_national_holiday': isNational,
    };
  }
}

class HolidayService {
  static const String _cacheKey = 'holidays_cache';
  static const String _cacheTimeKey = 'holidays_cache_time';
  static const Duration _cacheDuration = Duration(days: 7); // Cache for 7 days
  
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api-harilibur.vercel.app',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  List<Holiday>? _holidays;
  
  /// Get holidays for a specific year
  Future<List<Holiday>> getHolidays(int year) async {
    // Check cache first
    final cached = await _loadFromCache(year);
    if (cached != null) {
      debugPrint('Loaded ${cached.length} holidays from cache for year $year');
      _holidays = cached;
      return cached;
    }

    // Fetch from API
    try {
      debugPrint('Fetching holidays from API for year $year...');
      final response = await _dio.get('/api?year=$year');
      
      if (response.statusCode == 200 && response.data != null) {
        final List<Holiday> holidays = [];
        
        // Parse response - bisa berupa array atau object dengan key
        if (response.data is List) {
          for (var item in response.data) {
            try {
              holidays.add(Holiday.fromJson(item));
            } catch (e) {
              debugPrint('Error parsing holiday: $e');
            }
          }
        } else if (response.data is Map) {
          // Jika response berupa object, ambil value yang berupa list
          for (var value in response.data.values) {
            if (value is List) {
              for (var item in value) {
                try {
                  holidays.add(Holiday.fromJson(item));
                } catch (e) {
                  debugPrint('Error parsing holiday: $e');
                }
              }
            }
          }
        }
        
        debugPrint('Fetched ${holidays.length} holidays for year $year');
        
        // Cache the results
        await _saveToCache(year, holidays);
        _holidays = holidays;
        return holidays;
      }
    } catch (e) {
      debugPrint('Error fetching holidays: $e');
    }
    
    return [];
  }

  /// Check if a date is a holiday
  Future<bool> isHoliday(DateTime date) async {
    // Ensure holidays are loaded for the year
    if (_holidays == null || _holidays!.isEmpty) {
      await getHolidays(date.year);
    }
    
    // Check if date matches any holiday
    return _holidays?.any((holiday) =>
      holiday.date.year == date.year &&
      holiday.date.month == date.month &&
      holiday.date.day == date.day
    ) ?? false;
  }

  /// Get holiday name for a date (returns null if not a holiday)
  Future<String?> getHolidayName(DateTime date) async {
    // Ensure holidays are loaded for the year
    if (_holidays == null || _holidays!.isEmpty) {
      await getHolidays(date.year);
    }
    
    try {
      final holiday = _holidays?.firstWhere((holiday) =>
        holiday.date.year == date.year &&
        holiday.date.month == date.month &&
        holiday.date.day == date.day
      );
      return holiday?.name;
    } catch (e) {
      return null;
    }
  }

  /// Check if date is weekend (Saturday or Sunday)
  bool isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  /// Check if date is holiday or weekend
  Future<bool> isNonWorkingDay(DateTime date) async {
    return isWeekend(date) || await isHoliday(date);
  }

  /// Save holidays to cache
  Future<void> _saveToCache(int year, List<Holiday> holidays) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = holidays.map((h) => h.toJson()).toList();
      await prefs.setString('${_cacheKey}_$year', jsonEncode(json));
      await prefs.setInt('${_cacheTimeKey}_$year', DateTime.now().millisecondsSinceEpoch);
      debugPrint('Cached ${holidays.length} holidays for year $year');
    } catch (e) {
      debugPrint('Error caching holidays: $e');
    }
  }

  /// Load holidays from cache
  Future<List<Holiday>?> _loadFromCache(int year) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if cache exists
      final jsonString = prefs.getString('${_cacheKey}_$year');
      if (jsonString == null) return null;
      
      // Check if cache is still valid
      final cacheTime = prefs.getInt('${_cacheTimeKey}_$year');
      if (cacheTime == null) return null;
      
      final cacheDate = DateTime.fromMillisecondsSinceEpoch(cacheTime);
      if (DateTime.now().difference(cacheDate) > _cacheDuration) {
        debugPrint('Cache expired for year $year');
        return null;
      }
      
      // Parse cached data
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => Holiday.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading cached holidays: $e');
      return null;
    }
  }

  /// Clear cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => 
        key.startsWith(_cacheKey) || key.startsWith(_cacheTimeKey)
      );
      for (var key in keys) {
        await prefs.remove(key);
      }
      _holidays = null;
      debugPrint('Holiday cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
}
