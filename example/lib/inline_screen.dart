import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

class InlineScreen extends StatelessWidget {
  const InlineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inline Screen'),
      ),
      body: Column(
        children: [
          GravityInlineWidget(
            width: 200,
            height: 200,
            selector: 'bottom-sheet-banner',
            pageContext: PageContext(type: ContextType.search, data: ['adsfasdf'], location: 'sdfsdf'),
          ),
          SizedBox(height: 36,),
          GravityInlineWidget(
            selector: 'bottom-sheet-products-row',
          ),
        ],
      ),
    );
  }
}
