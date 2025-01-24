import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _ModalButton(),
            _ModalButton2(),
            _SnackBarButton(),
          ],
        ),
      ),
    );
  }
}

class _ModalButton extends StatelessWidget {
  const _ModalButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) {
            final modal = GravitySDK().getModal(type: GravityModalType.type1);
            return modal;
          },
        );
      },
      child: Text('Show Modal'),
    );
  }
}

class _ModalButton2 extends StatelessWidget {
  const _ModalButton2();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) {
            final modal = GravitySDK().getModal(type: GravityModalType.type2);
            return modal;
          },
        );
      },
      child: Text('Show Modal 2'),
    );
  }
}

class _SnackBarButton extends StatelessWidget {
  const _SnackBarButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () {
        final snackBar = GravitySDK().getSnackBar(type: GravitySnackBarType.type1);
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      },
      child: Text('Show SnackBar'),
    );
  }
}
