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
  bool get hasActiveLeave => _activeLeave?.isActive ?? false;
  
  // Check if user has any pending leave requests
  bool get hasPendingLeave => _leaves.any((leave) => leave.status == 'pending');

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
      
      // Compute active leave only from approved/current leaves
      final activeLeaves = _leaves.where((leave) => leave.isActive).toList();
      if (activeLeaves.isEmpty) {
        _activeLeave = null;
      } else {
        // Prefer active izin types if present; otherwise any active leave
        _activeLeave = activeLeaves.firstWhere(
          (leave) => leave.isDinasLuar || leave.isKeperluanPribadi,
          orElse: () => activeLeaves.first,
        );
      }
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
    String? supervisorId,
    String? attachmentPath,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.submitLeave(
        leaveType: leaveType,
        category: category,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        supervisorId: supervisorId,
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
