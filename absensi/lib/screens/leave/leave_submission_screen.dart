import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../models/leave_model.dart';
import '../../providers/leave_provider.dart';
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
  File? _attachmentFile;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialLeaveType;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
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
      initialDate: isStartDate 
          ? (_startDate ?? now) 
          : (_endDate ?? _startDate ?? now),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('id', 'ID'),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Reset end date if it's before start date
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickAttachment() async {
    try {
      final picker = ImagePicker();
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pilih Sumber'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _attachmentFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          'Gagal memilih file: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _submitLeave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedType == null) {
      ErrorHandler.showErrorSnackBar(
        context,
        'Pilih jenis pengajuan',
      );
      return;
    }

    if (_selectedCategory == null) {
      ErrorHandler.showErrorSnackBar(
        context,
        'Pilih kategori',
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ErrorHandler.showErrorSnackBar(
        context,
        'Pilih tanggal mulai dan selesai',
      );
      return;
    }

    // Validate attachment for sakit dengan surat
    if (_selectedCategory == LeaveCategory.sakitDenganSurat && _attachmentFile == null) {
      ErrorHandler.showErrorSnackBar(
        context,
        'Lampiran surat sakit wajib diisi',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final leaveProvider = context.read<LeaveProvider>();
      
      await leaveProvider.submitLeave(
        leaveType: _selectedType!.name,
        category: _selectedCategory!.name,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim(),
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
        ErrorHandler.showErrorDialog(
          context,
          ErrorHandler.mapError(e),
          onRetry: _submitLeave,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');
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
            // Leave Quota Info
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
            const SizedBox(height: 12),
            
            // Working Days Info
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.calendar_today, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Perhitungan Hari Kerja',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Akhir pekan (Sabtu-Minggu) dan hari libur nasional tidak dihitung',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Leave Type Selection
            const Text(
              'Jenis Pengajuan',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<LeaveType>(
              value: _selectedType,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.category),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              hint: const Text('Pilih jenis'),
              items: LeaveType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value;
                  _selectedCategory = null; // Reset category
                  _attachmentFile = null; // Reset attachment
                });
              },
              validator: (value) => value == null ? 'Pilih jenis pengajuan' : null,
            ),
            const SizedBox(height: 16),

            // Category Selection
            if (_selectedType != null) ...[
              const Text(
                'Kategori',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<LeaveCategory>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.label),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                hint: const Text('Pilih kategori'),
                items: _getAvailableCategories().map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    _attachmentFile = null; // Reset attachment when category changes
                  });
                },
                validator: (value) => value == null ? 'Pilih kategori' : null,
              ),
              const SizedBox(height: 16),
            ],

            // Date Range
            const Text(
              'Periode',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(context, true),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      child: Text(
                        _startDate == null 
                            ? 'Tanggal mulai'
                            : dateFormat.format(_startDate!),
                        style: TextStyle(
                          fontSize: 13,
                          color: _startDate == null ? Colors.grey : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _startDate == null ? null : () => _pickDate(context, false),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.event),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      child: Text(
                        _endDate == null 
                            ? 'Tanggal selesai'
                            : dateFormat.format(_endDate!),
                        style: TextStyle(
                          fontSize: 13,
                          color: _endDate == null ? Colors.grey : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Reason
            const Text(
              'Alasan/Keterangan',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Masukkan alasan pengajuan...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Alasan wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Attachment (for sakit dengan surat)
            if (_selectedCategory == LeaveCategory.sakitDenganSurat) ...[
              const Text(
                'Lampiran Surat Sakit',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_attachmentFile == null)
                OutlinedButton.icon(
                  onPressed: _pickAttachment,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Pilih File'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                )
              else
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                    title: Text(
                      _attachmentFile!.path.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _attachmentFile = null),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],

            // Submit Button
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitLeave,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Ajukan',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),

            // Info Note
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Catatan Penting',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• Hari libur nasional dan akhir pekan TIDAK dihitung sebagai cuti\n'
                          '• Sistem otomatis exclude tanggal merah dari perhitungan\n'
                          '• Pengajuan cuti akan mengurangi jatah cuti tahunan\n'
                          '• Sakit dengan surat tidak mengurangi cuti tahunan\n'
                          '• Pengajuan memerlukan persetujuan supervisor dan HRD',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
