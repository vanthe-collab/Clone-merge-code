# Thiết lập và kiểm tra Firebase cho Quản lý nhà/phòng

Dự án đã cấu hình Firebase project `homeshare-fe18e` cho web, Android, iOS.
`main.dart` khởi tạo Firebase trong lần chạy bình thường, sau đó đăng nhập qua Firebase Auth.
Chế độ Windows / `HOST_PREVIEW=true` bỏ qua Firebase; `/host-preview` cũng không thay thế đăng nhập.
Chưa xác nhận dịch vụ, billing và rules đang triển khai trong Firebase Console.

## Các bước trên Firebase Console

1. Mở https://console.firebase.google.com/project/homeshare-fe18e/overview .
2. Authentication → Sign-in method: bật Email/Password nếu chưa bật. Đăng ký bằng lựa chọn **Chủ trọ** trong app. Hồ sơ `users/{uid}` cần `role: "host"`. Không tạo UID giả hoặc sửa collection của người khác.
3. Firestore Database: nếu chưa có database thì tạo Cloud Firestore Standard, Native mode, database `(default)`. Không cần tự tạo collection: app tạo `properties` và `host_rooms` khi chủ trọ lưu. Collection `rooms` hiện có chỉ dành cho dữ liệu công khai của khách thuê. Không chuyển sang rules cho phép mọi người đọc/ghi.
4. Storage: tạo/kiểm tra bucket `homeshare-fe18e.firebasestorage.app`. Cloud Storage hiện yêu cầu gói Blaze; kiểm tra việc liên kết billing trong Console và chi phí trước khi bật. Nguồn: https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024 .
5. Firestore → Rules: ghép `firestore-host.rules.snippet` vào bên trong `match /databases/{database}/documents`. Storage → Rules: ghép `storage-host.rules.snippet` vào bên trong `match /b/{bucket}/o`. Đây là các đoạn bổ sung, **không thay toàn bộ rules hiện có**. Giữ rules users/chat/bookings/rooms; thêm rules riêng cho `host_rooms`. Rules có nhiều allow thì chỉ cần một allow đúng: các allow rộng hoặc recursive wildcard hiện có sẽ làm mất giới hạn trong đoạn bổ sung. Kiểm tra bằng Rules Playground trước khi Publish.
6. Không có thao tác publish rules hoặc thay đổi billing tự động trong lần sửa code này.

## Chạy và thử trên Chrome

```powershell
flutter run -d chrome
```

Không thêm `--dart-define=HOST_PREVIEW=true` để thử lưu Firebase.

- Đăng nhập Chủ trọ → Quản lý → dấu cộng → Tạo cơ sở (Nhà).
- Chọn từ 1–5 ảnh JPG/PNG, mỗi ảnh tối đa 5 MB; điền tên, địa chỉ, quy mô và số tầng. Địa chỉ được chọn theo 3 cấp: Tỉnh/Thành phố → Quận/Huyện → Phường/Xã; mỗi ô sau chỉ hiển thị dữ liệu thuộc ô đang chọn trước đó.
- Giấy tờ tùy chọn chỉ nhận ảnh JPG/PNG tối đa 15 MB; không hỗ trợ PDF trong phiên bản này, không tự đánh dấu đã xác minh.
- Lưu & tạo phòng: chỉ chuyển sang tab phòng sau khi Firebase ghi xong. Chọn cơ sở, nhập mã phòng duy nhất trong cơ sở, giá, cọc, tầng, tiện ích, ảnh (1–8).
- Lưu phòng → trở về Quản lý. Kiểm tra nhà, số phòng và ảnh; tải lại trang để xác nhận dữ liệu còn tồn tại. Thử lại mã phòng cũ: phải báo trùng, không tăng số phòng.
- Đăng nhập chủ trọ khác: không thấy cơ sở/phòng quản lý của tài khoản trước. Người thuê vẫn chỉ đọc phòng công khai trong `rooms`; CRUD quản lý chủ trọ dùng `host_rooms`.

## Cấu trúc và ý nghĩa dữ liệu

Nếu quận/huyện đã chọn không có dữ liệu phường/xã, form cho phép bỏ qua phường/xã và lưu `ward` là chuỗi rỗng. Khu vực có danh sách phường/xã vẫn yêu cầu chọn.

- `properties/{id}`: `hostId`, tên, địa chỉ, `city`, `district`, `ward`, tổng số phòng `plannedRooms`, `floors`, khung giá, URL ảnh, `roomCount`, `verificationStatus: unverified`. Tổng số phòng là giới hạn số phòng thực có thể tạo; giảm giới hạn không được thấp hơn số phòng đã tạo.
- Khung giá và diện tích có ô nhập tối thiểu/tối đa đồng bộ với thanh kéo. Mốc mặc định của thanh kéo là 20 triệu đồng và 100 m²; nhập lớn hơn sẽ mở rộng thanh. Khoảng diện tích được lưu bằng `minArea`/`maxArea`; `area` giữ giá trị tối thiểu để tương thích dữ liệu cũ.
- `rooms/{id}`: dữ liệu phòng công khai của luồng khách thuê; màn quản lý chủ trọ không ghi vào collection này.
- `host_rooms/{id}`: kho phòng riêng của chủ trọ, dùng schema RoomModel và bổ sung `propertyId`, `roomCode`, `status`, `operationId`. ID phòng chuẩn hóa theo mã chữ hoa trong cơ sở để chống trùng.
- Tạo phòng dùng transaction ghi room và tăng `properties.roomCount` cùng lúc. Transaction kiểm tra sở hữu, mã phòng và giới hạn quy mô; thao tác tạo ID cố định giúp thử lại sau lỗi mạng không tạo bản sao.
- `host_media/{uid}/properties/...` và `host_media/{uid}/host_rooms/...`: ảnh thực tải lên bằng `putData`, không dùng dart:io hoặc fallback ảnh mẫu/base64.
- `host_private/{uid}/{propertyId}/proof`: giấy tờ riêng, chỉ lưu Storage path ở cơ sở, không tạo URL tải công khai cho giấy tờ.
- Tổng quan đếm **phòng thực đã tạo** theo cơ sở; `available` là trống, `occupied` là đang thuê, các trạng thái khác tách riêng. Phòng cũ chưa có propertyId không tự ghép theo tên/địa chỉ; màn quản lý thông báo số phòng chưa liên kết.
- `Thu dự kiến` là tổng giá tháng của phòng `occupied`, không phải tiền thanh toán đã thu. Chưa triển khai hợp đồng/người thuê/tiền tệ hoặc tự chuyển trạng thái khi đặt cọc.
- Sửa cơ sở giữ nguyên ID, ảnh cũ và liên kết phòng; không cho giảm quy mô/số tầng thấp hơn dữ liệu phòng hiện có. Xóa cơ sở là xóa mềm và chỉ thực hiện khi không còn phòng. Xóa phòng cũng là xóa mềm trong `host_rooms` để giữ lịch sử. Ảnh tải thành công nhưng lần ghi Firestore thất bại có thể còn trong Storage; không tự xóa tệp khi chưa chắc kết quả transaction.

## Dữ liệu cũ trước khi tách collection

Các phòng chủ trọ đã từng ghi vào `rooms` không được ứng dụng tự động di chuyển, nhằm tránh sao chép nhầm tin công khai hoặc làm hỏng booking đang tham chiếu. Nếu có dữ liệu thật cần giữ, dùng Admin SDK hoặc công cụ migration đáng tin cậy để **sao chép** đúng các tài liệu có `propertyId` và `hostId` sang `host_rooms` với nguyên document ID; kiểm tra xong mới quyết định có gỡ bản công khai cũ hay không.

## Giới hạn xác nhận

Widget tests kiểm tra điều hướng, form, dữ liệu stream và phản hồi lỗi bằng repository thay thế. Phân tích mã và build web kiểm tra khả năng biên dịch. Các kiểm tra đó không thay thế thử nghiệm ghi thật bằng tài khoản trong Firebase Console, kiểm tra Storage, hoặc kiểm tra rules đang triển khai.
