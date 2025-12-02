class Attendance {
  final String id;
  final String userId;
  final DateTime checkInTime;
  final double checkInLatitude;
  final double checkInLongitude;
  final String checkInLocation;
  final String? checkInPhotoUrl;
  final DateTime? checkOutTime;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final String? checkOutLocation;
  final String? checkOutPhotoUrl;
  final DateTime requiredCheckoutTime;
  final String status;
  final String? notes;

  Attendance({
    required this.id,
    required this.userId,
    required this.checkInTime,
    required this.checkInLatitude,
    required this.checkInLongitude,
    required this.checkInLocation,
    this.checkInPhotoUrl,
    this.checkOutTime,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.checkOutLocation,
    this.checkOutPhotoUrl,
    required this.requiredCheckoutTime,
    required this.status,
    this.notes,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'],
      userId: json['user_id'],
      checkInTime: DateTime.parse(json['check_in_time']),
      checkInLatitude: json['check_in_latitude'].toDouble(),
      checkInLongitude: json['check_in_longitude'].toDouble(),
      checkInLocation: json['check_in_location'],
      checkInPhotoUrl: json['check_in_photo_url'],
      checkOutTime: json['check_out_time'] != null 
          ? DateTime.parse(json['check_out_time']) 
          : null,
      checkOutLatitude: json['check_out_latitude']?.toDouble(),
      checkOutLongitude: json['check_out_longitude']?.toDouble(),
      checkOutLocation: json['check_out_location'],
      checkOutPhotoUrl: json['check_out_photo_url'],
      requiredCheckoutTime: DateTime.parse(json['required_checkout_time']),
      status: json['status'],
      notes: json['notes'],
    );
  }

  bool get canCheckOut {
    if (checkOutTime != null) return false;
    return DateTime.now().isAfter(requiredCheckoutTime);
  }

  String get statusDisplay {
    switch (status) {
      case 'on_time':
        return 'Tepat Waktu';
      case 'late':
        return 'Terlambat';
      case 'absent':
        return 'Tidak Hadir';
      default:
        return status;
    }
  }
}
