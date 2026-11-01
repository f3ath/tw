import 'dart:convert';

import 'package:crypto/crypto.dart';

String tokenHash(String token) => sha256.convert(utf8.encode(token)).toString();
