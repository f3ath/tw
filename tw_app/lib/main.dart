import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_interop_http/http_interop_http.dart';
import 'package:json_api/routing.dart';
import 'package:tw_server/client.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TW',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const MyHomePage(title: 'TW Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: const [LoginControl(), SizedBox(width: 8)],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
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
}

class LoginControl extends StatefulWidget {
  const LoginControl({super.key, this.client, this.openAuthorization});

  final TwApiClient? client;
  final Future<bool> Function(Uri)? openAuthorization;

  @override
  State<LoginControl> createState() => _LoginControlState();
}

class _LoginControlState extends State<LoginControl> {
  final _http = http.Client();
  late final TwApiClient _client =
      widget.client ??
      TwApiClient(
        StandardUriDesign(
          Uri.parse(
            const String.fromEnvironment(
              'TW_SERVER_URL',
              defaultValue: 'http://localhost:8080/api/v0',
            ),
          ),
        ),
        (request) =>
            _http.handleInterop(request).timeout(const Duration(seconds: 15)),
      );
  String? _userName;
  Uri? _authorizationUri;
  bool _busy = false;

  Future<void> _login() async {
    setState(() => _busy = true);
    try {
      final session = await _client.createSession();
      if (!mounted) return;
      final redirect = Uri.tryParse(
        session?.attributes['redirect'] as String? ?? '',
      );
      if (redirect == null ||
          !const ['http', 'https'].contains(redirect.scheme)) {
        throw StateError('Missing authorization URL');
      }
      setState(() => _authorizationUri = redirect);
      final opened = await _openAuthorization(redirect);
      if (!mounted) return;
      if (!opened) {
        _showError('Select Open sign-in to continue in your browser.');
      }

      // The OAuth callback links the session on the server. Keep this app open
      // and wait for the user relationship to become available.
      final deadline = DateTime.now().add(const Duration(minutes: 3));
      while (mounted && DateTime.now().isBefore(deadline)) {
        final user = await _client.fetchCurrentUser();
        if (!mounted) return;
        if (user != null) {
          final name = (user.attributes['name'] as String?)?.trim();
          final email = (user.attributes['email'] as String?)?.trim();
          setState(() {
            _userName = name != null && name.isNotEmpty
                ? name
                : email != null && email.isNotEmpty
                ? email
                : 'Signed in';
          });
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      if (mounted) _showError('Sign-in timed out. Please try again.');
    } catch (_) {
      if (mounted) _showError('Could not sign in. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _authorizationUri = null;
        });
      }
    }
  }

  Future<bool> _openAuthorization(Uri uri) async {
    try {
      return await (widget.openAuthorization?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      return false;
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await _client.deleteSession();
      if (mounted) setState(() => _userName = null);
    } catch (_) {
      if (mounted) _showError('Could not log out. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      if (_authorizationUri case final uri?) {
        return TextButton.icon(
          onPressed: () async {
            if (!await _openAuthorization(uri) && mounted) {
              _showError('Could not open the sign-in page.');
            }
          },
          icon: const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: const Text('Open sign-in'),
        );
      }
      return const TextButton(onPressed: null, child: Text('Please wait…'));
    }
    if (_userName case final name?) {
      return MenuAnchor(
        menuChildren: [
          MenuItemButton(onPressed: _logout, child: const Text('Log out')),
        ],
        builder: (context, controller, child) => TextButton(
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width / 2,
            ),
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      );
    }
    return TextButton(onPressed: _login, child: const Text('Log in'));
  }
}
