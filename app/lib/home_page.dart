import 'package:flutter/material.dart';
import 'package:app/auth/login_control.dart';
import 'package:app/auth/login_controller.dart';

class const HomePage({
  super.key,
  required final String title,
  required final LoginController loginController,
}) extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState() extends State<HomePage> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: Text(widget.title),
      actions: [
        LoginControl(controller: widget.loginController),
        const SizedBox(width: 8),
      ],
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: .center,
        children: [
          const Text('You have pushed the button this many times:'),
          Text('$_counter', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () => setState(() => _counter++),
      tooltip: 'Increment',
      child: const Icon(Icons.add),
    ),
  );
}
