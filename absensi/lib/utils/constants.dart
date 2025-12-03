class AppConstants {
  //static const String baseUrl = 'http://localhost:8000'; // for Linux/Desktop
  //static const String baseUrl = 'http://10.0.2.2:8000'; // for Android emulator
  static const String baseUrl = 'https://apiabsen.ueu-fasilkom.my.id'; 
  static const int pinLength = 6;
  
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'user_id';
  
  static const List<Map<String, dynamic>> validLocations = [
    {'name': 'iNews Tower', 'lat': -6.184961, 'lng': 106.8317751, 'radius': 100.0},
    {'name': 'MNC Tower', 'lat': -6.184087, 'lng': 106.8315492, 'radius': 100.0},
    {'name': 'MNC University', 'lat': -6.1641544, 'lng': 106.762682, 'radius': 100.0},
  ];
}
