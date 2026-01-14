import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../models/leave_model.dart';
import '../../providers/leave_provider.dart';
import '../../services/api_service.dart';
import '../../utils/error_handler.dart';

class LeaveSubmissionScreen extends StatefulWidget {
  final LeaveType? initialLeaveType;

  const LeaveSubmissionScreen({super.key, this.initialLeaveType});

  @override
  State<LeaveSubmissionScreen> createState() => _LeaveSubmissionScreenState();
}

class _LeaveSubmissionScreenState extends State<LeaveSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  LeaveType? _selectedType;
  LeaveCategory? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  File? _attachmentFile;
  String? _selectedSupervisor;
  String? _selectedTaskAssignee;  // Who will handle tasks during leave
  TextEditingController? _taskDescriptionController;
  List<Map<String, dynamic>> _supervisors = [];
  bool _isSubmitting = false;
  bool _isLoadingSupervisors = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialLeaveType;
    _startTime = const TimeOfDay(hour: 8, minute: 0);
    _endTime = const TimeOfDay(hour: 17, minute: 0);
    _taskDescriptionController = TextEditingController();
    _loadSupervisors();
    
    // Set kategori default berdasarkan tipe yang dipilih
    if (_selectedType != null) {
      _setDefaultCategory();
    }
  }
  
  @override
  void dispose() {
    _reasonController.dispose();
    _taskDescriptionController?.dispose();
    super.dispose();
  }
  
  void _setDefaultCategory() {
    final categories = _getAvailableCategories();
    if (categories.isNotEmpty && _selectedCategory == null) {
      _selectedCategory = categories.first;
    }
  }

  String _getLeaveTypeCode(LeaveType type) {
    switch (type) {
      case LeaveType.cuti:
        return 'cuti';
      case LeaveType.sakit:
        return 'sakit';
      case LeaveType.izin:
        return 'izin';
    }
  }

  Future<void> _loadSupervisors() async {
    setState(() {
      _isLoadingSupervisors = true;
    });

    try {
      final apiService = ApiService();
      final result = await apiService.getSupervisors();
      setState(() {
        _supervisors = result
            .map((item) => item as Map<String, dynamic>)
            .toList();
        _isLoadingSupervisors = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSupervisors = false;
      });
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, 'Gagal memuat daftar atasan: ${e.toString()}');
      }
    }
  }

  List<LeaveCategory> _getAvailableCategories() {
    if (_selectedType == null) return [];

    switch (_selectedType!) {
      case LeaveType.cuti:
        return [LeaveCategory.cutiTahunan];
      case LeaveType.sakit:
        return [LeaveCategory.sakitDenganSurat, LeaveCategory.sakitTanpaSurat];
      case LeaveType.izin:
        return [LeaveCategory.dinasLuar, LeaveCategory.keperluanPribadi];
    }
  }

  Future<void> _pickDate(BuildContext context, bool isStartDate) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (_startDate ?? now) : (_endDate ?? _startDate ?? now),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('id', 'ID'),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickSakitDate(BuildContext context, bool isStartDate) async {
    final now = DateTime.now();
    // Allow selecting dates up to 30 days in the past for sick leave
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (_startDate ?? now) : (_endDate ?? _startDate ?? now),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('id', 'ID'),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime(BuildContext context, bool isStartTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? (_startTime ?? const TimeOfDay(hour: 8, minute: 0)) : (_endTime ?? const TimeOfDay(hour: 17, minute: 0)),
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _pickAttachment() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _attachmentFile = File(picked.path));
    }
  }

  void _submitLeave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      ErrorHandler.showErrorSnackBar(context, 'Pilih tanggal mulai dan selesai');
      return;
    }

    if (_selectedCategory == null) {
      ErrorHandler.showErrorSnackBar(context, 'Pilih kategori terlebih dahulu');
      return;
    }

    if (_selectedType == LeaveType.sakit && _selectedCategory == LeaveCategory.sakitDenganSurat && _attachmentFile == null) {
      ErrorHandler.showErrorSnackBar(context, 'Lampiran surat sakit wajib diisi');
      return;
    }

    if (_selectedSupervisor == null) {
      ErrorHandler.showErrorSnackBar(context, 'Pilih atasan untuk persetujuan');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final leaveProvider = context.read<LeaveProvider>();

      // Combine date and time for IZIN type
      DateTime startDateTime = _startDate!;
      DateTime endDateTime = _endDate!;

      if (_selectedType == LeaveType.izin && _startTime != null && _endTime != null) {
        startDateTime = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
          _startTime!.hour,
          _startTime!.minute,
        );
        endDateTime = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          _endTime!.hour,
          _endTime!.minute,
        );
      }

      // Debug: print values before submit
      debugPrint('Submitting leave:');
      debugPrint('  Type: ${_selectedType?.name}');
      debugPrint('  Category: ${_selectedCategory?.name}');
      debugPrint('  Start: $startDateTime');
      debugPrint('  End: $endDateTime');
      debugPrint('  Supervisor: $_selectedSupervisor');
      debugPrint('  Attachment: ${_attachmentFile?.path}');

      await leaveProvider.submitLeave(
        leaveType: _getLeaveTypeCode(_selectedType!),
        category: _selectedCategory!.code,
        startDate: startDateTime,
        endDate: endDateTime,
        reason: _reasonController.text.trim(),
        supervisorId: _selectedSupervisor,
        attachmentPath: _attachmentFile?.path,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan berhasil dikirim'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorDialog(context, ErrorHandler.mapError(e), onRetry: _submitLeave);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildLeaveTypeField() {
    return Card(
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.lock, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Jenis Pengajuan', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    _selectedType?.displayName ?? 'Tidak dipilih',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIzinForm() {
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Kategori', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<LeaveCategory>(
          initialValue: _selectedCategory,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.label),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          hint: const Text('Pilih kategori'),
          items: _getAvailableCategories()
              .map((cat) => DropdownMenuItem(value: cat, child: Text(cat.displayName)))
              .toList(),
          onChanged: (value) => setState(() => _selectedCategory = value),
          validator: (value) => value == null ? 'Pilih kategori' : null,
        ),
        const SizedBox(height: 16),
        const Text('Waktu Mulai', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () => _pickDate(context, true),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  child: Text(_startDate == null ? 'Tanggal' : dateFormat.format(_startDate!),
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => _pickTime(context, true),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.access_time),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  child: Text(_startTime == null ? 'Jam' : _startTime!.format(context),
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Waktu Selesai', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: _startDate == null ? null : () => _pickDate(context, false),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.event),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  child:
                      Text(_endDate == null ? 'Tanggal' : dateFormat.format(_endDate!),
                          style: const TextStyle(fontSize: 13)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => _pickTime(context, false),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.access_time),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  child: Text(_endTime == null ? 'Jam' : _endTime!.format(context),
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Alasan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _reasonController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Masukkan alasan izin...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Alasan wajib diisi' : null,
        ),
      ],
    );
  }

  Widget _buildCutiForm() {
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Tanggal Mulai', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pickDate(context, true),
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.calendar_today),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            child: Text(_startDate == null ? 'Pilih tanggal' : dateFormat.format(_startDate!)),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Tanggal Selesai', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _startDate == null ? null : () => _pickDate(context, false),
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.event),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            child: Text(_endDate == null ? 'Pilih tanggal' : dateFormat.format(_endDate!)),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Keterangan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _reasonController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Masukkan keterangan...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Keterangan wajib diisi' : null,
        ),
      ],
    );
  }

  Widget _buildSakitForm() {
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Kategori', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<LeaveCategory>(
          initialValue: _selectedCategory,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.label),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          hint: const Text('Pilih kategori sakit'),
          items: _getAvailableCategories()
              .map((cat) => DropdownMenuItem(value: cat, child: Text(cat.displayName)))
              .toList(),
          onChanged: (value) => setState(() {
            _selectedCategory = value;
            _attachmentFile = null;
          }),
          validator: (value) => value == null ? 'Pilih kategori' : null,
        ),
        const SizedBox(height: 16),
        const Text('Tanggal Mulai', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pickSakitDate(context, true),
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.calendar_today),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            child: Text(_startDate == null ? 'Pilih tanggal' : dateFormat.format(_startDate!)),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Tanggal Selesai', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _startDate == null ? null : () => _pickSakitDate(context, false),
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.event),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            child: Text(_endDate == null ? 'Pilih tanggal' : dateFormat.format(_endDate!)),
          ),
        ),
        if (_selectedCategory == LeaveCategory.sakitDenganSurat) ...[
          const SizedBox(height: 16),
          const Text('Bukti Surat Sakit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_attachmentFile == null)
            OutlinedButton.icon(
              onPressed: _pickAttachment,
              icon: const Icon(Icons.attach_file),
              label: const Text('Upload File'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )
          else
            Card(
              child: ListTile(
                leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                title: Text(_attachmentFile!.path.split('/').last,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => setState(() => _attachmentFile = null),
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        const Text('Keterangan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _reasonController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Masukkan keterangan...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Keterangan wajib diisi' : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final leaveProvider = context.watch<LeaveProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan Cuti/Izin'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (leaveProvider.currentQuota != null)
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sisa cuti tahunan: ${leaveProvider.currentQuota!.remainingQuota} dari ${leaveProvider.currentQuota!.totalQuota} hari',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _buildLeaveTypeField(),
            if (_selectedType == LeaveType.izin)
              _buildIzinForm()
            else if (_selectedType == LeaveType.cuti)
              _buildCutiForm()
            else if (_selectedType == LeaveType.sakit)
              _buildSakitForm(),
            const SizedBox(height: 16),
            const Text('Atasan untuk Persetujuan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _isLoadingSupervisors
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<String>(
                    initialValue: _selectedSupervisor,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    hint: const Text('Pilih atasan'),
                    items: _supervisors.isEmpty
                        ? [const DropdownMenuItem(value: null, child: Text('Tidak ada atasan tersedia'))]
                        : _supervisors.map((supervisor) {
                            return DropdownMenuItem<String>(
                              value: supervisor['id'],
                              child: Text(
                                '${supervisor['name']} (${supervisor['nip']})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                    onChanged: _supervisors.isEmpty ? null : (value) => setState(() => _selectedSupervisor = value),
                    validator: (value) => value == null ? 'Pilih atasan' : null,
                  ),
            const SizedBox(height: 20),
            const Text('Penugasan Saat Cuti (Opsional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedTaskAssignee,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.assignment_ind),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                hintText: 'Siapa yang akan handle tugas',
              ),
              items: _supervisors.isEmpty
                  ? [const DropdownMenuItem(value: null, child: Text('Tidak ada orang tersedia'))]
                  : _supervisors.map((supervisor) {
                      return DropdownMenuItem<String>(
                        value: supervisor['id'],
                        child: Text(
                          '${supervisor['name']} (${supervisor['nip']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
              onChanged: (value) => setState(() => _selectedTaskAssignee = value),
            ),
            if (_selectedTaskAssignee != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _taskDescriptionController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.description),
                  hintText: 'Deskripsi tugas yang perlu ditangani',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 3,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitLeave,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Ajukan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
