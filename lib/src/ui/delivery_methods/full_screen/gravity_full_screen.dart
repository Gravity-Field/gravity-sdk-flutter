import 'package:flutter/material.dart';

class GravityFullScreen extends StatelessWidget {
  const GravityFullScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Подарок новичкам'),
                SizedBox(height: 16,),
                Text('Получите 500 бонусов за установку приложения ЛЭТУАЛЬ'),
                Expanded(child: Image.network('https://i.pinimg.com/736x/ff/07/96/ff07969368583b661cf6826af280fa91.jpg', fit: BoxFit.cover,)),
                SizedBox(height: 16,),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton(
                    onPressed: () {},
                    child: Text('За покупками'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
