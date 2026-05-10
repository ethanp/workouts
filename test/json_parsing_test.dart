import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/utils/json_parsing.dart';

void main() {
  group('stringListFromJsonText', () {
    test('returns an empty list for null empty or malformed text', () {
      expect(stringListFromJsonText(null), isEmpty);
      expect(stringListFromJsonText(''), isEmpty);
      expect(stringListFromJsonText('{not json'), isEmpty);
      expect(stringListFromJsonText('{"not":"a list"}'), isEmpty);
    });

    test('returns strings and ignores non-string elements', () {
      expect(stringListFromJsonText('["brace", 5, "breathe", null]'), [
        'brace',
        'breathe',
      ]);
    });
  });

  group('jsonMapFromObject', () {
    test('converts map-like objects to string keyed maps', () {
      expect(jsonMapFromObject({'name': 'carry'}), {'name': 'carry'});
      expect(jsonMapFromObject({#badKey: 'skip'}), isNull);
      expect(jsonMapFromObject('not a map'), isNull);
    });
  });
}
