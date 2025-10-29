import 'package:example/src/core/widgets/bottom_navigation_bar.dart';
import 'package:example/src/features/cart/cart_page.dart';
import 'package:example/src/features/home/home_page.dart';
import 'package:flutter/material.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      const Center(child: Text('Акции')),
      CartPage(key: const ValueKey('cart_page'), isActive: _selectedIndex == 2),
      const Center(child: Text('История')),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }
}
