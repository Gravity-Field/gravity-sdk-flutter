import 'package:example/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  const AppBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    this.onDestinationSelected,
  });

  void _handleDestinationSelected(BuildContext context, int index) {
    final destinationNames = ['Главный', 'Акции', 'Заказ', 'История'];

    GravitySDK.instance.triggerEvent(
      context: context,
      events: [
        CustomEvent(type: 'Tapbar — clicked', name: destinationNames[index]),
      ],
      pageContext: PageContext(
        type: ContextType.homepage,
        data: [],
        location: 'homepage',
      ),
    );

    onDestinationSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        navigationBarTheme: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              );
            }
            return const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            );
          }),
        ),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => _handleDestinationSelected(context, index),
        backgroundColor: const Color(0xFFF5F5F5),
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            label: 'Главный',
            icon: Assets.icons.home.image(
              width: 24,
              height: 24,
              color: selectedIndex == 0 ? Colors.red : Colors.grey,
            ),
          ),
          NavigationDestination(
            label: 'Акции',
            icon: Assets.icons.gift.image(
              width: 24,
              height: 24,
              color: selectedIndex == 1 ? Colors.red : Colors.grey,
            ),
          ),
          NavigationDestination(
            label: 'Заказ',
            icon: Assets.icons.shoppingBasket.image(
              width: 24,
              height: 24,
              color: selectedIndex == 2 ? Colors.red : Colors.grey,
            ),
          ),
          NavigationDestination(
            label: 'История',
            icon: Assets.icons.history.image(
              width: 24,
              height: 24,
              color: selectedIndex == 3 ? Colors.red : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
