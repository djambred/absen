import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/leave_provider.dart';
import '../../services/api_service.dart';
import '../../models/leave_model.dart';
import '../history/attendance_history_screen.dart';
import '../leave/leave_submission_screen.dart';
import '../leave/leave_approval_screen.dart';
import '../leave/active_leaves_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasPendingApprovals = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().loadTodayAttendance();
      context.read<LeaveProvider>().refresh();
      _checkPendingApprovals();
    });
  }

  Future<void> _checkPendingApprovals() async {
    try {
      final apiService = ApiService();
      final response = await apiService.getPendingApprovals();
      final pendingApprovals = response['pending_approvals'] as List;
      
      if (mounted) {
        setState(() {
          _hasPendingApprovals = pendingApprovals.isNotEmpty;
        });
      }
    } catch (e) {
      // Silently fail - user just won't see the button
      debugPrint('Error checking pending approvals: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();
    final leaveProvider = context.watch<LeaveProvider>();
    final user = authProvider.user;

    // Check if user can apply for annual leave (worked for 1+ year)
    // NOTE: This validation is disabled - users can apply CUTI immediately
    final canApplyForCuti = true; // user != null && DateTime.now().difference(user.createdAt).inDays >= 365;
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
            
            // Approval Button (for supervisors)
            _buildApprovalButton(context, user),
            
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
              label: const Text('Riwayat'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            
            // View Active Leaves Button
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ActiveLeavesScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.people),
              label: const Text('Lihat Karyawan Sedang Cuti'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                foregroundColor: Colors.deepOrange,
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
                    message: leaveProvider.hasPendingLeave 
                        ? 'Tidak bisa mengajukan cuti sambil menunggu persetujuan'
                        : 'Ajukan cuti tahunan',
                    child: ElevatedButton(
                      onPressed: leaveProvider.hasPendingLeave ? null : () {
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
                        backgroundColor: Colors.pink[400],
                        foregroundColor: Colors.white,
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
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: leaveProvider.hasPendingLeave ? null : () {
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
                    onPressed: leaveProvider.hasPendingLeave ? null : () {
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
            const SizedBox(height: 12),
            // Info UI for leave types
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.pink[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.pink[200]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.beach_access, color: Colors.pink),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Cuti Tahunan — ajukan setelah 12 bulan masa kerja, gunakan untuk cuti berbayar.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.exit_to_app, color: Colors.blue),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Izin / Dinas Luar — pilih sesuai keperluan pribadi atau tugas dinas.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.yellow[600]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_hospital, color: Colors.orange),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Sakit — unggah surat dokter bila ada untuk mempercepat approval.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
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
    if (!leaveProvider.hasActiveLeave || leaveProvider.leaves.isEmpty) {
      return const SizedBox.shrink();
    }

    // Find an active leave, but handle the case where none exist
    Leave? activeLeave;
    try {
      activeLeave = leaveProvider.leaves.firstWhere(
        (leave) => leave.isActive,
      );
    } catch (e) {
      return const SizedBox.shrink();
    }

    if (activeLeave == null) {
      return const SizedBox.shrink();
    }

    IconData categoryIcon;
    MaterialColor categoryColor;
    String categoryLabel;

    if (activeLeave.leaveType == 'cuti') {
      categoryIcon = Icons.beach_access;
      categoryColor = Colors.pink;
      categoryLabel = 'Cuti';
    } else if (activeLeave.leaveType == 'sakit') {
      categoryIcon = Icons.local_hospital;
      categoryColor = Colors.red;
      if (activeLeave.category == 'sakit_dengan_surat') {
        categoryLabel = 'Sakit (dengan surat)';
      } else {
        categoryLabel = 'Sakit (tanpa surat)';
      }
    } else if (activeLeave.leaveType == 'izin') {
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

  Widget _buildApprovalButton(BuildContext context, user) {
    // Show approval button if user has pending approvals to review
    // Previously we checked for "kepala" in role, but now we check if there are pending approvals
    if (!_hasPendingApprovals) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LeaveApprovalScreen(),
                ),
              ).then((_) {
                // Refresh when back from approval screen
                _checkPendingApprovals();
              });
            },
            icon: const Icon(Icons.approval, size: 24),
            label: const Text('Persetujuan Cuti/Izin'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

