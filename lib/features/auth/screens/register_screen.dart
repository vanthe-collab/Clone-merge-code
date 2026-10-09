import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/phong_sang_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_form_card.dart';

/// Màn hình Đăng Ký Tài Khoản HomeShare (Hỗ trợ 2 Role: Người thuê & Chủ trọ)
/// Theo chuẩn Moodboard Phòng Sáng (phong_sang_theme.dart)
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Role người dùng: 'renter' (người thuê) hoặc 'host' (chủ trọ)
  String _selectedRole = 'renter';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đồng ý với Điều khoản dịch vụ và Chính sách của HomeShare.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        displayName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        role: _selectedRole,
      );

      // QUAN TRỌNG: Đăng xuất ngay để người dùng trở về màn hình Đăng Nhập
      await authService.signOut();

      if (mounted) {
        final roleName = _selectedRole == 'host' ? 'Chủ trọ' : 'Người thuê';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đăng ký tài khoản $roleName thành công! Vui lòng đăng nhập.'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );

        // Quay trở lại màn hình Đăng nhập và truyền email vừa tạo để điền sẵn
        Navigator.pop(context, _emailController.text.trim());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Đăng ký tài khoản', style: PhongSangText.roomName.copyWith(fontSize: 20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'BẠN THAM GIA VỚI VAI TRÒ NÀO?',
                  style: PhongSangText.label(color: AppColors.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildRoleCard(
                        role: 'renter',
                        title: 'Người Thuê',
                        subtitle: 'Tìm phòng, căn hộ & bạn ở ghép',
                        icon: Icons.person_search_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildRoleCard(
                        role: 'host',
                        title: 'Chủ Trọ',
                        subtitle: 'Đăng tin phòng & tìm khách thuê',
                        icon: Icons.domain_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 2. KHUNG ĐIỀN THÔNG TIN TÀI KHOẢN
                AuthFormCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthTextField(
                        controller: _nameController,
                        label: 'Họ và tên *',
                        hint: 'Ví dụ: Nguyễn Văn An',
                        icon: Icons.person_outline_rounded,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập họ và tên';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email
                      AuthTextField(
                        controller: _emailController,
                        label: 'Email *',
                        hint: 'an.nguyen@example.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập email';
                          }
                          if (!val.contains('@') || !val.contains('.')) {
                            return 'Email không hợp lệ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Số điện thoại
                      AuthTextField(
                        controller: _phoneController,
                        label: 'Số điện thoại *',
                        hint: '0901234567',
                        icon: Icons.phone_iphone_rounded,
                        keyboardType: TextInputType.phone,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập số điện thoại';
                          }
                          final phoneRegex = RegExp(r'^0\d{9}$');
                          if (!phoneRegex.hasMatch(val.trim())) {
                            return 'Số điện thoại phải gồm 10 chữ số (bắt đầu bằng 0)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Mật khẩu
                      AuthTextField(
                        controller: _passwordController,
                        label: 'Mật khẩu *',
                        hint: 'Tối thiểu 6 ký tự',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập mật khẩu';
                          }
                          if (val.length < 6) {
                            return 'Mật khẩu tối thiểu 6 ký tự';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Xác nhận mật khẩu
                      AuthTextField(
                        controller: _confirmPasswordController,
                        label: 'Xác nhận mật khẩu *',
                        hint: 'Nhập lại mật khẩu vừa tạo',
                        icon: Icons.verified_user_outlined,
                        obscureText: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        validator: (val) {
                          if (val != _passwordController.text) {
                            return 'Mật khẩu xác nhận không khớp';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      InkWell(
                        onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: Checkbox(
                                value: _agreeToTerms,
                                activeColor: AppColors.primary,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) => setState(() => _agreeToTerms = val ?? false),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tôi đồng ý với Điều khoản dịch vụ và Chính sách quyền riêng tư của HomeShare.',
                                style: PhongSangText.body.copyWith(fontSize: 15, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. NÚT ĐĂNG KÝ
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Đăng ký tài khoản (${_selectedRole == 'host' ? 'Chủ trọ' : 'Người thuê'})',
                            style: PhongSangText.button.copyWith(fontSize: 17),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // 4. QUAY VỀ ĐĂNG NHẬP
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Đã có tài khoản? ', style: PhongSangText.body.copyWith(fontSize: 16)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'Đăng nhập ngay',
                        style: PhongSangText.label(color: PhongSangColors.accent, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Thẻ lựa chọn Role trực quan (Người thuê / Chủ trọ)
  Widget _buildRoleCard({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;

    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.3) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.priceSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: isSelected ? Colors.white : AppColors.textDark,
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13.5,
                color: isSelected ? AppColors.textDark : AppColors.textMuted,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

}
