import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/host/models/violation_model.dart';
import 'package:home_share/features/host/models/violation_record_model.dart';
import 'package:home_share/features/host/models/invoice_line_model.dart';

void main() {
  group('ViolationModel Tests', () {
    test('parses from English keys map correctly', () {
      final now = DateTime.now();
      final map = {
        'title': 'Ồn ào sau 23h',
        'description': 'Mở nhạc lớn sau giờ giới nghiêm',
        'defaultFine': 200000.0,
        'category': 'Trật tự',
        'iconName': 'volume_up',
        'isActive': true,
        'createdAt': Timestamp.fromDate(now),
      };

      final model = ViolationModel.fromMap(map, 'vp_01');
      expect(model.id, 'vp_01');
      expect(model.title, 'Ồn ào sau 23h');
      expect(model.defaultFine, 200000.0);
      expect(model.category, 'Trật tự');

      // Check Dual Aliases
      expect(model.viPhamId, 'vp_01');
      expect(model.ten, 'Ồn ào sau 23h');
      expect(model.moTa, 'Mở nhạc lớn sau giờ giới nghiêm');
      expect(model.mucPhatMacDinh, 200000.0);
      expect(model.nhomViPham, 'Trật tự');
      expect(model.trangThai, 'active');
    });

    test('parses from Vietnamese keys map correctly', () {
      final map = {
        'ten': 'Hút thuốc trong phòng',
        'moTa': 'Phát hiện tàn thuốc lá',
        'mucPhatMacDinh': 300000,
        'nhomViPham': 'Phòng cháy',
        'trangThai': 'active',
      };

      final model = ViolationModel.fromMap(map, 'vp_02');
      expect(model.title, 'Hút thuốc trong phòng');
      expect(model.defaultFine, 300000.0);
      expect(model.category, 'Phòng cháy');
      expect(model.isActive, true);
    });

    test('toMap includes both English and Vietnamese keys', () {
      final now = DateTime(2026, 10, 11);
      final model = ViolationModel(
        id: 'vp_03',
        title: 'Để rác sai nơi quy định',
        defaultFine: 150000,
        createdAt: now,
      );

      final map = model.toMap();
      expect(map['title'], 'Để rác sai nơi quy định');
      expect(map['ten'], 'Để rác sai nơi quy định');
      expect(map['defaultFine'], 150000.0);
      expect(map['mucPhatMacDinh'], 150000.0);
    });
  });

  group('ViolationRecordModel Tests', () {
    test('parses from map and normalizes status and dual aliases', () {
      final now = DateTime(2026, 10, 11);
      final map = {
        'landlordId': 'host_01',
        'roomId': 'room_203',
        'roomCode': 'P.203',
        'tenantId': 'user_02',
        'tenantName': 'Lê Hoàng Nam',
        'tenantPhone': '0912345678',
        'violationIds': ['vp_01', 'vp_02'],
        'violationTitles': ['Để rác sai nơi quy định', 'Ồn ào sau 23h'],
        'totalFine': 350000.0,
        'paymentMethod': 'NEXT_INVOICE',
        'status': 'PENDING',
        'description': 'Vi phạm lần 1',
        'evidenceUrls': ['url1', 'url2'],
        'createdAt': Timestamp.fromDate(now),
      };

      final record = ViolationRecordModel.fromMap(map, 'rec_01');
      expect(record.id, 'rec_01');
      expect(record.landlordId, 'host_01');
      expect(record.roomCode, 'P.203');
      expect(record.tenantName, 'Lê Hoàng Nam');
      expect(record.violationIds.length, 2);
      expect(record.totalFine, 350000.0);
      expect(record.isPending, true);
      expect(record.statusDisplayText, 'Chờ nộp');
      expect(record.paymentMethodDisplayText, 'Cộng vào tiền phòng tháng sau');

      // Dual Aliases
      expect(record.bienBanId, 'rec_01');
      expect(record.chuNhaId, 'host_01');
      expect(record.phongId, 'room_203');
      expect(record.soPhong, 'P.203');
      expect(record.nguoiDungId, 'user_02');
      expect(record.hoTen, 'Lê Hoàng Nam');
      expect(record.tongTienPhat, 350000.0);
      expect(record.chungCu, ['url1', 'url2']);
    });

    test('handles status transitions correctly', () {
      final record = ViolationRecordModel(
        id: 'rec_02',
        landlordId: 'host_01',
        roomId: 'room_101',
        tenantId: 'user_01',
        tenantName: 'Trần Văn A',
        totalFine: 200000,
        status: 'PAID',
        createdAt: DateTime.now(),
      );

      expect(record.isPaid, true);
      expect(record.isPending, false);
      expect(record.statusDisplayText, 'Đã thanh toán');

      final addedRecord = record.copyWith(status: 'ADDED_TO_INVOICE');
      expect(addedRecord.isAddedToInvoice, true);
      expect(addedRecord.statusDisplayText, 'Đã trừ vào tiền thuê');
    });
  });

  group('InvoiceLineModel Tests', () {
    test('serializes and deserializes with Database.docx keys', () {
      final now = DateTime.now();
      final map = {
        'bienBanId': 'rec_01',
        'viPhamId': 'vp_01',
        'phongId': 'room_203',
        'kyThue_id': 'period_01',
        'soTien': 150000.0,
        'mucDich': 'PhatViPham',
        'ten': 'Phạt để rác',
        'trangThai': 'pending',
        'createdAt': Timestamp.fromDate(now),
      };

      final line = InvoiceLineModel.fromMap(map, 'line_01');
      expect(line.id, 'line_01');
      expect(line.violationRecordId, 'rec_01');
      expect(line.violationId, 'vp_01');
      expect(line.roomId, 'room_203');
      expect(line.periodId, 'period_01');
      expect(line.amount, 150000.0);

      // Check Dual Aliases
      expect(line.lineId, 'line_01');
      expect(line.bienBanId, 'rec_01');
      expect(line.viPhamId, 'vp_01');
      expect(line.phongId, 'room_203');
      expect(line.kyThue_id, 'period_01');
      expect(line.soTien, 150000.0);
    });
  });
}
