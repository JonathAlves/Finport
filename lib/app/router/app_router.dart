import 'package:finport/core/config/supabase_config.dart';
import 'package:finport/features/auth/presentation/pages/auth_gate_page.dart';
import 'package:flutter/material.dart';

class AppRouter {
  static Widget initialPage() {
    if (SupabaseConfig.isConfigured) {
      return const AuthGatePage();
    }
    return const _MissingSupabaseConfigPage();
  }
}

class _MissingSupabaseConfigPage extends StatelessWidget {
  const _MissingSupabaseConfigPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finport')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Configure o Supabase para usar o Finport.\n\n'
          'Rode o app com:\n'
          'flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...\n',
        ),
      ),
    );
  }
}
