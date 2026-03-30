import 'package:flutter/material.dart';

class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({
    super.key,
    required this.onGoogle,
    required this.onApple,
  });

  final VoidCallback onGoogle;
  final VoidCallback onApple;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: onGoogle,
          icon: const Text('G', style: TextStyle(fontWeight: FontWeight.w700)),
          label: const Text('Entrar com Google'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: const BorderSide(color: Color(0xFFE8E8E8)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onApple,
          icon: const Icon(Icons.apple),
          label: const Text('Entrar com Apple'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: const BorderSide(color: Color(0xFFE8E8E8)),
          ),
        ),
      ],
    );
  }
}
