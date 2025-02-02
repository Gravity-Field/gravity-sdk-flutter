import 'package:flutter/material.dart';

class GravityBottomSheet extends StatelessWidget {
  const GravityBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                'https://media.istockphoto.com/id/498301640/ru/%D0%B2%D0%B5%D0%BA%D1%82%D0%BE%D1%80%D0%BD%D0%B0%D1%8F/big-%D0%BF%D1%80%D0%BE%D0%B4%D0%B0%D0%B6%D0%B0-%D0%B1%D0%B0%D0%BD%D0%BD%D0%B5%D1%80.jpg?s=2048x2048&w=is&k=20&c=C8_7_zP0THELiZrH4BDfl85ak2auPFb9nT9oPWZYXQk=',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              onPressed: () {},
              child: Text('За покупками'),
            ),
          ),
        ],
      ),
    );
  }
}
