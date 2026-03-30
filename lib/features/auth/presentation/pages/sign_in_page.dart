import 'package:finport/features/auth/data/repositories/auth_repository.dart';
import 'package:finport/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:finport/features/auth/presentation/pages/sign_up_page.dart';
import 'package:finport/features/auth/presentation/widgets/auth_layout.dart';
import 'package:finport/features/auth/presentation/widgets/social_signin_buttons.dart';
import 'package:flutter/material.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _authRepo = AuthRepository();
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _loading = true);
    try {
      await _authRepo.signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } catch (e) {
      _snack('Não foi possível entrar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    try {
      await _authRepo.signInWithGoogle();
    } catch (e) {
      _snack('Falha no login com Google: $e');
    }
  }

  Future<void> _apple() async {
    try {
      await _authRepo.signInWithApple();
    } catch (e) {
      _snack('Falha no login com Apple: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Entrar',
      subtitle: 'Bem-vindo de volta! Faça login para continuar.',
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Senha',
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
                if ((v ?? '').trim().isEmpty) {
                  return 'Informe sua senha';
                }
                return null;
              },
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                  );
                },
                child: const Text('Esqueceu a senha?'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD89A37),
                minimumSize: const Size.fromHeight(50),
              ),
              child: Text(_loading ? 'Entrando...' : 'Entrar'),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Não tem conta? '),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignUpPage()),
                    );
                  },
                  child: const Text('Cadastrar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'ou',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45),
            ),
            const SizedBox(height: 12),
            SocialSignInButtons(onGoogle: _google, onApple: _apple),
          ],
        ),
      ),
    );
  }
}
