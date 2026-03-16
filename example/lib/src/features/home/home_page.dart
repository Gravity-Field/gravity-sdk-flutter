import 'package:example/gen/assets.gen.dart';
import 'package:example/src/core/widgets/product_shimmer_loader.dart';
import 'package:flutter/material.dart';

import 'package:gravity_sdk/gravity_sdk.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();

    GravitySDK.instance.trackView(
      context: context,
      pageContext: PageContext(
        type: ContextType.homepage,
        data: [],
        location: 'homepage',
        attributes: {'segment': 'vip'},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Assets.images.novasushi.image(),
        centerTitle: true,
        leading: const Icon(Icons.menu),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Assets.icons.search.image(
              width: 24,
              height: 24,
              color: Colors.grey,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Assets.icons.person.image(
              width: 24,
              height: 24,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              GravityInlineWidget(
                key: Key('inline_banner'),
                selector: 'inline_banner',
                pageContext: PageContext(
                  type: ContextType.homepage,
                  data: [],
                  location: 'homepage',
                ),
              ),
              GravityInlineWidget(
                key: Key('inline_widget_qa'),
                selector: 'inline_widget_qa',
                pageContext: PageContext(
                  type: ContextType.homepage,
                  data: [],
                  location: 'homepage',
                ),
              ),
              GravityInlineWidget(
                key: Key('inline_multi_widget_qa_placeholder_1'),
                selector: 'inline_multi_widget_qa',
                placeholderId: 'placeholder_1',
                pageContext: PageContext(
                  type: ContextType.homepage,
                  data: [],
                  location: 'homepage',
                ),
                loadingWidget: const ProductsShimmerLoader(),
              ),
              GravityInlineWidget(
                key: Key('inline_banner_2'),
                selector: 'inline_banner_2',
                pageContext: PageContext(
                  type: ContextType.homepage,
                  data: [],
                  location: 'homepage',
                ),
              ),
              GravityInlineWidget(
                key: Key('inline_multi_widget_qa_placeholder_2'),
                selector: 'inline_multi_widget_qa',
                placeholderId: 'placeholder_2',
                pageContext: PageContext(
                  type: ContextType.homepage,
                  data: [],
                  location: 'homepage',
                ),
                loadingWidget: const ProductsShimmerLoader(),
              ),
              GravityInlineWidget(
                key: Key('inline_multi_widget_qa_placeholder_3'),
                selector: 'inline_multi_widget_qa',
                placeholderId: 'placeholder_3',
                pageContext: PageContext(
                  type: ContextType.homepage,
                  data: [],
                  location: 'homepage',
                ),
                loadingWidget: const ProductsShimmerLoader(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
