import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed; // Made nullable
  final Color buttonColor;
  final Color textColor;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed, // Nullable to allow disabling
    required this.buttonColor,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed, // Can be null to disable the button
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: textColor,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 16, color: textColor),
      ),
    );
  }
}
