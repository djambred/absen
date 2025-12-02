import 'package:flutter/foundation.dart';
import '../services/location_service.dart';

class LocationProvider with ChangeNotifier {
  ValidLocationCheck? _locationCheck;
  bool _isLoading = false;
  String? _error;

  ValidLocationCheck? get locationCheck => _locationCheck;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isValidLocation => _locationCheck?.isValid ?? false;

  final _locationService = LocationService();

  Future<bool> checkLocation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _locationCheck = await _locationService.checkIfInValidLocation();
      _isLoading = false;
      notifyListeners();
      return _locationCheck?.isValid ?? false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clear() {
    _locationCheck = null;
    _error = null;
    notifyListeners();
  }
}
