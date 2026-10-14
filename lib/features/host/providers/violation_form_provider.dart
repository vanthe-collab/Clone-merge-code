import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/violation_model.dart';
import '../models/violation_record_model.dart';
import '../repositories/violation_repository.dart';
import 'violation_provider.dart';

class ViolationFormState {
  final HostOccupiedRoomItem? selectedRoom;
  final List<ViolationModel> selectedViolations;
  final double fineAmount;
  final String paymentMethod; // 'NEXT_INVOICE', 'CASH', 'DEPOSIT'
  final List<File> evidenceFiles; // max 5 files
  final String note;
  final bool isSubmitting;
  final String? errorMessage;

  int get selectedViolationCount => selectedViolations.length;
  int get evidenceCount => evidenceFiles.length;

  const ViolationFormState({
    this.selectedRoom,
    this.selectedViolations = const [],
    this.fineAmount = 0.0,
    this.paymentMethod = 'NEXT_INVOICE',
    this.evidenceFiles = const [],
    this.note = '',
    this.isSubmitting = false,
    this.errorMessage,
  });

  ViolationFormState copyWith({
    HostOccupiedRoomItem? selectedRoom,
    bool clearSelectedRoom = false,
    List<ViolationModel>? selectedViolations,
    double? fineAmount,
    String? paymentMethod,
    List<File>? evidenceFiles,
    String? note,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ViolationFormState(
      selectedRoom: clearSelectedRoom ? null : (selectedRoom ?? this.selectedRoom),
      selectedViolations: selectedViolations ?? this.selectedViolations,
      fineAmount: fineAmount ?? this.fineAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      evidenceFiles: evidenceFiles ?? this.evidenceFiles,
      note: note ?? this.note,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ViolationFormNotifier extends Notifier<ViolationFormState> {
  final ViolationRepository? _customRepo;
  ViolationFormState? _localState;

  ViolationFormNotifier([this._customRepo, ViolationFormState? initialState])
      : _localState = initialState;

  @override
  ViolationFormState build() {
    return _localState ?? const ViolationFormState();
  }

  @override
  ViolationFormState get state {
    try {
      return super.state;
    } catch (_) {
      return _localState ?? const ViolationFormState();
    }
  }

  @override
  set state(ViolationFormState value) {
    _localState = value;
    try {
      super.state = value;
    } catch (_) {
      // Fallback khi chạy unit test thuần túy không qua container
    }
  }

  void selectRoom(HostOccupiedRoomItem room) {
    state = state.copyWith(selectedRoom: room, clearError: true);
  }

  void toggleViolation(ViolationModel item) {
    final list = List<ViolationModel>.from(state.selectedViolations);
    final exists = list.any((v) => v.id == item.id);

    if (exists) {
      list.removeWhere((v) => v.id == item.id);
    } else {
      list.add(item);
    }

    // Tự động tính tổng tiền phạt từ danh sách lỗi đã chọn
    final total = list.fold<double>(0.0, (sum, v) => sum + v.defaultFine);

    state = state.copyWith(
      selectedViolations: list,
      fineAmount: total,
      clearError: true,
    );
  }

  void setFineAmount(double amount) {
    state = state.copyWith(fineAmount: amount, clearError: true);
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method, clearError: true);
  }

  String? addEvidenceFile(File file) {
    if (state.evidenceFiles.length >= 5) {
      return 'Chỉ được tải lên tối đa 5 tệp bằng chứng';
    }

    // Kiểm tra dung lượng < 25MB
    final sizeInBytes = file.lengthSync();
    if (sizeInBytes > 25 * 1024 * 1024) {
      return 'Dung lượng tệp vượt quá 25MB cho phép';
    }

    // Kiểm tra định dạng JPG, PNG, MP4
    final ext = file.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'mp4'].contains(ext)) {
      return 'Chỉ hỗ trợ định dạng ảnh JPG, PNG hoặc video MP4';
    }

    final updated = List<File>.from(state.evidenceFiles)..add(file);
    state = state.copyWith(evidenceFiles: updated, clearError: true);
    return null;
  }

  void removeEvidenceFile(int index) {
    if (index < 0 || index >= state.evidenceFiles.length) return;
    final updated = List<File>.from(state.evidenceFiles)..removeAt(index);
    state = state.copyWith(evidenceFiles: updated, clearError: true);
  }

  void setNote(String note) {
    state = state.copyWith(note: note, clearError: true);
  }

  String? validate() {
    if (state.selectedRoom == null) {
      return 'Vui lòng chọn căn hộ / khách thuê vi phạm';
    }
    if (state.selectedViolations.isEmpty) {
      return 'Vui lòng chọn ít nhất một hành vi vi phạm';
    }
    if (state.fineAmount <= 0) {
      return 'Mức phạt phải lớn hơn 0 VNĐ';
    }
    if (state.evidenceFiles.length > 5) {
      return 'Tối đa 5 tệp bằng chứng';
    }
    return null;
  }

  ViolationRepository get _repo {
    final custom = _customRepo;
    if (custom != null) return custom;
    try {
      return ref.read(violationRepositoryProvider);
    } catch (_) {
      return ViolationRepository();
    }
  }

  Future<bool> submit(String hostId) async {
    final error = validate();
    if (error != null) {
      state = state.copyWith(errorMessage: error);
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final repository = _repo;
      final room = state.selectedRoom!;
      final recordId = 'bb_${DateTime.now().millisecondsSinceEpoch}';

      // 1. Tải bằng chứng lên Storage
      List<String> evidenceUrls = [];
      if (state.evidenceFiles.isNotEmpty) {
        evidenceUrls = await repository.uploadEvidenceFiles(
          hostId: hostId,
          recordId: recordId,
          files: state.evidenceFiles,
        );
      }

      // 2. Tạo biên bản vi phạm
      final record = ViolationRecordModel(
        id: recordId,
        landlordId: hostId,
        roomId: room.roomId,
        roomCode: room.roomCode,
        propertyName: room.propertyName,
        periodId: room.periodId,
        tenantId: room.tenantId,
        tenantName: room.tenantName,
        tenantPhone: room.tenantPhone,
        violationIds: state.selectedViolations.map((v) => v.id).toList(),
        violationTitles: state.selectedViolations.map((v) => v.title).toList(),
        totalFine: state.fineAmount,
        paymentMethod: state.paymentMethod,
        status: state.paymentMethod == 'NEXT_INVOICE'
            ? 'ADDED_TO_INVOICE'
            : 'PENDING',
        description: state.note.trim().isNotEmpty
            ? state.note.trim()
            : 'Ghi nhận vi phạm ${state.selectedViolations.map((v) => v.title).join(', ')}',
        evidenceUrls: evidenceUrls,
        createdAt: DateTime.now(),
      );

      await repository.createViolationRecord(record);

      state = const ViolationFormState(); // reset form
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Lỗi khi lưu biên bản vi phạm: $e',
      );
      return false;
    }
  }
}

final violationFormNotifierProvider =
    NotifierProvider<ViolationFormNotifier, ViolationFormState>(
  ViolationFormNotifier.new,
);
