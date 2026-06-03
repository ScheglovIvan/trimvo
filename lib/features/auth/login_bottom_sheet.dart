import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/providers/auth_provider.dart';

Future<bool> showLoginBottomSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LoginSheet(),
  );
  return result ?? false;
}

class _LoginSheet extends ConsumerStatefulWidget {
  const _LoginSheet();

  @override
  ConsumerState<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends ConsumerState<_LoginSheet> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notifier = ref.read(authProvider.notifier);
      if (_isRegister) {
        await notifier.register(_emailCtrl.text.trim(), _passwordCtrl.text);
      } else {
        await notifier.login(_emailCtrl.text.trim(), _passwordCtrl.text);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 24),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Sign in to continue',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _field(controller: _emailCtrl, hint: 'Email', keyboard: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _field(controller: _passwordCtrl, hint: 'Password', obscure: true),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _loading ? null : _submit,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.accentPurpleLight,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Text(
                      _isRegister ? 'Register' : 'Sign In',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => setState(() => _isRegister = !_isRegister),
            child: Text(
              _isRegister
                  ? 'Already have an account? Sign In'
                  : "Don't have account? Register",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.accentPurpleLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 15, color: AppColors.textHint),
        filled: true,
        fillColor: const Color(0xFF1A1A28),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
