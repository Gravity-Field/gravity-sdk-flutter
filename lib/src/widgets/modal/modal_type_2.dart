import 'package:flutter/material.dart';

class ModalType2 extends StatelessWidget {
  final String imageUrl;

  const ModalType2({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Content(
            imageUrl: imageUrl,
          ),
          SizedBox(
            height: 8,
          ),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  style: ButtonStyle(fixedSize: WidgetStatePropertyAll(Size.fromHeight(50))),
                  child: Text('К покупкам'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final String imageUrl;

  const _Content({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Скидка 5% ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(
            height: 8,
          ),
          Text(
            'Поздравляем! Для вас доступен промокод на первую покупку в Mindbox',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(
            height: 8,
          ),
          SizedBox(
            height: 200,
            child: Image.network(imageUrl),
          ),
          SizedBox(
            height: 8,
          ),
        ],
      ),
    );
  }
}
