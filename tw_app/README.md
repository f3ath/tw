# tw_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Server sign-in

Run the server and use **Log in** in the top-right corner to sign in with Google
in your browser. Keep the app open; it displays your name after sign-in completes.
Select your name to log out. Sessions are kept in memory for the current app run.

The default API URL is `http://localhost:8080/api/v0`. Override it when needed:

```sh
flutter run --dart-define=TW_SERVER_URL=https://your-server.example/api/v0
```

Use an address reachable from the device (for example, `10.0.2.2` instead of
`localhost` on the Android emulator). Use HTTPS for deployed servers. For web,
the server must allow requests from the app's origin through CORS.
