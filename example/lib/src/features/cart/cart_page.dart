import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

class CartPage extends StatefulWidget {
  final bool isActive;

  const CartPage({super.key, this.isActive = false});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool _hasTrackedView = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive && !_hasTrackedView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _trackView();
      });
    }
  }

  @override
  void didUpdateWidget(CartPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive && !oldWidget.isActive && !_hasTrackedView) {
      _trackView();
    }
  }

  void _trackView() {
    if (_hasTrackedView) return;

    _hasTrackedView = true;

    GravitySDK.instance.trackView(
      context: context,
      pageContext: PageContext(
        type: ContextType.cart,
        data: [],
        location: 'cart',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Заказ'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              GravityInlineWidget(
                selector: 'bottom_sheet_recs_grid',
                pageContext: PageContext(
                  type: ContextType.cart,
                  data: [],
                  location: 'cart',
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
