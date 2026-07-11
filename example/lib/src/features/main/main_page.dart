import 'package:example/src/core/services/presentation_lock_prefs.dart';
import 'package:example/src/core/widgets/bottom_navigation_bar.dart';
import 'package:example/src/features/cart/cart_page.dart';
import 'package:example/src/features/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  bool _isPresentationLocked = GravitySDK.instance.isPresentationLocked;

  @override
  void initState() {
    super.initState();

    GravitySDK.instance.setPresentationLockListener((locked) {
      PresentationLockPrefs.save(locked);
      if (!mounted) return;
      setState(() {
        _isPresentationLocked = locked;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(locked ? 'Показ кампаний заблокирован' : 'Показ кампаний разблокирован'),
            duration: const Duration(seconds: 1),
          ),
        );
    });
  }

  @override
  void dispose() {
    GravitySDK.instance.setPresentationLockListener(null);
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _togglePresentationLock() {
    if (GravitySDK.instance.isPresentationLocked) {
      GravitySDK.instance.unlockPresentation();
    } else {
      GravitySDK.instance.lockPresentation();
    }
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
      floatingActionButton: FloatingActionButton(
        onPressed: _togglePresentationLock,
        backgroundColor: _isPresentationLocked ? Colors.red : Colors.green,
        child: Icon(_isPresentationLocked ? Icons.lock : Icons.lock_open, color: Colors.white),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }
}
