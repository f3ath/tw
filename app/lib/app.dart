import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:app/api/create_api_client.dart';
import 'package:app/auth/login_controller.dart';
import 'package:app/home_page.dart';
import 'package:url_launcher/url_launcher.dart';

class const TwApp({super.key}) extends StatefulWidget {
  @override
  State<TwApp> createState() => _TwAppState();
}

class _TwAppState() extends State<TwApp> {
  final _transport = http.Client();
  late final _loginController = LoginController(
    client: createApiClient(_transport),
    openAuthorization: (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
  );

  @override
  void dispose() {
    _loginController.dispose();
    _transport.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TW',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: HomePage(title: 'TW Demo', loginController: _loginController),
    );
  }
}
