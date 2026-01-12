import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/leave_provider.dart';
import '../history/attendance_history_screen.dart';
import '../leave/leave_submission_screen.dart';
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
      context.read<LeaveProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();
    final leaveProvider = context.watch<LeaveProvider>();
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Absensi MNC'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            attendanceProvider.loadTodayAttendance(),
            leaveProvider.refresh(),
          ]);
        },
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
            
            // Sisa Cuti Card
            _buildLeaveQuotaCard(leaveProvider),
            const SizedBox(height: 16),
            
            // Active Leave Card (if any)
            _buildActiveLeaveCard(leaveProvider),
            if (leaveProvider.hasActiveLeave)
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
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LeaveSubmissionScreen(),
                  ),
                ).then((_) {
                  // Refresh after submission
                  leaveProvider.refresh();
                });
              },
              icon: const Icon(Icons.event_note),
              label: const Text('Pengajuan Cuti/Izin'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
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

  Widget _buildLeaveQuotaCard(LeaveProvider leaveProvider) {
    final quota = leaveProvider.quota;
    if (quota == null) {
      return const SizedBox.shrink();
    }

    final remaining = quota.remaining;
    final used = quota.used;
    final total = quota.totalDays;
    final percentage = total > 0 ? remaining / total : 0.0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.calendar_month, color: Colors.blue.shade700, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sisa Cuti Tahunan',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Tahun ${quota.year}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$remaining',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: remaining > 6 ? Colors.green.shade700 : 
                               remaining > 3 ? Colors.orange.shade700 : Colors.red.shade700,
                      ),
                    ),
                    Text(
                      'dari $total hari',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  remaining > 6 ? Colors.green : 
                  remaining > 3 ? Colors.orange : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Terpakai: $used hari',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                Text(
                  '${(percentage * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveLeaveCard(LeaveProvider leaveProvider) {
    if (!leaveProvider.hasActiveLeave) {
      return const SizedBox.shrink();
    }

    final activeLeave = leaveProvider.leaves.firstWhere(
      (leave) => leave.isActive,
    );

    IconData categoryIcon;
    Color categoryColor;
    String categoryLabel;

    if (activeLeave.type == LeaveType.izin) {
      if (activeLeave.category == LeaveCategory.dinasLuar) {
        categoryIcon = Icons.business_center;
        categoryColor = Colors.purple;
        categoryLabel = 'Dinas Luar';
      } else {
        categoryIcon = Icons.exit_to_app;
        categoryColor = Colors.orange;
        categoryLabel = 'Keperluan Pribadi';
      }
    } else {
      return const SizedBox.shrink();
    }

    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
    
    return Card(
      elevation: 2,
      color: categoryColor.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: categoryColor.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: categoryColor.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(categoryIcon, color: categoryColor.shade700, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: categoryColor.shade900,
                        ),
                      ),
                      const Text(
                        'Sedang Berlangsung',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'AKTIF',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: categoryColor.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        '${dateFormat.format(activeLeave.startDate)} - ${dateFormat.format(activeLeave.endDate)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  if (activeLeave.reason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            activeLeave.reason,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
