import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/leave_provider.dart';
import 'home/home_screen.dart';
import 'attendance/check_in_screen.dart';
import 'profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    if (index == 1) {
      // Check in/out button - show appropriate screen based on attendance status
      final attendanceProvider = context.read<AttendanceProvider>();
      final leaveProvider = context.read<LeaveProvider>();
      final hasCheckedIn = attendanceProvider.hasCheckedIn;
      final hasCheckedOut = attendanceProvider.hasCheckedOut;
      final canCheckOutNow = attendanceProvider.canCheckOutNow;
      final requiredTime = attendanceProvider.requiredCheckoutTime;
      
      // Don't allow check-in if user has an active leave
      if (leaveProvider.hasActiveLeave && !hasCheckedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak bisa check-in karena Anda sedang cuti'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      
      // Don't allow navigation if already checked out
      if (hasCheckedOut) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Absensi hari ini sudah selesai'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      
      // Don't allow checkout if not yet time
      if (hasCheckedIn && !canCheckOutNow) {
        final timeStr = requiredTime != null 
            ? '${requiredTime.hour.toString().padLeft(2, '0')}:${requiredTime.minute.toString().padLeft(2, '0')} WIB'
            : 'waktu yang ditentukan';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check out tersedia mulai jam $timeStr'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckInScreen(isCheckIn: !hasCheckedIn),
        ),
      ).then((_) {
        // Refresh attendance after returning
        if (mounted) {
          context.read<AttendanceProvider>().loadTodayAttendance();
        }
      });
    } else {
      setState(() {
        _currentIndex = index == 2 ? 1 : 0; // Map index 2 (profile) to screen index 1
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final leaveProvider = context.watch<LeaveProvider>();
    final hasCheckedIn = attendanceProvider.hasCheckedIn;
    final hasCheckedOut = attendanceProvider.hasCheckedOut;
    final canCheckOutNow = attendanceProvider.canCheckOutNow;
    final hasActiveLeave = leaveProvider.hasActiveLeave;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex == 0 ? 0 : 2, // Map screen index back to nav index
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              hasActiveLeave && !hasCheckedIn
                  ? Icons.block
                  : hasCheckedOut 
                      ? Icons.check_circle
                      : hasCheckedIn 
                          ? (canCheckOutNow ? Icons.logout : Icons.access_time)
                          : Icons.login,
              color: hasActiveLeave && !hasCheckedIn ? Colors.red : null,
            ),
            label: hasActiveLeave && !hasCheckedIn
                ? 'Sedang Cuti'
                : hasCheckedOut 
                    ? 'Selesai' 
                    : hasCheckedIn 
                        ? (canCheckOutNow ? 'Check Out' : 'Menunggu')
                        : 'Check In',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
