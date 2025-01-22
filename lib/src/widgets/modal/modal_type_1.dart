import 'package:flutter/material.dart';

class ModalType1 extends StatelessWidget {
  final double imageSize;
  final double buttonSize;
  final String imageUrl;

  const ModalType1({
    super.key,
    required this.imageSize,
    required this.buttonSize,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          _Background(
            imageSize: imageSize,
            buttonSize: buttonSize,
          ),
          _Content(
            imageSize: imageSize,
            buttonSize: buttonSize,
          ),
          _Button(
            buttonSize: buttonSize,
          ),
          _Image(
            imageSize: imageSize,
            imageUrl: imageUrl,
          ),
        ],
      ),
    );
  }
}

class _Background extends StatelessWidget {
  final double imageSize;
  final double buttonSize;

  const _Background({
    super.key,
    required this.imageSize,
    required this.buttonSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: imageSize / 2),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        SizedBox(height: buttonSize / 2),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  final double imageSize;
  final double buttonSize;

  const _Content({
    super.key,
    required this.imageSize,
    required this.buttonSize,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: imageSize.toDouble(),
      left: 0,
      right: 0,
      bottom: buttonSize.toDouble(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
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
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  final double buttonSize;

  const _Button({super.key, required this.buttonSize});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilledButton(
            onPressed: () {},
            style: ButtonStyle(fixedSize: WidgetStatePropertyAll(Size.fromHeight(buttonSize.toDouble()))),
            child: Text('Получить промокод'),
          ),
        ],
      ),
    );
  }
}

class _Image extends StatelessWidget {
  final double imageSize;
  final String imageUrl;

  const _Image({
    super.key,
    required this.imageSize,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: imageSize.toDouble(),
            child: Image.network(imageUrl),
          ),
        ],
      ),
    );
  }
}
