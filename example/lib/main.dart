import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

void main() {

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {

    GravitySDK.instance.initialize(navigatorKey: navigatorKey);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Gravity SDK Example'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // _ModalButton(),
            // _ModalButton2(),
            // _SnackBarButton(),
            // _BottomSheetButton(),
            // _FullScreenButton(),
            _AddToCartEvent(),
          ],
        ),
      ),
    );
  }
}

// class _ModalButton extends StatelessWidget {
//   const _ModalButton();
//
//   @override
//   Widget build(BuildContext context) {
//     return FilledButton(
//       onPressed: () {
//         showDialog(
//           context: context,
//           builder: (context) {
//             final modal = GravitySDK.instance.getModal(type: GravityModalType.type1);
//             return modal;
//           },
//         );
//       },
//       child: Text('Show Modal'),
//     );
//   }
// }
//
// class _ModalButton2 extends StatelessWidget {
//   const _ModalButton2();
//
//   @override
//   Widget build(BuildContext context) {
//     return FilledButton(
//       onPressed: () {
//         showDialog(
//           context: context,
//           builder: (context) {
//             final modal = GravitySDK.instance.getModal(type: GravityModalType.type2);
//             return modal;
//           },
//         );
//       },
//       child: Text('Show Modal 2'),
//     );
//   }
// }
//
// class _SnackBarButton extends StatelessWidget {
//   const _SnackBarButton();
//
//   @override
//   Widget build(BuildContext context) {
//     return FilledButton(
//       onPressed: () {
//         final snackBar = GravitySDK.instance.getSnackBar(type: GravitySnackBarType.type1);
//         ScaffoldMessenger.of(context).showSnackBar(snackBar);
//       },
//       child: Text('Show SnackBar'),
//     );
//   }
// }
//
// class _BottomSheetButton extends StatelessWidget {
//   const _BottomSheetButton();
//
//   @override
//   Widget build(BuildContext context) {
//     return FilledButton(
//       onPressed: () {
//         showModalBottomSheet(
//           context: context,
//           builder: (context) {
//             final bottomSheet = GravitySDK.instance.getBottomSheet();
//             return bottomSheet;
//           },
//         );
//       },
//       child: Text('Show Bottom Sheet'),
//     );
//   }
// }
//
// class _FullScreenButton extends StatelessWidget {
//   const _FullScreenButton();
//
//   @override
//   Widget build(BuildContext context) {
//     return FilledButton(
//       onPressed: () {
//         Navigator.of(context).push(
//           MaterialPageRoute(
//             builder: (context) {
//               final fullScreen = GravitySDK.instance.getFullScreen();
//               return fullScreen;
//             },
//           ),
//         );
//       },
//       child: Text('Show Full Screen'),
//     );
//   }
// }

class _AddToCartEvent extends StatelessWidget {
  const _AddToCartEvent();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () {
        GravitySDK.instance.onAddToCartEvent(context);
      },
      child: Text('Add to cart'),
    );
  }
}
