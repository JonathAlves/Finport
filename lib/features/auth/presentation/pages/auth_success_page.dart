import 'package:flutter/material.dart';

class AuthSuccessPage extends StatelessWidget {
  const AuthSuccessPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.nextPageBuilder,
  });

  final String title;
  final String subtitle;
  final String buttonText;
  final WidgetBuilder nextPageBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SuccessIllustration(),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: nextPageBuilder),
                    (route) => false,
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD89A37),
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(buttonText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessIllustration extends StatelessWidget {
  const _SuccessIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFE6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 24,
            bottom: 12,
            child: Icon(Icons.person, size: 54, color: Color(0xFFD89A37)),
          ),
          Positioned(
            top: 18,
            right: 22,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.verified, color: Color(0xFFD89A37)),
            ),
          ),
          const Center(
            child: Icon(Icons.lock_outline, size: 56, color: Color(0xFF6D4C2D)),
          ),
        ],
      ),
    );
  }
}
