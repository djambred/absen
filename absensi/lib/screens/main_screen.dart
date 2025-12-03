import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
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
      final hasCheckedIn = attendanceProvider.hasCheckedIn;
      
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
    final hasCheckedIn = attendanceProvider.hasCheckedIn;
    final hasCheckedOut = attendanceProvider.hasCheckedOut;

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
              hasCheckedOut 
                  ? Icons.check_circle
                  : hasCheckedIn 
                      ? Icons.logout 
                      : Icons.login,
            ),
            label: hasCheckedOut 
                ? 'Selesai' 
                : hasCheckedIn 
                    ? 'Check Out' 
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
