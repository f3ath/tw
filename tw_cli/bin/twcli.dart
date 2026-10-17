import 'dart:io';

import 'package:twcli/twcli.dart';

Future<void> main(List<String> args) async {
  final exitCode = await TwCli.production().run(args, stdin: stdin, stdout: stdout, stderr: stderr);
  if (exitCode != 0) {
    exit(exitCode);
  }
}
