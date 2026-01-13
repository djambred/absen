class LeaveQuota {
  final String id;
  final String userId;
  final int year;
  final int totalQuota;
  final int usedQuota;
  final int remainingQuota;
  final DateTime createdAt;
  final DateTime updatedAt;

  LeaveQuota({
    required this.id,
    required this.userId,
    required this.year,
    required this.totalQuota,
    required this.usedQuota,
    required this.remainingQuota,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LeaveQuota.fromJson(Map<String, dynamic> json) {
    return LeaveQuota(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      year: json['year'] ?? DateTime.now().year,
      totalQuota: json['total_quota'] ?? 12,
      usedQuota: json['used_quota'] ?? 0,
      remainingQuota: json['remaining_quota'] ?? 12,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  double get percentageUsed => totalQuota > 0 ? (usedQuota / totalQuota) * 100 : 0;
}

enum LeaveType {
  cuti,
  sakit,
  izin;

  String get displayName {
    switch (this) {
      case LeaveType.cuti:
        return 'Cuti';
      case LeaveType.sakit:
        return 'Sakit';
      case LeaveType.izin:
        return 'Izin';
    }
  }
}

enum LeaveCategory {
  cutiTahunan,
  sakitDenganSurat,
  sakitTanpaSurat,
  dinasLuar,
  keperluanPribadi;

  String get displayName {
    switch (this) {
      case LeaveCategory.cutiTahunan:
        return 'Cuti Tahunan';
      case LeaveCategory.sakitDenganSurat:
        return 'Sakit (Dengan Surat)';
      case LeaveCategory.sakitTanpaSurat:
        return 'Sakit (Tanpa Surat)';
      case LeaveCategory.dinasLuar:
        return 'Dinas Luar';
      case LeaveCategory.keperluanPribadi:
        return 'Keperluan Pribadi';
    }
  }

  String get code {
    switch (this) {
      case LeaveCategory.cutiTahunan:
        return 'cuti_tahunan';
      case LeaveCategory.sakitDenganSurat:
        return 'sakit_dengan_surat';
      case LeaveCategory.sakitTanpaSurat:
        return 'sakit_tanpa_surat';
      case LeaveCategory.dinasLuar:
        return 'dinas_luar';
      case LeaveCategory.keperluanPribadi:
        return 'keperluan_pribadi';
    }
  }
}

enum LeaveStatus {
  pending,
  approvedBySupervisor,
  approvedByHr,
  rejected,
  cancelled;

  String get displayName {
    switch (this) {
      case LeaveStatus.pending:
        return 'Menunggu Persetujuan';
      case LeaveStatus.approvedBySupervisor:
        return 'Disetujui Atasan';
      case LeaveStatus.approvedByHr:
        return 'Disetujui HR';
      case LeaveStatus.rejected:
        return 'Ditolak';
      case LeaveStatus.cancelled:
        return 'Dibatalkan';
    }
  }

  String get code {
    switch (this) {
      case LeaveStatus.pending:
        return 'pending';
      case LeaveStatus.approvedBySupervisor:
        return 'approved_by_supervisor';
      case LeaveStatus.approvedByHr:
        return 'approved_by_hr';
      case LeaveStatus.rejected:
        return 'rejected';
      case LeaveStatus.cancelled:
        return 'cancelled';
    }
  }
}

class Leave {
  final String id;
  final String userId;
  final String leaveType;
  final String category;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final String reason;
  final String? attachmentUrl;
  final String status;
  final String? approvedByLevel1;
  final DateTime? approvedAtLevel1;
  final String? approvalNotesLevel1;
  final String? approvedByLevel2;
  final DateTime? approvedAtLevel2;
  final String? approvalNotesLevel2;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final bool deductedFromQuota;
  final int? quotaYear;
  final DateTime createdAt;
  final DateTime updatedAt;

  Leave({
    required this.id,
    required this.userId,
    required this.leaveType,
    required this.category,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.reason,
    this.attachmentUrl,
    required this.status,
    this.approvedByLevel1,
    this.approvedAtLevel1,
    this.approvalNotesLevel1,
    this.approvedByLevel2,
    this.approvedAtLevel2,
    this.approvalNotesLevel2,
    this.rejectedBy,
    this.rejectedAt,
    this.rejectionReason,
    required this.deductedFromQuota,
    this.quotaYear,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Leave.fromJson(Map<String, dynamic> json) {
    try {
      return Leave(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        leaveType: json['leave_type'] ?? '',
        category: json['category'] ?? '',
        startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : DateTime.now(),
        endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : DateTime.now(),
        totalDays: json['total_days'] ?? 0,
        reason: json['reason'] ?? '',
        attachmentUrl: json['attachment_url'],
        status: json['status'] ?? 'pending',
        approvedByLevel1: json['approved_by_level_1'],
        approvedAtLevel1: json['approved_at_level_1'] != null
            ? DateTime.parse(json['approved_at_level_1'])
            : null,
        approvalNotesLevel1: json['approval_notes_level_1'],
        approvedByLevel2: json['approved_by_level_2'],
        approvedAtLevel2: json['approved_at_level_2'] != null
            ? DateTime.parse(json['approved_at_level_2'])
            : null,
        approvalNotesLevel2: json['approval_notes_level_2'],
        rejectedBy: json['rejected_by'],
        rejectedAt: json['rejected_at'] != null
            ? DateTime.parse(json['rejected_at'])
            : null,
        rejectionReason: json['rejection_reason'],
        deductedFromQuota: json['deducted_from_quota'] ?? false,
        quotaYear: json['quota_year'],
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error parsing Leave from JSON: $e');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }

  bool get isActive {
    final now = DateTime.now();
    return (status == 'approved_by_hr' || status == 'approved_by_supervisor') &&
        startDate.isBefore(now.add(const Duration(days: 1))) &&
        endDate.isAfter(now.subtract(const Duration(days: 1)));
  }

  bool get isDinasLuar => category == 'dinas_luar';
  bool get isKeperluanPribadi => category == 'keperluan_pribadi';
}
