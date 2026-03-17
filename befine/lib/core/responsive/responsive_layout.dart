import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileShell;
  final Widget webShell;

  const ResponsiveLayout({
    super.key,
    required this.mobileShell,
    required this.webShell,
  });

  @override
  Widget build(BuildContext context) {
    // Determine screen width directly from the media query
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Using 800 threshold to show Web sidebar
    if (screenWidth > 800) {
      return webShell;
    } else {
      return mobileShell;
    }
  }
}
