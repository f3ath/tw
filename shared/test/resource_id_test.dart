import 'package:shared/resource_id.dart';
import 'package:test/test.dart';

void main() {
  test('generates distinct lowercase UUID v4 IDs', () {
    final first = ResourceId.generate();
    final second = ResourceId.generate();

    expect(ResourceId.isValid(first), isTrue);
    expect(ResourceId.isValid(second), isTrue);
    expect(first, first.toLowerCase());
    expect(first, isNot(second));
  });

  test('accepts UUID v4 IDs in any letter case', () {
    const id = '12345678-abCd-4abc-8abc-1234567890ab';
    for (final value in [id, id.toLowerCase(), id.toUpperCase()]) {
      expect(ResourceId.isValid(value), isTrue);
    }
  });

  test('rejects malformed IDs, other UUID versions, and invalid variants', () {
    for (final id in [
      '',
      'not-a-uuid',
      '12345678abcd4abc8abc1234567890ab',
      '12345678-abcd-7abc-8abc-1234567890ab',
      '12345678-abcd-4abc-7abc-1234567890ab',
      '00000000-0000-0000-0000-000000000000',
      '12345678-abcd-4abc-8abc-1234567890ab\n',
    ]) {
      expect(ResourceId.isValid(id), isFalse, reason: id);
    }
  });
}
