import 'package:cached_network_image/cached_network_image.dart';
import 'package:example/gen/assets.gen.dart';
import 'package:example/src/features/webview/webview_page.dart';
import 'package:flutter/material.dart';

import 'package:gravity_sdk/gravity_sdk.dart';

class CustomProductWidgetBuilder extends ProductWidgetBuilder {
  @override
  Widget build({
    required BuildContext context,
    required Slot product,
    required CampaignContent content,
    required Campaign campaign,
  }) {
    final productData = product.item;
    final name = productData['name'] as String? ?? '';
    final price = productData['price'] as String?;
    final imageUrl = productData['image_url'] as String?;
    final url = productData['url'] as String?;
    final inStock = productData['in_stock'] as bool? ?? false;

    return GestureDetector(
      onTap: () {
        GravitySDK.instance.sendProductEngagement(
          ProductClickEngagement(product, content, campaign),
        );

        if (url != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => WebViewPage(url: url)),
          );
        }
      },
      child: SizedBox(
        width: 164,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Container(
                            width: 164,
                            height: 164,
                            color: Colors.grey[100],
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            return Container(
                              width: 164,
                              height: 164,
                              color: Colors.grey[100],
                              child: Icon(
                                Icons.image_not_supported,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                            );
                          },
                        )
                      : ColoredBox(
                          color: Colors.grey,
                          child: Icon(
                            Icons.shopping_bag,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: inStock ? const Color(0xFFFFE5E5) : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$price ₽',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: inStock ? const Color(0xFFFF4D4D) : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Assets.icons.shoppingBasket.image(color: Colors.red),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
