import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../utils/error_handler.dart';

class ActiveLeavesScreen extends StatefulWidget {
  const ActiveLeavesScreen({super.key});

  @override
  State<ActiveLeavesScreen> createState() => _ActiveLeavesScreenState();
}

class _ActiveLeavesScreenState extends State<ActiveLeavesScreen> {
  final _apiService = ApiService();
  List<Map<String, dynamic>> _activeLeaves = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadActiveLeaves();
  }

  Future<void> _loadActiveLeaves() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getActiveLeaves();
      setState(() {
        _activeLeaves = List<Map<String, dynamic>>.from(response['active_leaves']);
      });
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, 'Gagal memuat data: ${e.toString()}');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Karyawan Sedang Cuti'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadActiveLeaves,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _activeLeaves.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada karyawan yang sedang cuti',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _activeLeaves.length,
                    itemBuilder: (context, index) {
                      final leave = _activeLeaves[index];
                      final startDate = DateTime.parse(leave['start_date']);
                      final endDate = DateTime.parse(leave['end_date']);
                      final daysLeft = endDate.difference(today).inDays + 1;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.blue[100],
                                    child: Text(
                                      leave['user_name'][0].toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.blue[900],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          leave['user_name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          '${leave['user_nip']} • ${leave['user_department']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getTypeColor(leave['leave_type']),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      leave['leave_type'].toString().toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _getTypeTextColor(leave['leave_type']),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.event_available, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Total: ${leave['total_days']} hari',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  if (daysLeft > 0) ...[
                                    Text(
                                      ' • ',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    Text(
                                      'Sisa: $daysLeft hari',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (leave['reason'] != null && leave['reason'].toString().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.info_outline, size: 14, color: Colors.grey[700]),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Keterangan:',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        leave['reason'],
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (leave['approved_by_name'] != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.check_circle, size: 14, color: Colors.green[700]),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Disetujui oleh: ${leave['approved_by_name']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'cuti':
        return Colors.pink[100]!;
      case 'izin':
        return Colors.blue[100]!;
      case 'sakit':
        return Colors.yellow[100]!;
      default:
        return Colors.grey[100]!;
    }
  }

  Color _getTypeTextColor(String type) {
    switch (type.toLowerCase()) {
      case 'cuti':
        return Colors.pink[900]!;
      case 'izin':
        return Colors.blue[900]!;
      case 'sakit':
        return Colors.orange[900]!;
      default:
        return Colors.grey[900]!;
    }
  }
}
