import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../utils/error_handler.dart';

class TaskSubmissionScreen extends StatefulWidget {
  const TaskSubmissionScreen({super.key});

  @override
  State<TaskSubmissionScreen> createState() => _TaskSubmissionScreenState();
}

class _TaskSubmissionScreenState extends State<TaskSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  
  final _apiService = ApiService();
  
  List<Map<String, dynamic>> _colleagues = [];
  String? _selectedAssignee;
  String? _selectedPriority = 'normal';
  DateTime? _selectedDueDate;
  bool _isLoading = false;
  bool _isLoadingColleagues = false;

  @override
  void initState() {
    super.initState();
    _loadColleagues();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadColleagues() async {
    setState(() => _isLoadingColleagues = true);
    try {
      final supervisorsList = await _apiService.getSupervisors();
      setState(() {
        _colleagues = List<Map<String, dynamic>>.from(
          supervisorsList.map((e) => e as Map<String, dynamic>)
        );
      });
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, 'Gagal memuat daftar orang: ${e.toString()}');
      }
    } finally {
      setState(() => _isLoadingColleagues = false);
    }
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() => _selectedDueDate = picked);
    }
  }

  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAssignee == null) {
      ErrorHandler.showErrorSnackBar(context, 'Pilih siapa yang akan menangani tugas');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _apiService.submitTask(
        title: _titleController.text.trim(),
        assignedToId: _selectedAssignee!,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        dueDate: _selectedDueDate?.toIso8601String(),
        priority: _selectedPriority,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tugas berhasil diajukan'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, 'Gagal mengajukan tugas: ${e.toString()}');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan Tugas'),
        elevation: 0,
      ),
      body: _isLoadingColleagues
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Judul Tugas',
                      prefixIcon: const Icon(Icons.assignment),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Judul tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Deskripsi Tugas',
                      prefixIcon: const Icon(Icons.description),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  const Text('Tugaskan ke', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedAssignee,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    hint: const Text('Pilih orang yang ditugaskan'),
                    items: _colleagues.map((colleague) {
                      return DropdownMenuItem<String>(
                        value: colleague['id'],
                        child: Text(
                          '${colleague['name']} (${colleague['nip']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedAssignee = value),
                    validator: (value) => value == null ? 'Pilih orang yang ditugaskan' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Prioritas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['low', 'normal', 'high', 'urgent'].map((priority) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(priority),
                            selected: _selectedPriority == priority,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedPriority = priority);
                              }
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Tanggal Deadline (Opsional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectDueDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.grey),
                          const SizedBox(width: 12),
                          Text(
                            _selectedDueDate == null
                                ? 'Pilih tanggal deadline'
                                : dateFormat.format(_selectedDueDate!),
                            style: TextStyle(
                              color: _selectedDueDate == null ? Colors.grey : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Catatan Tambahan (Opsional)',
                      prefixIcon: const Icon(Icons.note),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitTask,
                    icon: const Icon(Icons.send),
                    label: const Text('Ajukan Tugas'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
