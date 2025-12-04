import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../history/attendance_history_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().loadTodayAttendance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Absensi MNC'),
      ),
      body: RefreshIndicator(
        onRefresh: () => attendanceProvider.loadTodayAttendance(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, ${user?.name ?? ''}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${user?.nip ?? ''} • ${user?.role ?? ''}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    if (user?.department != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        user!.department!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Absensi Hari Ini',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    if (attendanceProvider.todayAttendance == null)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Belum ada absensi hari ini'),
                        ),
                      )
                    else
                      _buildAttendanceInfo(attendanceProvider.todayAttendance!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AttendanceHistoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('Riwayat Absensi'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceInfo(attendance) {
    final dateFormat = DateFormat('HH:mm');
    
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.login, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Check In'),
                  Text(
                    dateFormat.format(attendance.checkInTime),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    attendance.checkInLocation,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Chip(
              label: Text(attendance.statusDisplay),
              backgroundColor: attendance.status == 'on_time' 
                  ? Colors.green.shade100 
                  : Colors.orange.shade100,
            ),
          ],
        ),
        if (attendance.checkOutTime != null) ...[
          const Divider(height: 32),
          Row(
            children: [
              const Icon(Icons.logout, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Check Out'),
                    Text(
                      dateFormat.format(attendance.checkOutTime),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      attendance.checkOutLocation ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ] else ...[
          const Divider(height: 32),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: attendance.canCheckOut ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: attendance.canCheckOut ? Colors.green.shade300 : Colors.orange.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  attendance.canCheckOut ? Icons.check_circle : Icons.access_time,
                  color: attendance.canCheckOut ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attendance.canCheckOut 
                            ? 'Check out tersedia sekarang'
                            : 'Menunggu waktu check out',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: attendance.canCheckOut ? Colors.green.shade900 : Colors.orange.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Check out mulai ${dateFormat.format(attendance.requiredCheckoutTime)} WIB',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
