import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  NotificationService._internal();

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      if (initialized == true) {
        _initialized = true;
        debugPrint('Notifications initialized successfully');
        
        // Request permissions for iOS
        await _requestPermissions();
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  Future<void> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle notification tap - navigate to specific screen based on payload
  }

  Future<void> showCheckInNotification() async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'attendance_channel',
      'Attendance Notifications',
      channelDescription: 'Notifications for attendance check-in and check-out',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        1,
        'Check-In Berhasil ✓',
        'Absensi masuk Anda telah tercatat',
        details,
        payload: 'check_in',
      );
    } catch (e) {
      debugPrint('Error showing check-in notification: $e');
    }
  }

  Future<void> showCheckOutNotification() async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'attendance_channel',
      'Attendance Notifications',
      channelDescription: 'Notifications for attendance check-in and check-out',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        2,
        'Check-Out Berhasil ✓',
        'Absensi pulang Anda telah tercatat',
        details,
        payload: 'check_out',
      );
    } catch (e) {
      debugPrint('Error showing check-out notification: $e');
    }
  }

  Future<void> showLeaveApprovalNotification({
    required String leaveType,
    required String status,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'leave_channel',
      'Leave Notifications',
      channelDescription: 'Notifications for leave approvals',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = status == 'approved' 
        ? 'Pengajuan Disetujui ✓'
        : status == 'rejected'
            ? 'Pengajuan Ditolak ✗'
            : 'Pengajuan Pending';
    
    final body = status == 'approved'
        ? 'Pengajuan $leaveType Anda telah disetujui'
        : status == 'rejected'
            ? 'Pengajuan $leaveType Anda ditolak'
            : 'Pengajuan $leaveType Anda menunggu persetujuan';

    try {
      await _notifications.show(
        3,
        title,
        body,
        details,
        payload: 'leave_$status',
      );
    } catch (e) {
      debugPrint('Error showing leave notification: $e');
    }
  }

  Future<void> showPendingApprovalNotification({
    required int count,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'approval_channel',
      'Approval Notifications',
      channelDescription: 'Notifications for pending approvals',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        4,
        'Menunggu Persetujuan',
        'Anda memiliki $count pengajuan cuti/izin yang menunggu persetujuan',
        details,
        payload: 'pending_approvals',
      );
    } catch (e) {
      debugPrint('Error showing pending approval notification: $e');
    }
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
