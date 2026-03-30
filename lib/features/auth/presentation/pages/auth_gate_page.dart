import 'package:finport/features/auth/data/repositories/auth_repository.dart';
import 'package:finport/features/auth/presentation/pages/sign_in_page.dart';
import 'package:finport/features/movements/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  final _authRepo = AuthRepository();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _authRepo.authStateChanges(),
      builder: (context, snapshot) {
        final session = _authRepo.currentSession;
        if (session != null) {
          return const HomePage();
        }
        return const SignInPage();
      },
    );
  }
}
