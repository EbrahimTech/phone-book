import 'package:flutter/material.dart';

class ContactSectionHeader extends StatelessWidget {
  final String letter;

  const ContactSectionHeader({
    super.key,
    required this.letter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

