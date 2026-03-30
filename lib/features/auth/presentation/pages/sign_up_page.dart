import 'package:finport/features/auth/data/repositories/auth_repository.dart';
import 'package:finport/features/auth/presentation/pages/auth_success_page.dart';
import 'package:finport/features/auth/presentation/pages/sign_in_page.dart';
import 'package:finport/features/auth/presentation/widgets/auth_layout.dart';
import 'package:finport/features/auth/presentation/widgets/social_signin_buttons.dart';
import 'package:flutter/material.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _authRepo = AuthRepository();
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _loading = true);
    try {
      await _authRepo.signUpWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AuthSuccessPage(
            title: 'Conta criada com sucesso',
            subtitle: 'Agora você já pode entrar e começar a usar o app.',
            buttonText: 'Entrar',
            nextPageBuilder: (_) => const SignInPage(),
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      _snack('Não foi possível criar a conta: $e');
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
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.chevron_left),
      ),
      title: 'Criar conta',
      subtitle: 'Crie sua conta para acessar o Finport.',
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
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD89A37),
                minimumSize: const Size.fromHeight(50),
              ),
              child: Text(_loading ? 'Criando conta...' : 'Cadastrar'),
            ),
            const SizedBox(height: 18),
            const Text(
              'ou',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45),
            ),
            const SizedBox(height: 12),
            SocialSignInButtons(onGoogle: _google, onApple: _apple),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Já tem conta? '),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const SignInPage()),
                    );
                  },
                  child: const Text('Entrar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
