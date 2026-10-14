# Quản lý phòng chủ trọ

Luồng: Quản lý nhà → Quản lý phòng → Chi tiết → Chỉnh sửa.

- Mỗi thẻ cơ sở có menu ba chấm để sửa hoặc xóa. Form sửa dùng lại form tạo cơ sở, giữ ảnh hiện có và không làm đổi ID/liên kết phòng. Chỉ xóa mềm cơ sở không còn phòng.
- Danh sách và chi tiết đọc stream `properties`/`host_rooms` của UID đang đăng nhập. Collection `rooms` công khai của khách thuê không bị ghi bởi module này.
- Form sửa cập nhật mã phòng, tầng, diện tích, sức chứa, giá/cọc, phí, tiện ích, mô tả và ảnh. ID phòng không đổi; trạng thái, khách thuê và hợp đồng không bị form ghi đè.
- Các phí mới: `electricityRate`, `waterRate`, `serviceFee`. Phòng cũ thiếu phí hiển thị “Chưa thiết lập”.
- Thông tin khách thuê dùng các trường `tenantName`, `tenantPhone`, `contractId`, `contractStart`, `contractEnd`; chưa có dữ liệu thì hiển thị trống. Luồng gán khách/hợp đồng cần được module hợp đồng của nhóm cập nhật, không tự suy ra từ đơn đặt phòng.
- `properties.roomCodes` giữ mã phòng duy nhất. Tài liệu phòng trong `host_rooms` dùng ID có mã thao tác.
- Lưu kiểm tra `updatedAt` để tránh ghi đè bản sửa từ thiết bị khác.
- Xóa sau xác nhận đánh dấu `status: deleted`, giảm `roomCount`, bỏ mã phòng khỏi `roomCodes`. Bản ghi và ảnh cũ giữ lại cho lịch sử. Không cho xóa phòng đang thuê, giữ chỗ hoặc còn khách/hợp đồng.

Các file Rules trong repository đã được tách quyền cho `host_rooms`, nhưng vẫn là bản nháp/snippet và chưa tự động publish lên Firebase. Phải đối chiếu với Rules đang chạy trước khi ghép và triển khai.

Kiểm thử giao diện dùng repository giả, không chứng minh quyền truy cập trên Firebase thật. Việc tải ảnh và ghi dữ liệu thật phụ thuộc tài khoản đăng nhập và Rules Firestore/Storage của dự án.
