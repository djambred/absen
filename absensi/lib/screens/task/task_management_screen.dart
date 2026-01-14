import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../utils/error_handler.dart';

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({super.key});

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  final _apiService = ApiService();
  List<Map<String, dynamic>> _tasksAssignedToMe = [];
  List<Map<String, dynamic>> _tasksAssignedByMe = [];
  bool _isLoading = false;
  String _selectedTab = 'assigned_to_me';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        _apiService.getTasksAssignedToMe(),
        _apiService.getTasksAssignedByMe(),
      ]);

      setState(() {
        _tasksAssignedToMe = List<Map<String, dynamic>>.from(responses[0]['tasks']);
        _tasksAssignedByMe = List<Map<String, dynamic>>.from(responses[1]['tasks']);
      });
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, 'Gagal memuat tugas: ${e.toString()}');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    try {
      await _apiService.updateTaskStatus(taskId, status: newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status tugas berhasil diperbarui'),
            backgroundColor: Colors.green,
          ),
        );
        _loadTasks();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, 'Gagal memperbarui status: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Tugas'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTab = 'assigned_to_me'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _selectedTab == 'assigned_to_me' ? Colors.blue : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Tugas Saya (${_tasksAssignedToMe.length})',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTab == 'assigned_to_me' ? Colors.blue : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTab = 'assigned_by_me'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _selectedTab == 'assigned_by_me' ? Colors.blue : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Tugas Saya Buat (${_tasksAssignedByMe.length})',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTab == 'assigned_by_me' ? Colors.blue : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _selectedTab == 'assigned_to_me'
                        ? _buildAssignedToMeList(dateFormat)
                        : _buildAssignedByMeList(dateFormat),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAssignedToMeList(DateFormat dateFormat) {
    if (_tasksAssignedToMe.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada tugas yang ditugaskan',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tasksAssignedToMe.length,
      itemBuilder: (context, index) {
        final task = _tasksAssignedToMe[index];
        final dueDate = task['due_date'] != null ? DateTime.parse(task['due_date']) : null;
        final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now());
        final isCompleted = task['status'] == 'completed';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['title'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dari: ${task['assigned_by_name']}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(task['status']),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        task['status'].toString().replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                if (task['description'] != null && task['description'].toString().isNotEmpty) ...[
                  Text(
                    task['description'],
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    if (task['priority'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(task['priority']),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          task['priority'].toString().toUpperCase(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (dueDate != null) ...[
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: isOverdue ? Colors.red : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(dueDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue ? Colors.red : Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                if (!isCompleted) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _updateTaskStatus(task['id'], 'in_progress'),
                          child: const Text('Mulai'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateTaskStatus(task['id'], 'completed'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Selesai'),
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
    );
  }

  Widget _buildAssignedByMeList(DateFormat dateFormat) {
    if (_tasksAssignedByMe.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada tugas yang dibuat',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tasksAssignedByMe.length,
      itemBuilder: (context, index) {
        final task = _tasksAssignedByMe[index];
        final dueDate = task['due_date'] != null ? DateTime.parse(task['due_date']) : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['title'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Untuk: ${task['assigned_to_name']}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(task['status']),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        task['status'].toString().replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                if (task['description'] != null && task['description'].toString().isNotEmpty) ...[
                  Text(
                    task['description'],
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    if (task['priority'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(task['priority']),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          task['priority'].toString().toUpperCase(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (dueDate != null) ...[
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(dueDate),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return Colors.blue[100]!;
      case 'normal':
        return Colors.grey[300]!;
      case 'high':
        return Colors.orange[200]!;
      case 'urgent':
        return Colors.red[200]!;
      default:
        return Colors.grey[300]!;
    }
  }
}
