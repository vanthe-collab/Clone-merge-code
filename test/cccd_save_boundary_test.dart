import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/profile/models/cccd_data.dart';
import 'package:home_share/features/profile/models/cccd_validation_models.dart';
import 'package:home_share/features/profile/services/cccd_image_evidence_validator.dart';

void main() {
  const validator = CccdImageEvidenceValidator();

  const frontEvidence = CccdImageEvidence(
    side: CccdImageSide.front,
    normalizedOcrText: 'CĂN CƯỚC CÔNG DÂN',
    qrPayload: '079201000001||NGUYEN VAN A|01012000|Nam|TP HO CHI MINH|01012022',
    imageByteHash: 'hash_front',
    width: 800,
    height: 600,
    byteLength: 50000,
    filePath: '/synthetic/front.jpg',
  );

  const backEvidence = CccdImageEvidence(
    side: CccdImageSide.back,
    normalizedOcrText: 'ĐẶC ĐIỂM NHẬN DẠNG',
    imageByteHash: 'hash_back',
    width: 800,
    height: 600,
    byteLength: 50000,
    filePath: '/synthetic/back.jpg',
  );

  const verifiedData = CccdData(
    idNumber: '079201000001',
    fullName: 'NGUYEN VAN A',
    birthDate: '01/01/2000',
    gender: 'Nam',
    address: 'TP HO CHI MINH',
    issueDate: '01/01/2022',
  );

  group('Save boundary của bằng chứng CCCD', () {
    test('Không cho lưu khi proof không hợp lệ', () {
      const proof = CccdValidationProof(
        isValid: false,
        rejectionReasonCode: CccdValidationReasonCodes.proofIncomplete,
      );

      expect(validator.canSave(proof), isFalse);
    });

    test('Không cho lưu khi proof thiếu dữ liệu hoặc dùng phiên bản cũ', () {
      const legacyProof = CccdValidationProof(
        isValid: true,
        version: 'legacy_v0',
        verifiedData: null,
        frontEvidence: frontEvidence,
        backEvidence: backEvidence,
      );

      expect(validator.canSave(legacyProof), isFalse);
    });

    test('Không cho lưu khi hai mặt bị gán sai phía', () {
      const wrongSideProof = CccdValidationProof(
        isValid: true,
        frontEvidence: frontEvidence,
        backEvidence: CccdImageEvidence(
          side: CccdImageSide.front,
          normalizedOcrText: 'ĐẶC ĐIỂM NHẬN DẠNG',
          imageByteHash: 'hash_back',
          width: 800,
          height: 600,
          byteLength: 50000,
          filePath: '/synthetic/back.jpg',
        ),
        verifiedData: verifiedData,
      );

      expect(validator.canSave(wrongSideProof), isFalse);
    });

    test('Cho lưu khi proof đủ hai mặt, khác hash và có dữ liệu QR', () {
      const proof = CccdValidationProof(
        isValid: true,
        frontEvidence: frontEvidence,
        backEvidence: backEvidence,
        verifiedData: verifiedData,
      );

      expect(validator.canSave(proof), isTrue);
    });
  });
}
