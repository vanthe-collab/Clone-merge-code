import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/auth/services/role_resolver.dart';

void main() {
  group('1. Role Normalization (RoleResolver.normalizeRole)', () {
    test(
      'Chuẩn hóa đúng các alias của Renter: renter, tenant, nguoiDung, 1',
      () {
        expect(
          RoleResolver.normalizeRole('renter'),
          equals(RoleResolver.renter),
        );
        expect(
          RoleResolver.normalizeRole('Renter'),
          equals(RoleResolver.renter),
        );
        expect(
          RoleResolver.normalizeRole('RENTER'),
          equals(RoleResolver.renter),
        );
        expect(
          RoleResolver.normalizeRole(' tenant '),
          equals(RoleResolver.renter),
        );
        expect(
          RoleResolver.normalizeRole('Tenant'),
          equals(RoleResolver.renter),
        );
        expect(
          RoleResolver.normalizeRole('nguoiDung'),
          equals(RoleResolver.renter),
        );
        expect(
          RoleResolver.normalizeRole('nguoi_dung'),
          equals(RoleResolver.renter),
        );
        expect(
          RoleResolver.normalizeRole('NGUOIDUNG'),
          equals(RoleResolver.renter),
        );
        expect(RoleResolver.normalizeRole('1'), equals(RoleResolver.renter));
        expect(RoleResolver.normalizeRole(1), equals(RoleResolver.renter));
      },
    );

    test('Chuẩn hóa đúng các alias của Host: host, landlord, chutro, 2', () {
      expect(RoleResolver.normalizeRole('host'), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole('Host'), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole('HOST'), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole('landlord'), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole('LandLord'), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole('chutro'), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole('chu_tro'), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole(' ChuTro '), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole('2'), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole(2), equals(RoleResolver.host));
    });

    test(
      'Chuẩn hóa đúng các alias của Admin: admin, administrator, quantri, 3',
      () {
        expect(RoleResolver.normalizeRole('admin'), equals(RoleResolver.admin));
        expect(RoleResolver.normalizeRole('Admin'), equals(RoleResolver.admin));
        expect(RoleResolver.normalizeRole('ADMIN'), equals(RoleResolver.admin));
        expect(
          RoleResolver.normalizeRole('administrator'),
          equals(RoleResolver.admin),
        );
        expect(
          RoleResolver.normalizeRole('Administrator'),
          equals(RoleResolver.admin),
        );
        expect(
          RoleResolver.normalizeRole('quantri'),
          equals(RoleResolver.admin),
        );
        expect(
          RoleResolver.normalizeRole('quan_tri'),
          equals(RoleResolver.admin),
        );
        expect(RoleResolver.normalizeRole('3'), equals(RoleResolver.admin));
        expect(RoleResolver.normalizeRole(3), equals(RoleResolver.admin));
      },
    );

    test(
      'Tuyệt đối không ép host/admin hoặc role sai thành renter (Fail-closed)',
      () {
        expect(
          RoleResolver.normalizeRole('host'),
          isNot(equals(RoleResolver.renter)),
        );
        expect(
          RoleResolver.normalizeRole('admin'),
          isNot(equals(RoleResolver.renter)),
        );
        expect(
          RoleResolver.normalizeRole('chutro'),
          isNot(equals(RoleResolver.renter)),
        );
        expect(
          RoleResolver.normalizeRole('landlord'),
          isNot(equals(RoleResolver.renter)),
        );
        expect(RoleResolver.normalizeRole('unknown_role'), isNull);
        expect(RoleResolver.normalizeRole('guest'), isNull);
        expect(RoleResolver.normalizeRole('hacker'), isNull);
        expect(RoleResolver.normalizeRole(''), isNull);
        expect(RoleResolver.normalizeRole('   '), isNull);
        expect(RoleResolver.normalizeRole(null), isNull);
        expect(RoleResolver.normalizeRole(999), isNull);
      },
    );
  });

  group('2. Firestore Map Extraction (RoleResolver.extractRoleFromMap)', () {
    test('Đọc thành công từ khóa `role`', () {
      expect(
        RoleResolver.extractRoleFromMap({'role': 'renter'}),
        equals(RoleResolver.renter),
      );
      expect(
        RoleResolver.extractRoleFromMap({'role': 'host'}),
        equals(RoleResolver.host),
      );
      expect(
        RoleResolver.extractRoleFromMap({'role': 'admin'}),
        equals(RoleResolver.admin),
      );
    });

    test('Đọc thành công từ khóa tiếng Việt `vaiTro`', () {
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro': 'tenant'}),
        equals(RoleResolver.renter),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro': 'chutro'}),
        equals(RoleResolver.host),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro': 'admin'}),
        equals(RoleResolver.admin),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro': 'nguoiDung'}),
        equals(RoleResolver.renter),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro': 'landlord'}),
        equals(RoleResolver.host),
      );
    });

    test('Đọc thành công từ khóa định danh số hoặc chuỗi `vaiTro_id`', () {
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro_id': 1}),
        equals(RoleResolver.renter),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro_id': '1'}),
        equals(RoleResolver.renter),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro_id': 2}),
        equals(RoleResolver.host),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro_id': '2'}),
        equals(RoleResolver.host),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro_id': 3}),
        equals(RoleResolver.admin),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro_id': 'host'}),
        equals(RoleResolver.host),
      );
    });

    test('Tuân thủ thứ tự ưu tiên: role > vaiTro > vaiTro_id', () {
      // role có giá trị -> dùng role
      final mapWithAll = {'role': 'host', 'vaiTro': 'renter', 'vaiTro_id': 1};
      expect(
        RoleResolver.extractRoleFromMap(mapWithAll),
        equals(RoleResolver.host),
      );

      // role rỗng -> kiểm tra vaiTro
      final mapEmptyRole = {'role': '', 'vaiTro': 'admin', 'vaiTro_id': 2};
      expect(
        RoleResolver.extractRoleFromMap(mapEmptyRole),
        equals(RoleResolver.admin),
      );

      // role & vaiTro rỗng -> kiểm tra vaiTro_id
      final mapOnlyId = {'role': null, 'vaiTro': '', 'vaiTro_id': 2};
      expect(
        RoleResolver.extractRoleFromMap(mapOnlyId),
        equals(RoleResolver.host),
      );
    });

    test(
      'Dữ liệu không hợp lệ hoặc thiếu khóa phải trả về null (Không fallback về renter)',
      () {
        expect(RoleResolver.extractRoleFromMap({}), isNull);
        expect(RoleResolver.extractRoleFromMap(null), isNull);
        expect(RoleResolver.extractRoleFromMap({'hoTen': 'Test'}), isNull);
        expect(RoleResolver.extractRoleFromMap({'role': 'invalid'}), isNull);
        expect(
          RoleResolver.extractRoleFromMap({'vaiTro': 'unsupported'}),
          isNull,
        );
        expect(RoleResolver.extractRoleFromMap({'vaiTro_id': 999}), isNull);
      },
    );
  });

  group('3. Pure Auth Destination Resolution (resolveAuthDestination)', () {
    final validRenterProfile = UserProfile(
      uid: 'u_renter',
      email: 'renter@test.vn',
      displayName: 'Nguyễn Renter',
      phoneNumber: '0901111111',
      role: 'renter',
    );

    final validHostProfile = UserProfile(
      uid: 'u_host',
      email: 'host@test.vn',
      displayName: 'Trần Host',
      phoneNumber: '0902222222',
      role: 'host',
    );

    final validAdminProfile = UserProfile(
      uid: 'u_admin',
      email: 'admin@test.vn',
      displayName: 'Lê Admin',
      phoneNumber: '0903333333',
      role: 'admin',
    );

    test('Chưa xác thực -> điều hướng unauthenticated', () {
      final dest = resolveAuthDestination(isAuthenticated: false, role: null);
      expect(dest, equals(AuthDestination.unauthenticated));
    });

    test('Đang tải profile -> điều hướng loading', () {
      final dest = resolveAuthDestination(
        isAuthenticated: true,
        isProfileLoading: true,
        role: null,
      );
      expect(dest, equals(AuthDestination.loading));
    });

    test('Gặp lỗi tải profile -> điều hướng error', () {
      final dest = resolveAuthDestination(
        isAuthenticated: true,
        error: 'Firestore connection failure',
        role: null,
      );
      expect(dest, equals(AuthDestination.error));
    });

    test('Đã đăng nhập và role renter -> điều hướng renter', () {
      final dest = resolveAuthDestination(
        isAuthenticated: true,
        role: validRenterProfile.role,
      );
      expect(dest, equals(AuthDestination.renter));
    });

    test('Đã đăng nhập và role host -> điều hướng host (Không ép renter)', () {
      final dest = resolveAuthDestination(
        isAuthenticated: true,
        role: validHostProfile.role,
      );
      expect(dest, equals(AuthDestination.host));
    });

    test(
      'Đã đăng nhập và role admin -> điều hướng admin (Không ép renter)',
      () {
        final dest = resolveAuthDestination(
          isAuthenticated: true,
          role: validAdminProfile.role,
        );
        expect(dest, equals(AuthDestination.admin));
      },
    );

    test(
      'Role không hợp lệ hoặc null -> điều hướng invalidRole (Fail-closed)',
      () {
        final nullRoleDest = resolveAuthDestination(
          isAuthenticated: true,
          role: null,
        );
        expect(nullRoleDest, equals(AuthDestination.invalidRole));

        final invalidProfile = UserProfile(
          uid: 'u_invalid',
          email: 'invalid@test.vn',
          displayName: 'Invalid User',
          phoneNumber: '0904444444',
          role: 'invalid_role',
        );
        final invalidDest = resolveAuthDestination(
          isAuthenticated: true,
          role: invalidProfile.role,
        );
        expect(invalidDest, equals(AuthDestination.invalidRole));

        final emptyRoleProfile = UserProfile(
          uid: 'u_empty',
          email: 'empty@test.vn',
          displayName: 'Empty Role',
          phoneNumber: '0905555555',
          role: '',
        );
        final emptyDest = resolveAuthDestination(
          isAuthenticated: true,
          role: emptyRoleProfile.role,
        );
        expect(emptyDest, equals(AuthDestination.invalidRole));
      },
    );
  });

  group('4. UserProfile.fromMap trên main luôn là người thuê', () {
    test('fromMap giữ role renter dù Firestore ghi host, admin hoặc role lạ', () {
      final cases = [
        {'vaiTro': 'chutro'},
        {'role': 'admin'},
        {'vaiTro': 'tenant'},
        <String, String>{},
        {'role': 'super_admin_hacker'},
      ];

      for (final data in cases) {
        final profile = UserProfile.fromMap({
          'hoTen': 'Người dùng',
          'email': 'user@test.vn',
          'soDienThoai': '0900000000',
          ...data,
        }, 'uid_${data.hashCode}');
        expect(profile.role, equals('renter'));
        expect(profile.isRenter, isTrue);
        expect(profile.isHost, isFalse);
        expect(profile.isAdmin, isFalse);
        expect(profile.hasValidRole, isTrue);
      }
    });

    test('Getter role phản ánh đúng giá trị được truyền vào constructor', () {
      final host = UserProfile(
        uid: 'u_host',
        email: 'host@test.vn',
        displayName: 'Host',
        phoneNumber: '0902222222',
        role: 'host',
      );
      final admin = UserProfile(
        uid: 'u_admin',
        email: 'admin@test.vn',
        displayName: 'Admin',
        phoneNumber: '0903333333',
        role: 'admin',
      );
      final invalid = UserProfile(
        uid: 'u_invalid',
        email: 'invalid@test.vn',
        displayName: 'Invalid',
        phoneNumber: '0904444444',
        role: 'hacker_role',
      );

      expect(host.isHost, isTrue);
      expect(host.isAdmin, isFalse);
      expect(host.hasValidRole, isTrue);
      expect(admin.isAdmin, isTrue);
      expect(admin.hasValidRole, isTrue);
      expect(invalid.hasValidRole, isFalse);
      expect(invalid.isRenter, isFalse);
    });
  });

  group('5. toMap của main không ghi vaiTro_id', () {
    test('toMap ghi role và vaiTro, không sinh vaiTro_id', () {
      final profile = UserProfile(
        uid: 'u_renter_map',
        email: 'renter@test.vn',
        displayName: 'Nguyễn Renter',
        phoneNumber: '0901111111',
        role: 'renter',
      );

      final map = profile.toMap();
      expect(map['role'], equals('renter'));
      expect(map['vaiTro'], equals('renter'));
      expect(map.containsKey('vaiTro_id'), isFalse);
    });

    test('fromMap sau toMap vẫn là người thuê', () {
      final host = UserProfile(
        uid: 'u_rt_host',
        email: 'host@test.vn',
        displayName: 'Host RT',
        phoneNumber: '0908888888',
        role: 'host',
      );

      final reconstructed = UserProfile.fromMap(host.toMap(), 'u_rt_host');
      expect(reconstructed.role, equals('renter'));
      expect(reconstructed.isRenter, isTrue);
      expect(reconstructed.isHost, isFalse);
      expect(reconstructed.isAdmin, isFalse);
    });
  });
}
