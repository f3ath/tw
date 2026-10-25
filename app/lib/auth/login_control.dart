import 'package:flutter/material.dart';
import 'package:app/auth/login_controller.dart';
import 'package:app/auth/login_state.dart';

class const LoginControl({super.key, required final LoginController controller}) extends StatefulWidget {
  @override
  State<LoginControl> createState() => _LoginControlState();
}

class _LoginControlState() extends State<LoginControl> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(LoginControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  void _onChanged() {
    setState(() {});
    final error = widget.controller.takeError();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (widget.controller.state) {
    SignedOut() => TextButton(onPressed: widget.controller.login, child: const Text('Log in')),
    SigningIn() || SigningOut() => const TextButton(onPressed: null, child: Text('Please wait…')),
    AwaitingAuthorization() => TextButton.icon(
      onPressed: widget.controller.openAuthorization,
      icon: const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      label: const Text('Open sign-in'),
    ),
    SignedIn(:final userName) => MenuAnchor(
      menuChildren: [
        MenuItemButton(onPressed: widget.controller.logout, child: const Text('Log out')),
      ],
      builder: (context, controller, child) => TextButton(
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width / 2),
          child: Text(userName, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    ),
  };
}
