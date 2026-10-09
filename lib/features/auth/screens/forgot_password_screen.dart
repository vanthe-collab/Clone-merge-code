import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/phong_sang_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_form_card.dart';

/// Gửi link đổi mật khẩu của Firebase tới Gmail của tài khoản.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isLoading = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(_emailController.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _emailController.text.trim();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Đặt lại mật khẩu', style: PhongSangText.roomName.copyWith(fontSize: 20)),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _sent ? 'Kiểm tra Gmail' : 'Nhập email tài khoản cần đổi mật khẩu',
                  style: PhongSangText.screenTitle.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  _sent
                      ? 'Firebase đã gửi link đổi mật khẩu tới $email. Mở thư, bấm link, đặt mật khẩu mới. Sau đó quay lại app và đăng nhập bằng mật khẩu vừa đổi.'
                      : 'Firebase sẽ gửi một link đổi mật khẩu vào Gmail này. Mật khẩu mới có hiệu lực ngay khi bạn đăng nhập lại.',
                  style: PhongSangText.body.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 22),
                if (!_sent)
                  AuthFormCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'vidu@gmail.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) {
                            final text = val?.trim() ?? '';
                            if (text.isEmpty) return 'Vui lòng nhập email';
                            if (!text.contains('@') || !text.contains('.')) return 'Email không hợp lệ';
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendResetLink,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PhongSangColors.accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : Text('Gửi link đổi mật khẩu', style: PhongSangText.button.copyWith(fontSize: 17)),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  AuthFormCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.mark_email_read_outlined, size: 42, color: PhongSangColors.accent),
                        const SizedBox(height: 12),
                        Text(
                          'Nếu không thấy thư, hãy xem mục Spam. Link chỉ dùng cho đúng email đã đăng ký.',
                          style: PhongSangText.body.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PhongSangColors.accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Về đăng nhập', style: PhongSangText.button.copyWith(fontSize: 17)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
