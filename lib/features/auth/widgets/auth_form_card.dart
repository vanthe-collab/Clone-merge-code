import 'package:flutter/material.dart';
import '../../../core/theme/phong_sang_theme.dart';

/// Card trắng bọc cụm ô nhập trên màn đăng nhập và đăng ký.
class AuthFormCard extends StatelessWidget {
  final Widget child;

  const AuthFormCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: PhongSangColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhongSangColors.line),
        boxShadow: [
          BoxShadow(
            color: PhongSangColors.ink.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Ô nhập cao, nền xám nhạt, dễ chạm trên điện thoại.
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: PhongSangColors.line),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PhongSangText.label(color: PhongSangColors.ink, fontSize: 15)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: PhongSangText.search.copyWith(fontSize: 17, fontWeight: FontWeight.w500),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: PhongSangText.search.copyWith(fontSize: 16, color: PhongSangColors.muted),
            prefixIcon: Icon(icon, size: 22, color: PhongSangColors.muted),
            prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 56),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: PhongSangColors.priceSoft,
            isDense: false,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: const BorderSide(color: PhongSangColors.accent, width: 1.6),
            ),
            errorBorder: border.copyWith(
              borderSide: const BorderSide(color: Color(0xFFD92D20)),
            ),
            focusedErrorBorder: border.copyWith(
              borderSide: const BorderSide(color: Color(0xFFD92D20), width: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}
