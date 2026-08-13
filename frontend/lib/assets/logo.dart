import 'package:flutter/material.dart';

class Logo extends StatelessWidget {
  final double velicina;

  const Logo({
    super.key,
    this.velicina = 68,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'lib/assets/nova_logo.png',
      width: velicina,
      height: velicina,
      fit: BoxFit.contain,
    );
  }
}