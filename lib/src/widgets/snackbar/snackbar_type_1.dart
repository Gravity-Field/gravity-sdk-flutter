import 'package:flutter/material.dart';
import 'package:flutter/src/material/snack_bar.dart';
import 'package:gravity_sdk/src/widgets/snackbar/snackbar.dart';

class SnackBarType1 extends GravitySnackBar {
  final String title;
  final String text;
  final String imageUrl;

  SnackBarType1({
    required this.title,
    required this.text,
    required this.imageUrl,
  });

  @override
  SnackBar toMaterialSnackBar() {
    return SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      content: Stack(
        children: [
          _Background(),
          _Content(
            imageUrl: imageUrl,
          ),
        ],
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          SizedBox(width: 30),
          Expanded(
            child: Container(
              height: 100,
              width: double.minPositive,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x19000000),
                    spreadRadius: 2.0,
                    blurRadius: 8.0,
                    offset: Offset(2, 4),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final String imageUrl;

  const _Content({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 60,
            child: Image.network(imageUrl),
          ),
          SizedBox(
            width: 16,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Скидка 5% ',
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(
                  height: 8,
                ),
                Text(
                  'Для вас доступен промокод на первую покупку в Mindbox',
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 8,
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.black,
            child: Icon(Icons.arrow_forward, color: Colors.white,),
          ),
          SizedBox(
            width: 16,
          ),
        ],
      ),
    );
  }
}
