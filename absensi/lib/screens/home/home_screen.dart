import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/leave_provider.dart';
import '../../models/leave_model.dart';
import '../history/attendance_history_screen.dart';
import '../leave/leave_submission_screen.dart';

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

    // Check if user can apply for annual leave (worked for 1+ year)
    final canApplyForCuti = user != null && 
        DateTime.now().difference(user.createdAt).inDays >= 365;
    final monthsWorked = user != null 
        ? (DateTime.now().difference(user.createdAt).inDays / 30).floor()
        : 0;

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
            const SizedBox(height: 16),
            
            // Leave Submission Buttons
            Text(
              'Pengajuan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: !canApplyForCuti 
                        ? 'Cuti tahunan dapat diajukan setelah bekerja minimal 1 tahun (saat ini: $monthsWorked bulan)'
                        : 'Ajukan cuti tahunan',
                    child: ElevatedButton(
                      onPressed: !canApplyForCuti ? null : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LeaveSubmissionScreen(
                              initialLeaveType: LeaveType.cuti,
                            ),
                          ),
                        ).then((_) {
                          leaveProvider.refresh();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: !canApplyForCuti ? Colors.grey[300] : Colors.pink[400],
                        foregroundColor: !canApplyForCuti ? Colors.grey[600] : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.beach_access, size: 28),
                          const SizedBox(height: 4),
                          const Text(
                            'Cuti',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          if (!canApplyForCuti)
                            Text(
                              '$monthsWorked/12 bulan',
                              style: const TextStyle(fontSize: 9),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LeaveSubmissionScreen(
                            initialLeaveType: LeaveType.izin,
                          ),
                        ),
                      ).then((_) {
                        leaveProvider.refresh();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue[400],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.exit_to_app, size: 28),
                        SizedBox(height: 4),
                        Text(
                          'Izin',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LeaveSubmissionScreen(
                            initialLeaveType: LeaveType.sakit,
                          ),
                        ),
                      ).then((_) {
                        leaveProvider.refresh();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.yellow[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.local_hospital, size: 28),
                        SizedBox(height: 4),
                        Text(
                          'Sakit',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
                  ? Colors.green[100] 
                  : Colors.orange[100],
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
              color: attendance.canCheckOut ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: attendance.canCheckOut ? Colors.green[300]! : Colors.orange[300]!,
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
                          color: attendance.canCheckOut ? Colors.green[900]! : Colors.orange[900]!,
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
    final quota = leaveProvider.currentQuota;
    if (quota == null) {
      return const SizedBox.shrink();
    }

    final remaining = quota.remainingQuota;
    final used = quota.usedQuota;
    final total = quota.totalQuota;
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
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.calendar_month, color: Colors.blue[700]!, size: 24),
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
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                        color: remaining > 6 ? Colors.green[700]! : 
                               remaining > 3 ? Colors.orange[700]! : Colors.red[700]!,
                      ),
                    ),
                    Text(
                      'dari $total hari',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                backgroundColor: Colors.grey[200],
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
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]!),
                ),
                Text(
                  '${(percentage * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700]!,
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
    MaterialColor categoryColor;
    String categoryLabel;

    if (activeLeave.leaveType == 'izin') {
      if (activeLeave.category == 'dinas_luar') {
        categoryIcon = Icons.business_center;
        categoryColor = Colors.blue;
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
      color: categoryColor[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: categoryColor[200]!, width: 1),
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
                    color: categoryColor[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(categoryIcon, color: categoryColor[700]!, size: 24),
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
                          color: categoryColor[900]!,
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
                    color: categoryColor[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'AKTIF',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: categoryColor[900]!,
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
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
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
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            activeLeave.reason,
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]!),
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
