import 'package:flutter/foundation.dart';

@immutable
sealed class const LoginState();

final class const SignedOut() extends LoginState;

final class const SigningIn() extends LoginState;

final class const AwaitingAuthorization(final Uri uri) extends LoginState {}

final class const SignedIn(final String userName) extends LoginState {}

final class const SigningOut(final String userName) extends LoginState {}
