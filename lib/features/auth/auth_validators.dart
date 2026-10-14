/// Ràng buộc ô đăng nhập. Tách riêng để kiểm tra không cần mở Firebase.
String? validateLoginEmail(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return 'Vui lòng nhập email';
  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  if (!ok) return 'Email không hợp lệ';
  return null;
}

String? validateLoginPassword(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return 'Vui lòng nhập mật khẩu';
  if (value.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
  return null;
}
