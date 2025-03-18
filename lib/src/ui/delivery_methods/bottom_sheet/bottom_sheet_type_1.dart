import 'package:flutter/material.dart';

import 'bottom_sheet_data.dart';

class BottomSheetType1 extends StatelessWidget {
  final BottomSheetData data;

  const BottomSheetType1({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 20, left: 32, right: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: data.circleIconBackground,
              child: Image.asset(
                data.circeIconAssetImage,
                width: 72,
                height: 72,
                package: 'gravity_sdk',
              ),
            ),
            SizedBox(height: 24),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF181d27),
              ),
            ),
            SizedBox(height: 4),
            Text(
              data.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF535862),
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(data.buttonText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
