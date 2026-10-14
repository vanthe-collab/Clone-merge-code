# Rules dùng chung cho nhóm HomeShare — bản để kiểm tra

Admin chưa được triển khai. Bản `firestore-team.draft.rules` bao phủ các collection đang có ở dự án này: users, properties, rooms, host_rooms, bookings, roommate_posts, chats/messages, reports. Chưa được Publish lên Firebase, chưa được chạy Firebase Rules Emulator trên máy này. Chỉ kiểm thử Flutter không xác nhận Rules đúng.

## Ai được làm gì?

| Dữ liệu | Người thuê | Chủ trọ | Admin |
|---|---|---|---|
| Hồ sơ riêng / CCCD | Hồ sơ của mình | Hồ sơ của mình | Đọc và quản lý |
| Nhà / giấy tờ cơ sở | Không đọc hồ sơ quản lý | Nhà của mình | Quản lý |
| Phòng đăng cho thuê | Đọc | Đọc, tạo và sửa phòng của mình | Quản lý |
| Đơn đặt phòng | Tạo và xem đơn của mình, hủy, xác nhận demo | Xem và xử lý đơn gửi cho mình | Quản lý |
| Tin ở ghép | Đọc, đăng, sửa/xóa tin của mình | Đọc | Quản lý |
| Chat | Chat mình tham gia | Chat mình tham gia | Quản lý |
| Báo cáo | Gửi, xem báo cáo của mình | Gửi, xem báo cáo của mình | Xử lý |

## Bây giờ làm từng bước

1. Mở Firestore Database → Rules trong project homeshare-fe18e.
2. Lưu bản Rules đang có ra một tệp riêng để cả nhóm biết trạng thái trước đó. Bản có ngày hết hạn 07/10/2026 đã hết hiệu lực.
3. Mở `firestore-team.draft.rules` trong dự án, copy toàn bộ nội dung vào ô Rules. Việc dán chưa làm thay đổi dữ liệu; **chưa bấm Publish**.
4. Trong Rules Playground, chạy các tình huống bên dưới. Nếu Console không cho chạy bản nháp, dùng Firebase Emulator trên máy có Java phù hợp; không dùng tài khoản thử để sửa dữ liệu thật của người khác.
5. Chỉ Publish khi Rules biên dịch và các kiểm tra quyền đạt. Thành viên khác cần cập nhật bản app có truy vấn bookings theo renterId trước khi dùng bộ Rules này.
6. Sau Publish: tải lại app, đăng nhập bằng Chủ trọ hoặc Người thuê; thử hồ sơ, bảng tin, chat, tạo nhà/phòng và đơn thuê bằng tài khoản của nhóm.

## Các tình huống cần kiểm tra trước khi Publish

Dùng UID trong Authentication → Users, không dùng email thay UID. Những tài liệu mẫu phải có đầy đủ trường mà Rules yêu cầu.

- Chưa đăng nhập: đọc `/users/UID` phải bị từ chối.
- Người thuê đăng nhập: đọc `/users/UID_CUA_MINH` được phép; đọc hồ sơ riêng của UID khác bị từ chối.
- Người thuê: sửa `users/UID_CUA_MINH.role` thành `admin` hoặc `host` bị từ chối. Cập nhật tên không đổi vai trò được phép.
- Chủ trọ: tạo `properties`/`host_rooms` với hostId của mình được phép khi dữ liệu hợp lệ; hostId của tài khoản khác bị từ chối.
- Người thuê: không được đọc/ghi `host_rooms`; chỉ đọc `rooms` công khai.
- Đơn thuê: đọc bằng renterId hoặc hostId của người đang đăng nhập được phép; tài khoản thứ ba bị từ chối. Truy vấn phải lọc renterId hoặc hostId ở Firestore.
- Chat: batch tạo hội thoại và tin nhắn đầu tiên được phép cho người gửi; người thứ ba đọc/sửa tin nhắn bị từ chối. Kiểm tra batch bằng Emulator hoặc app thử vì Playground từng thao tác không thay thế test getAfter.
- Admin: dùng hồ sơ Admin do Firebase Console/trusted backend cấp; quản lý các collection trong bảng được phép.

## Admin cấp thế nào khi nhóm bắt đầu làm?

Chưa cần tạo Admin để Chủ trọ và Người thuê chạy được.
Khi làm phần Admin, người quản lý Firebase tạo/chỉnh `users/{UID_ADMIN}` từ **Firebase Console hoặc backend tin cậy** với `role: "admin"`, `vaiTro: "admin"`. Không thêm lựa chọn Admin vào form đăng ký. Bộ Rules khóa các trường vai trò của người dùng thường.
Ứng dụng hiện chưa có màn Admin và AuthGate chưa điều hướng Admin; cấp quyền dữ liệu không tự tạo giao diện Admin.

## Những điểm đã chỉnh trong app để phù hợp

- BookingService truy vấn `.where('renterId', isEqualTo: renterId)` thay vì tải mọi đơn rồi lọc trên máy. Đơn cũ chỉ có tên trường tiếng Việt mà chưa có renterId cần chuẩn hóa bởi Admin trước khi áp dụng.
- Dashboard Người thuê không tự ghi phòng mẫu hoặc xóa bài ở ghép mẫu khi mở bảng tin. Việc đó nên là thao tác chủ động của người quản lý, không phải quyền của người thuê.
- Chat đã lọc danh sách hội thoại bằng `users arrayContains UID`, tin nhắn đọc theo hội thoại cụ thể.
- Những collection mới ở dự án khác sẽ bị chặn mặc định cho đến khi nhóm bổ sung quyền phù hợp, kể cả Admin. Admin không có quyền vô điều kiện cho mọi collection chưa xác định.

## Giới hạn của bản đồ án hiện tại

- Quyền Admin dựa trên users.role được bảo vệ bởi Rules. Nếu dùng custom claims ở backend sau này, cần đổi admin() theo cách cả nhóm thống nhất. Kiểm tra các tài khoản có role admin hiện có trước khi áp dụng bộ mới.
- Nút xác nhận thanh toán hiện cho client gửi status paid. Bản Rules giữ luồng DEMO cho đơn pending_payment của chính người thuê; điều đó không xác nhận giao dịch ngân hàng. Trước khi dùng thanh toán thật, chỉ backend tin cậy được xác nhận paid.
- Xác thực CCCD và badge isVerified hiện là mô phỏng phía app; không dùng chúng làm điều kiện cấp quyền Admin/Chủ trọ.
- Storage Rules là cấu hình khác, không bị thay đổi bởi tệp Firestore này. Phần upload nhà/phòng dùng các path đã chuẩn bị ở storage-host.rules.snippet. Path ảnh ở ghép cũ cần kiểm tra riêng trước khi nhóm đổi toàn bộ Storage Rules.
- Không có CLI deploy, Publish, sửa role hay sửa dữ liệu thật trên Firebase trong lần chuẩn bị này.

Nguồn:
- Rules không tự lọc kết quả truy vấn: https://firebase.google.com/docs/firestore/security/rules-query
- Kiểm thử Rules: https://firebase.google.com/docs/rules/unit-tests
- Quyền theo vai trò: https://firebase.google.com/docs/firestore/solutions/role-based-access
