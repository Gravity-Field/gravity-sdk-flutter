import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/models/slot.dart';

class GravityProductWidget extends StatelessWidget {
  final Slot slot;

  const GravityProductWidget({super.key, required this.slot});

  @override
  Widget build(BuildContext context) {
    final item = slot.item;

    return Container(
      width: 160,
      height: 210,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 112,
            child: Image.network(item.imageUrl, fit: BoxFit.cover),
          ),
          SizedBox(
            height: 6,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              item.name,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
          ),
          SizedBox(
            height: 8,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Column(
                  children: [
                    if (item.oldPrice.isNotEmpty)
                      Text(
                        item.oldPrice,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF535862),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    Text(
                      item.price,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
