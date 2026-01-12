import 'package:flutter/foundation.dart';
import '../models/leave_model.dart';
import '../services/api_service.dart';

class LeaveProvider with ChangeNotifier {
  LeaveQuota? _currentQuota;
  List<Leave> _leaves = [];
  Leave? _activeLeave;
  bool _isLoading = false;

  LeaveQuota? get currentQuota => _currentQuota;
  List<Leave> get leaves => _leaves;
  Leave? get activeLeave => _activeLeave;
  bool get isLoading => _isLoading;
  
  int get remainingQuota => _currentQuota?.remainingQuota ?? 12;
  bool get hasActiveLeave => _activeLeave != null;

  final _apiService = ApiService();

  Future<void> loadQuota() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final response = await _apiService.getLeaveQuota();
      if (response != null) {
        _currentQuota = LeaveQuota.fromJson(response);
      }
    } catch (e) {
      debugPrint('Load quota error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLeaves() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final response = await _apiService.getLeaves();
      _leaves = response.map((e) => Leave.fromJson(e)).toList();

      if (_leaves.isEmpty) {
        _activeLeave = null;
        return;
      }
      
      // Prefer active dinas luar/keperluan pribadi if present; otherwise any active leave
      _activeLeave = _leaves.firstWhere(
        (leave) => leave.isActive && (leave.isDinasLuar || leave.isKeperluanPribadi),
        orElse: () => _leaves.firstWhere(
          (leave) => leave.isActive,
          orElse: () => _leaves.first,
        ),
      );
    } catch (e) {
      debugPrint('Load leaves error: $e');
      _activeLeave = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitLeave({
    required String leaveType,
    required String category,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    String? attachmentPath,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.submitLeave(
        leaveType: leaveType,
        category: category,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        attachmentPath: attachmentPath,
      );

      // Refresh data
      await loadQuota();
      await loadLeaves();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refresh() async {
    await Future.wait([
      loadQuota(),
      loadLeaves(),
    ]);
  }
  
  /// Clear all data (called on logout)
  void clear() {
    _currentQuota = null;
    _leaves = [];
    _activeLeave = null;
    _isLoading = false;
    notifyListeners();
  }
}
