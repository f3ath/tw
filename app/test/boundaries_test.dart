import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dependency boundaries confine networking and storage to Services', () {
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final imports = RegExp(r'''(?:import|export)\s+['"]([^'"]+)''')
          .allMatches(file.readAsStringSync())
          .map((m) => m[1]!);
      for (final path in imports) {
        if (RegExp(r'package:(shared/|http/|http_interop|json_api|url_launcher|web/)')
            .hasMatch(path)) {
          expect(file.path.startsWith('lib/data/services/'), isTrue, reason: file.path);
        }
        if (file.path.startsWith('lib/domain/')) {
          expect(path, isNot(matches(r'(package:flutter|data/|ui/|services/)')), reason: file.path);
        }
        if (file.path.startsWith('lib/ui/')) {
          expect(
            path,
            isNot(matches(r'(data/|services/|shared_preferences|dart:io|dart:html)')),
            reason: file.path,
          );
        }
        if (path.contains('shared_preferences')) {
          expect(file.path.startsWith('lib/data/services/'), isTrue, reason: file.path);
        }
      }
    }
  });
}
