/// Centralized Firestore schema definition based strictly on Database.docx.
/// 
/// Rule: All collections and field names stored in Firestore MUST match the agreed
/// Database.docx schema. No new collections or ad-hoc fields are allowed.
/// Code uses English variable names; Firestore mapper maps to fixed schema keys.
library;

/// Tên các collection hợp lệ duy nhất trong Firestore theo Database.docx
abstract final class FirestoreCollections {
  static const users = 'users';
  static const properties = 'properties';
  static const rooms = 'rooms';
  static const amenities = 'amenities';
  static const locations = 'locations';
  static const posts = 'posts';
  static const bookings = 'bookings';

  // Nghiệp vụ quản lý vận hành kỳ ở, bàn giao, nhận phòng & vi phạm
  static const periods = 'periods';
  static const kyO = 'periods';
  static const checkins = 'checkins';
  static const residents = 'residents';
  static const handoverItems = 'handover_items';
  static const checkoutRecords = 'checkout_records';
  static const violations = 'violations';
  static const invoiceLines = 'invoice_lines';
  static const violationRecords = 'violation_records';

  // Thông báo & Thanh toán
  static const notifications = 'notifications';
  static const payments = 'payments';

  // Backward compatibility alias: publicRooms & hostRooms
  static const publicRooms = 'rooms';
  static const hostRooms = 'host_rooms';
  static const hostProperties = 'properties';
}

/// Schema các trường cho collection `posts` (Bảng Bài đăng)
abstract final class PostFields {
  /// Khóa chính document bài đăng [PK]
  static const postId = 'postId';

  /// Khóa ngoại liên kết phòng trọ trong `rooms` [FK] - Bắt buộc (String)
  static const roomId = 'roomId';

  /// Khóa ngoại liên kết chủ nhà trong `users` [FK] - Bắt buộc (String)
  static const hostId = 'hostId';

  /// Khóa ngoại liên kết địa điểm trong `locations` [FK] - Bắt buộc (String)
  static const locationId = 'locationId';

  /// Khóa ngoại loại thuê (thang, ngay, ...) [FK] - Bắt buộc (String)
  static const rentalTypeId = 'rentalTypeId';

  /// Khóa ngoại trạng thái bài đăng [FK] - Bắt buộc (String)
  static const statusId = 'statusId';

  /// Tiêu đề bài đăng - Bắt buộc (String)
  static const title = 'title';

  /// Mô tả chi tiết - Bắt buộc (String)
  static const description = 'description';

  /// Giá thuê theo tháng (VNĐ) - Bắt buộc (double/num)
  static const rentalPrice = 'rentalPrice';

  /// Tiền đặt cọc (VNĐ) - Bắt buộc (double/num)
  static const depositAmount = 'depositAmount';

  /// Phần trăm tiền cọc: chỉ cho phép 10, 20, 30, 40, 50 - Bắt buộc (int)
  static const depositPercentage = 'depositPercentage';

  /// Danh sách tiện ích phòng - Tùy chọn (`List<String>`)
  static const amenities = 'amenities';

  /// Danh sách URL ảnh phòng - Tùy chọn (`List<String>`)
  static const images = 'images';

  /// Địa chỉ chi tiết - Bắt buộc (String)
  static const address = 'address';

  /// Số điện thoại liên hệ - Bắt buộc (String)
  static const contactPhone = 'contactPhone';

  /// Thời gian đăng bài - Bắt buộc (Timestamp)
  static const createdAt = 'createdAt';

  /// Trạng thái hiển thị (tùy chọn) (String)
  static const status = 'status';

  // --- Legacy Vietnamese aliases để đọc dữ liệu cũ nếu có ---
  static const legacyPostId = 'baiDangId';
  static const legacyRoomId = 'phongId';
  static const legacyHostId = 'chuNhaId';
  static const legacyLocationId = 'diaDiemId';
  static const legacyRentalTypeId = 'loaiThue_id';
  static const legacyStatusId = 'trangThai_id';
  static const legacyTitle = 'tieuDe';
  static const legacyDescription = 'moTa';
  static const legacyRentalPrice = 'giaThue';
  static const legacyDepositAmount = 'tienCoc';
  static const legacyDepositPercentage = 'phanTramTienCoc';
  static const legacyAmenities = 'tienIch';
  static const legacyImages = 'anhPhong';
  static const legacyAddress = 'diaChi';
  static const legacyContactPhone = 'soDienThoaiLienHe';
  static const legacyCreatedAt = 'ngayDang';
  static const legacyStatus = 'trangThai';

  /// Tập hợp toàn bộ các trường hợp lệ được phép ghi vào document `posts`
  static const allowedWriteFields = {
    postId,
    roomId,
    hostId,
    locationId,
    rentalTypeId,
    statusId,
    title,
    description,
    rentalPrice,
    depositAmount,
    depositPercentage,
    amenities,
    images,
    address,
    contactPhone,
    createdAt,
    status,
  };
}

/// Schema các trường cho collection `rooms` (Bảng Phòng)
abstract final class RoomFields {
  /// Khóa chính document phòng [PK] (String)
  static const roomId = 'roomId';

  /// Khóa ngoại liên kết cơ sở trong `properties` [FK] - Bắt buộc (String)
  static const propertyId = 'propertyId';

  /// Khóa ngoại liên kết chủ nhà trong `users` [FK] - Bắt buộc (String)
  static const hostId = 'hostId';

  /// Số phòng / mã phòng - Bắt buộc (String)
  static const roomCode = 'roomCode';

  /// Tầng của phòng - Bắt buộc (int)
  static const floor = 'floor';

  /// Diện tích (m²) - Bắt buộc (double/num)
  static const area = 'area';

  /// Sức chứa tối đa (người) - Bắt buộc (int)
  static const capacity = 'capacity';

  /// Giá thuê phòng (VNĐ/tháng) - Bắt buộc (double/num)
  static const rentalPrice = 'rentalPrice';

  /// Tiền đặt cọc phòng (VNĐ) - Bắt buộc (double/num)
  static const depositAmount = 'depositAmount';

  /// Khóa ngoại trạng thái phòng [FK] (String)
  static const statusId = 'statusId';

  /// Trạng thái phòng: available, occupied, reserved, deleted (String)
  static const status = 'status';

  /// Danh sách tiện ích của phòng (`List<String>`)
  static const amenities = 'amenities';

  /// Danh sách URL ảnh của phòng (`List<String>`)
  static const images = 'images';

  /// Mô tả phòng (String)
  static const description = 'description';

  /// Tiêu đề phòng (String)
  static const title = 'title';

  /// Địa chỉ phòng (String)
  static const address = 'address';

  /// Thời gian tạo phòng (Timestamp)
  static const createdAt = 'createdAt';

  // Legacy Vietnamese aliases
  static const legacyRoomId = 'phongId';
  static const legacyPropertyId = 'nhaTroId';
  static const legacyHostId = 'chuNhaId';
  static const legacyRoomCode = 'soPhong';
  static const legacyFloor = 'tang';
  static const legacyArea = 'dienTich';
  static const legacyCapacity = 'sucChua';
  static const legacyRentalPrice = 'giaThue';
  static const legacyDepositAmount = 'tienCoc';
  static const legacyStatusId = 'trangThai_id';
  static const legacyStatus = 'trangThai';
  static const legacyAmenities = 'tienIch';
  static const legacyImages = 'anhPhong';
  static const legacyDescription = 'moTa';
  static const legacyTitle = 'tieuDe';
  static const legacyAddress = 'diaChi';
  static const legacyCreatedAt = 'ngayTao';
}

/// Schema các trường cho collection `properties` (Bảng Nhà trọ / Bất động sản)
abstract final class PropertyFields {
  /// Khóa chính document cơ sở [PK] (String)
  static const propertyId = 'propertyId';

  /// Khóa ngoại liên kết chủ nhà trong `users` [FK] - Bắt buộc (String)
  static const hostId = 'hostId';

  /// Khóa ngoại liên kết địa điểm trong `locations` [FK] (String)
  static const locationId = 'locationId';

  /// Tên nhà trọ / cơ sở - Bắt buộc (String)
  static const name = 'name';

  /// Địa chỉ chi tiết - Bắt buộc (String)
  static const address = 'address';

  /// Tỉnh / Thành phố (String)
  static const city = 'city';

  /// Tỉnh / Thành phố (alias province như trong thực tế Firestore)
  static const province = 'province';

  /// Quận / Huyện (String)
  static const district = 'district';

  /// Phường / Xã (String)
  static const ward = 'ward';

  /// Thời gian tạo (Timestamp)
  static const createdAt = 'createdAt';

  /// Trạng thái cơ sở (String)
  static const status = 'status';

  // Legacy aliases
  static const legacyPropertyId = 'nhaTroId';
  static const legacyHostId = 'chuNhaId';
  static const legacyLocationId = 'diaDiemId';
  static const legacyName = 'ten';
  static const legacyAddress = 'diaChi';
  static const legacyCity = 'thanhPho';
  static const legacyDistrict = 'quanHuyen';
  static const legacyWard = 'phuongXa';
  static const legacyCreatedAt = 'ngayTao';
  static const legacyStatus = 'trangThai';
}

/// Schema các trường cho collection `amenities` (Bảng Tiện ích)
abstract final class AmenityFields {
  /// Khóa chính tiện ích [PK] (String)
  static const amenityId = 'amenityId';

  /// Tên tiện ích - Bắt buộc (String)
  static const name = 'name';

  // Legacy aliases
  static const legacyAmenityId = 'tienIchId';
  static const legacyName = 'tenTienIch';
}

/// Schema các trường cho collection `locations` (Bảng Địa điểm)
abstract final class LocationFields {
  /// Khóa chính địa điểm [PK] (String)
  static const locationId = 'locationId';

  /// PlaceId (String)
  static const placeId = 'placeId';

  /// Khóa ngoại liên kết bài đăng (String)
  static const postId = 'postId';

  /// Địa chỉ (String)
  static const address = 'address';

  /// Tỉnh / Thành phố - Bắt buộc (String)
  static const city = 'city';

  /// Tỉnh / Thành phố (province)
  static const province = 'province';

  /// Quận / Huyện (String)
  static const district = 'district';

  /// Phường / Xã (String)
  static const ward = 'ward';

  /// Tọa độ vĩ độ
  static const latitude = 'latitude';

  /// Tọa độ kinh độ
  static const longitude = 'longitude';

  // Legacy aliases
  static const legacyLocationId = 'diaDiemId';
  static const legacyCity = 'thanhPho';
  static const legacyDistrict = 'quanHuyen';
  static const legacyWard = 'phuongXa';
}

/// Schema các trường cho collection `users` (Bảng Người dùng)
abstract final class UserFields {
  /// Khóa chính người dùng [PK] (String)
  static const userId = 'userId';

  /// Họ tên người dùng (String)
  static const displayName = 'displayName';

  /// Email (String)
  static const email = 'email';

  /// Số điện thoại (String)
  static const phoneNumber = 'phoneNumber';

  /// Vai trò người dùng (String)
  static const role = 'role';

  /// Khóa ngoại vai trò [FK] (String)
  static const roleId = 'roleId';

  /// URL ảnh đại diện (String)
  static const avatarUrl = 'avatarUrl';

  // Legacy aliases
  static const legacyUserId = 'nguoiDungId';
  static const legacyDisplayName = 'hoTen';
  static const legacyPhoneNumber = 'soDienThoai';
  static const legacyRole = 'vaiTro';
  static const legacyRoleId = 'vaiTro_id';
  static const legacyAvatarUrl = 'anhDaiDien';
}

/// Schema các trường cho collection `bookings` (Bảng Đơn đặt phòng)
abstract final class BookingFields {
  /// Khóa chính đơn đặt phòng [PK] (String)
  static const bookingId = 'bookingId';

  /// Khóa ngoại phòng [FK] (String)
  static const roomId = 'roomId';

  /// Khóa ngoại chủ nhà [FK] (String)
  static const hostId = 'hostId';

  /// Khóa ngoại người đặt phòng [FK] (String)
  static const userId = 'userId';

  /// Khóa ngoại trạng thái đơn phòng [FK] (String)
  static const statusId = 'statusId';

  /// Tiền đặt cọc (double)
  static const depositAmount = 'depositAmount';

  /// Giá thuê (double)
  static const rentalPrice = 'rentalPrice';

  /// Thời gian tạo đơn (Timestamp)
  static const createdAt = 'createdAt';

  // Legacy aliases
  static const legacyBookingId = 'donId';
  static const legacyRoomId = 'phongId';
  static const legacyHostId = 'chuNhaId';
  static const legacyUserId = 'nguoiDungId';
  static const legacyStatusId = 'trangThai_id';
  static const legacyDepositAmount = 'tienCoc';
  static const legacyRentalPrice = 'giaThue';
  static const legacyCreatedAt = 'ngayTao';
}

/// Schema các trường cho collection `notifications` (Bảng Thông báo)
abstract final class NotificationFields {
  /// Khóa chính document thông báo [PK] (String)
  static const notificationId = 'notificationId';

  /// Khóa ngoại người nhận [FK] (String)
  static const receiverId = 'receiverId';

  /// Khóa ngoại người gửi [FK] (String)
  static const senderId = 'senderId';

  /// Loại thông báo: deposit, pendingAction, paymentCompleted (String)
  static const notificationType = 'notificationType';

  /// Tiêu đề thông báo (String)
  static const title = 'title';

  /// Nội dung thông báo (String)
  static const message = 'message';

  /// Khóa ngoại liên kết đơn đặt phòng [FK] (String)
  static const bookingId = 'bookingId';

  /// Khóa ngoại liên kết thanh toán [FK] (String)
  static const paymentId = 'paymentId';

  /// Khóa ngoại liên kết phòng [FK] (String)
  static const roomId = 'roomId';

  /// Khóa ngoại liên kết cơ sở/nhà trọ [FK] (String)
  static const propertyId = 'propertyId';

  /// Số tiền liên quan (double)
  static const amount = 'amount';

  /// Khóa ngoại trạng thái thông báo [FK] (String)
  static const statusId = 'statusId';

  /// Đã đọc chưa (bool)
  static const isRead = 'isRead';

  /// Thời gian tạo (Timestamp)
  static const createdAt = 'createdAt';

  /// Thời gian cập nhật (Timestamp)
  static const updatedAt = 'updatedAt';

  // Thông tin hỗ trợ hiển thị giao diện & điều chỉnh cọc theo Figma
  static const bookingCode = 'bookingCode';
  static const roomCode = 'roomCode';
  static const roomTitle = 'roomTitle';
  static const renterName = 'renterName';
  static const checkInDate = 'checkInDate';
  static const oldRoomId = 'oldRoomId';
  static const newRoomId = 'newRoomId';
  static const oldCheckInDate = 'oldCheckInDate';
  static const newCheckInDate = 'newCheckInDate';
  static const adjustmentReason = 'adjustmentReason';
  static const paymentMethod = 'paymentMethod';

  // Legacy Vietnamese aliases
  static const legacyNotificationId = 'thongBaoId';
  static const legacyReceiverId = 'nguoiNhanId';
  static const legacySenderId = 'nguoiGuiId';
  static const legacyNotificationType = 'loaiThongBao';
  static const legacyTitle = 'tieuDe';
  static const legacyMessage = 'noiDung';
  static const legacyBookingId = 'donId';
  static const legacyPaymentId = 'thanhToanId';
  static const legacyRoomId = 'phongId';
  static const legacyPropertyId = 'nhaTroId';
  static const legacyAmount = 'soTien';
  static const legacyStatusId = 'trangThai_id';
  static const legacyIsRead = 'daDoc';
  static const legacyCreatedAt = 'ngayTao';
  static const legacyUpdatedAt = 'ngayCapNhat';
}

/// Schema các trường cho collection `payments` (Bảng Thanh toán)
abstract final class PaymentFields {
  static const paymentId = 'paymentId';
  static const bookingId = 'bookingId';
  static const userId = 'userId';
  static const hostId = 'hostId';
  static const roomId = 'roomId';
  static const propertyId = 'propertyId';
  static const amount = 'amount';
  static const paymentMethod = 'paymentMethod';
  static const paymentType = 'paymentType';
  static const status = 'status';
  static const statusId = 'statusId';
  static const transactionCode = 'transactionCode';
  static const createdAt = 'createdAt';
  static const completedAt = 'completedAt';

  // Legacy aliases
  static const legacyPaymentId = 'thanhToanId';
  static const legacyBookingId = 'donId';
  static const legacyUserId = 'nguoiDungId';
  static const legacyAmount = 'soTien';
  static const legacyPaymentMethod = 'phuongThucThanhToan';
  static const legacyStatus = 'trangThai';
  static const legacyCreatedAt = 'ngayTao';
}
