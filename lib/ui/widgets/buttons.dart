import 'package:flutter/material.dart';

/// Shared primary action button used across screens.
class PrimaryButton extends StatelessWidget {
  /// Creates a filled primary button.
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(onPressed: onPressed, child: Text(label));
  }
}
