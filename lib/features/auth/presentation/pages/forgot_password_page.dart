import 'package:finport/features/auth/data/repositories/auth_repository.dart';
import 'package:finport/features/auth/presentation/pages/verification_code_page.dart';
import 'package:finport/features/auth/presentation/widgets/auth_layout.dart';
import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _authRepo = AuthRepository();
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _sending = true);
    try {
      await _authRepo.sendPasswordRecoveryCode(email: _emailCtrl.text.trim());
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerificationCodePage(email: _emailCtrl.text.trim()),
        ),
      );
    } catch (e) {
      _snack('Não foi possível enviar o código: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
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
      title: 'Esqueci minha senha',
      subtitle: 'Informe seu e-mail para receber o código de verificação.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
              validator: (v) {
                final email = (v ?? '').trim();
                if (email.isEmpty || !email.contains('@')) {
                  return 'Informe um e-mail válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD89A37),
                minimumSize: const Size.fromHeight(50),
              ),
              child: Text(_sending ? 'Enviando...' : 'Enviar código'),
            ),
          ],
        ),
      ),
    );
  }
}
