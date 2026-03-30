import 'package:finport/features/auth/data/repositories/auth_repository.dart';
import 'package:finport/features/auth/presentation/pages/reset_password_page.dart';
import 'package:finport/features/auth/presentation/widgets/auth_layout.dart';
import 'package:finport/features/auth/presentation/widgets/otp_code_input.dart';
import 'package:flutter/material.dart';

class VerificationCodePage extends StatefulWidget {
  const VerificationCodePage({
    super.key,
    required this.email,
  });

  final String email;

  @override
  State<VerificationCodePage> createState() => _VerificationCodePageState();
}

class _VerificationCodePageState extends State<VerificationCodePage> {
  final _authRepo = AuthRepository();
  bool _loading = false;
  String _code = '';

  Future<void> _verify() async {
    if (_code.length != 4) {
      _snack('Digite o código de 4 dígitos.');
      return;
    }

    setState(() => _loading = true);
    try {
      await _authRepo.verifyRecoveryCode(email: widget.email, code: _code);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ResetPasswordPage()),
      );
    } catch (e) {
      _snack('Código inválido ou expirado: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await _authRepo.sendPasswordRecoveryCode(email: widget.email);
      _snack('Código reenviado para ${widget.email}.');
    } catch (e) {
      _snack('Não foi possível reenviar: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.chevron_left),
      ),
      title: 'Verificação',
      subtitle: 'Digite o código enviado para ${widget.email}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OtpCodeInput(
            length: 4,
            onChanged: (value) => _code = value,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _resend,
            child: const Text('Não recebeu? Reenviar código'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _verify,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD89A37),
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text(_loading ? 'Verificando...' : 'Verificar'),
          ),
        ],
      ),
    );
  }
}
