import 'package:finport/features/auth/data/repositories/auth_repository.dart';
import 'package:finport/features/auth/presentation/pages/auth_success_page.dart';
import 'package:finport/features/auth/presentation/pages/sign_in_page.dart';
import 'package:finport/features/auth/presentation/widgets/auth_layout.dart';
import 'package:flutter/material.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _authRepo = AuthRepository();
  final _formKey = GlobalKey<FormState>();

  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _saving = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await _authRepo.updatePassword(newPassword: _passwordCtrl.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AuthSuccessPage(
            title: 'Sua senha foi alterada com sucesso',
            subtitle: 'Agora faça login com sua nova senha.',
            buttonText: 'Entrar',
            nextPageBuilder: (_) => const SignInPage(),
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      _snack('Não foi possível redefinir a senha: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
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
      title: 'Redefinir senha',
      subtitle: 'Digite sua nova senha e confirme para continuar.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Nova senha',
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: (v) {
                if ((v ?? '').trim().length < 6) {
                  return 'A senha precisa ter pelo menos 6 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirmar senha',
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscureConfirm = !_obscureConfirm);
                  },
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: (v) {
                if (v != _passwordCtrl.text) {
                  return 'As senhas não conferem';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD89A37),
                minimumSize: const Size.fromHeight(50),
              ),
              child: Text(_saving ? 'Salvando...' : 'Redefinir senha'),
            ),
          ],
        ),
      ),
    );
  }
}
