import 'package:flutter/material.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth > maxWidth) {
      return Center(
        child: Container(
          width: maxWidth,
          padding: padding,
          child: child,
        ),
      );
    }
    
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );
  }
}

