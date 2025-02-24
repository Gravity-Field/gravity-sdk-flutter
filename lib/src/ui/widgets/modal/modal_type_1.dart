import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'modal_data.dart';

class ModalType1 extends StatelessWidget {
  final ModalData data;

  const ModalType1({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Content(data: data),
              Divider(height: 1, thickness: 1,),
              _Actions(),
            ],
          ),
          Positioned(
            top: 12,
            right: 12,
            child: IconButton(
              icon: Icon(Icons.close),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final ModalData data;

  const _Content({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: data.crossAxisAlignment,
        children: [
          if (data.networkIcon != null)
            SvgPicture.network(data.networkIcon!)
          else if (data.assetsIcon != null)
            SvgPicture.asset(data.assetsIcon!, package: 'gravity_sdk',),
          SizedBox(height: 12),
          Text(
            data.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF181d27),
            ),
          ),
          SizedBox(height: 4),
          Text(
            data.description,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF535862),
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Скопировать'),
          ),
          SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
