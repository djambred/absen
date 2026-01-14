import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../utils/error_handler.dart';

class LeaveApprovalScreen extends StatefulWidget {
  const LeaveApprovalScreen({super.key});

  @override
  State<LeaveApprovalScreen> createState() => _LeaveApprovalScreenState();
}

class _LeaveApprovalScreenState extends State<LeaveApprovalScreen> {
  final _apiService = ApiService();
  List<Map<String, dynamic>> _pendingApprovals = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPendingApprovals();
  }

  Future<void> _loadPendingApprovals() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getPendingApprovals();
      setState(() {
        _pendingApprovals = List<Map<String, dynamic>>.from(response['pending_approvals']);
      });
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, 'Gagal memuat data: ${e.toString()}');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveLeave(String leaveId) async {
    try {
      await _apiService.approveLeave(leaveId.toString(), level: 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan disetujui'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPendingApprovals();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, 'Gagal menyetujui: ${e.toString()}');
      }
    }
  }

  Future<void> _rejectLeave(String leaveId, String notes) async {
    try {
      await _apiService.rejectLeave(leaveId.toString(), notes: notes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan ditolak'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadPendingApprovals();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, 'Gagal menolak: ${e.toString()}');
      }
    }
  }

  void _showApprovalDialog(Map<String, dynamic> leave) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setujui Pengajuan?'),
        content: Text('Apakah Anda yakin ingin menyetujui pengajuan dari ${leave['user_name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _approveLeave(leave['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> leave) {
    final notesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Pengajuan?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pengajuan dari ${leave['user_name']}'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Alasan penolakan',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final notes = notesController.text.trim();
              if (notes.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Harap isi alasan penolakan')),
                );
                return;
              }
              Navigator.pop(context);
              _rejectLeave(leave['id'], notes);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Persetujuan Cuti/Izin'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadPendingApprovals,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _pendingApprovals.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada pengajuan pending',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingApprovals.length,
                    itemBuilder: (context, index) {
                      final leave = _pendingApprovals[index];
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
                                      style: TextStyle(color: Colors.blue[900]),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'PENDING',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[900],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(
                                      leave['leave_type'].toString().toUpperCase(),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: _getTypeColor(leave['leave_type']),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${leave['total_days']} hari',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${dateFormat.format(DateTime.parse(leave['start_date']))} - ${dateFormat.format(DateTime.parse(leave['end_date']))}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                              if (leave['reason'] != null && leave['reason'].toString().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Keterangan:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
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
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showRejectDialog(leave),
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('Tolak'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showApprovalDialog(leave),
                                      icon: const Icon(Icons.check, size: 18),
                                      label: const Text('Setujui'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
}
