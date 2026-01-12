import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/leave_provider.dart';

// Marker model for calendar dots
class _DayMarker {
  bool hasCheckIn = false;
  bool hasCheckOut = false;
  bool isHoliday = false;
  String? holidayName;
  bool hasCuti = false;
  bool hasIzin = false;
  bool hasSakit = false;
}

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().loadHistory();
      context.read<LeaveProvider>().loadLeaves();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Absensi'),
      ),
      body: Consumer2<AttendanceProvider, LeaveProvider>(
        builder: (context, attendanceProvider, leaveProvider, _) {
          if (attendanceProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (attendanceProvider.history.isEmpty) {
            return const Center(
              child: Text('Belum ada riwayat absensi'),
            );
          }

          final filtered = _filterBySelectedDateOrMonth(attendanceProvider);

          return RefreshIndicator(
            onRefresh: () async {
              await attendanceProvider.loadHistory();
              await leaveProvider.loadLeaves();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildMonthHeader(),
                const SizedBox(height: 8),
                _buildLegend(),
                const SizedBox(height: 8),
                FutureBuilder<Map<int, _DayMarker>>(
                  future: _buildDayMarkers(attendanceProvider, leaveProvider),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final markers = snapshot.data ?? {};
                    return _buildCalendarGrid(markers);
                  },
                ),
                const SizedBox(height: 16),
                if (_selectedDate != null) ...[
                  FutureBuilder<String?>(
                    future: context.read<AttendanceProvider>().getHolidayName(_selectedDate!),
                    builder: (context, snapshot) {
                      final holidayName = snapshot.data;
                      return Row(
                        children: [
                          Icon(
                            Icons.event, 
                            size: 18,
                            color: holidayName != null ? Colors.red : Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(_selectedDate!),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: holidayName != null ? Colors.red : Colors.black,
                                  ),
                                ),
                                if (holidayName != null)
                                  Text(
                                    holidayName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('Tidak ada catatan pada tanggal ini'),
                        ),
                      ],
                    ),
                  )
                else
                  ...filtered.map(_buildAttendanceCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Keterangan',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _legendItem('Check In', Colors.green),
                _legendItem('Check Out', Colors.orange),
                _legendItem('Libur Nasional', Colors.red),
                _legendItem('Cuti', Colors.pink),
                _legendItem('Izin', Colors.blue),
                _legendItem('Sakit', Colors.yellow.shade700),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildMonthHeader() {
    final monthStr = DateFormat('MMMM yyyy').format(_focusedMonth);
    return Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
              _selectedDate = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
            });
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: Text(
              monthStr,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
              _selectedDate = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
            });
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(Map<int, _DayMarker> markers) {
    // Weekday headers
    final weekdays = ['S', 'M', 'S', 'R', 'K', 'J', 'S'];
    final firstOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startWeekday = firstOfMonth.weekday % 7; // make Sunday index 0
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;

    final cells = <Widget>[];
    cells.add(Row(
      children: weekdays
          .map((w) => Expanded(
                child: Center(
                  child: Text(w, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                ),
              ))
          .toList(),
    ));
    cells.add(const SizedBox(height: 6));

    int dayCounter = 1;
    for (int week = 0; week < 6; week++) {
      final row = <Widget>[];
      for (int wd = 0; wd < 7; wd++) {
        final index = week * 7 + wd;
        if (index < startWeekday || dayCounter > daysInMonth) {
          row.add(Expanded(child: SizedBox(height: 44)));
        } else {
          final marker = markers[dayCounter];
          final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayCounter);
          final isSelected = _selectedDate != null && _isSameDate(_selectedDate!, date);
          final isHoliday = marker?.isHoliday ?? false;
          final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
          
          row.add(Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDate = date),
              child: Container(
                height: 44,
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.blue.shade50 
                      : (isHoliday || isWeekend) 
                          ? Colors.red.shade50 
                          : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected 
                        ? Colors.blue 
                        : (isHoliday || isWeekend)
                            ? Colors.red.shade200
                            : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayCounter', 
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: (isHoliday || isWeekend) ? Colors.red.shade700 : Colors.black,
                      ),
                    ),
                    if (marker != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (marker.hasCheckIn)
                              _dot(Colors.green),
                            if (marker.hasCheckOut)
                              _dot(Colors.orange),
                            if (marker.isHoliday)
                              _dot(Colors.red),
                            if (marker.hasCuti)
                              _dot(Colors.pink),
                            if (marker.hasIzin)
                              _dot(Colors.blue),
                            if (marker.hasSakit)
                              _dot(Colors.yellow.shade700),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ));
          dayCounter++;
        }
      }
      cells.add(Row(children: row));
    }

    return Column(children: cells);
  }

  Future<Map<int, _DayMarker>> _buildDayMarkers(AttendanceProvider attendanceProvider, LeaveProvider leaveProvider) async {
    final markers = <int, _DayMarker>{};
    
    // Mark attendance days
    for (final att in attendanceProvider.history) {
      if (att.checkInTime.year == _focusedMonth.year && att.checkInTime.month == _focusedMonth.month) {
        final day = att.checkInTime.day;
        markers.putIfAbsent(day, () => _DayMarker());
        markers[day]!.hasCheckIn = true;
        if (att.checkOutTime != null) markers[day]!.hasCheckOut = true;
      }
    }
    
    // Mark leaves (cuti, izin, sakit)
    for (final leave in leaveProvider.leaves) {
      // Check if leave overlaps with focused month
      final monthStart = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      final monthEnd = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
      
      if (leave.startDate.isBefore(monthEnd.add(const Duration(days: 1))) &&
          leave.endDate.isAfter(monthStart.subtract(const Duration(days: 1)))) {
        // Mark each day in the leave range
        var current = leave.startDate.isAfter(monthStart) ? leave.startDate : monthStart;
        final end = leave.endDate.isBefore(monthEnd) ? leave.endDate : monthEnd;
        
        while (current.isBefore(end.add(const Duration(days: 1)))) {
          if (current.year == _focusedMonth.year && current.month == _focusedMonth.month) {
            final day = current.day;
            markers.putIfAbsent(day, () => _DayMarker());
            
            // Set leave type
            if (leave.leaveType == 'cuti') {
              markers[day]!.hasCuti = true;
            } else if (leave.leaveType == 'izin') {
              markers[day]!.hasIzin = true;
            } else if (leave.leaveType == 'sakit') {
              markers[day]!.hasSakit = true;
            }
          }
          current = current.add(const Duration(days: 1));
        }
      }
    }
    
    // Mark holidays for the entire month
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final isHoliday = await attendanceProvider.isHoliday(date);
      if (isHoliday) {
        markers.putIfAbsent(day, () => _DayMarker());
        markers[day]!.isHoliday = true;
        markers[day]!.holidayName = await attendanceProvider.getHolidayName(date);
      }
    }
    
    return markers;
  }

  // Kept for reference; use _filterBySelectedDateOrMonth instead

  List<dynamic> _filterBySelectedDateOrMonth(AttendanceProvider provider) {
    if (_selectedDate != null) {
      return provider.history.where((att) => _isSameDate(att.checkInTime, _selectedDate!)).toList();
    }
    // Fallback: show entries for the focused month
    return provider.history
        .where((att) => att.checkInTime.year == _focusedMonth.year && att.checkInTime.month == _focusedMonth.month)
        .toList();
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _dot(Color color) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildAttendanceCard(attendance) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormat.format(attendance.checkInTime),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.login, size: 20, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Check In',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        timeFormat.format(attendance.checkInTime),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        attendance.checkInLocation,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (attendance.checkOutTime != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.logout, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Check Out',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          timeFormat.format(attendance.checkOutTime),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          attendance.checkOutLocation ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Belum check out',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
