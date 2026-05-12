import 'package:flutter/material.dart';

enum AuthButtonType {
  primary,
  secondary,
}

class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final AuthButtonType type;

  const AuthButton({
    super.key,
    required this.text,
    required this.onPressed,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPrimary = type == AuthButtonType.primary;

    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:
              isPrimary ? const Color(0xFF1F1F23) : const Color(0xFFEDEDED),
          foregroundColor:
              isPrimary ? Colors.white : const Color(0xFF1F1F23),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}