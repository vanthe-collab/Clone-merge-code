// Utility functions for Vietnamese string handling and normalization.

/// Loại bỏ toàn bộ dấu tiếng Việt khỏi chuỗi.
String removeVietnameseDiacritics(String str) {
  const withDiacritics =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
  const withoutDiacritics =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
  var result = str;
  for (int i = 0; i < withDiacritics.length; i++) {
    result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
  }
  return result;
}

/// Chuẩn hóa chuỗi tiếng Việt để so sánh (không phân biệt dấu tiếng Việt, hoa/thường, khoảng trắng).
String normalizeVietnameseComparison(String str) {
  return removeVietnameseDiacritics(str)
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');
}
