import 'dart:convert';

import 'package:driver_devtools/src/driver_automation_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'encodes canonical finder JSON into the existing wire contract once',
    () {
      final request = JsonPayloads.finderVerificationFromCanonical({
        'finderType': 'Descendant',
        'of': {
          'finderType': 'ByMatchPosition',
          'position': 'index',
          'index': 2,
          'of': {'finderType': 'ByType', 'type': 'Column'},
        },
        'matching': {
          'finderType': 'ByText',
          'text': 'Order #',
          'matchType': 'contains',
          'ignoreCase': false,
        },
        'matchRoot': false,
        'firstMatchOnly': true,
      });

      expect(request.payload, {
        'finderType': 'Descendant',
        'of': {
          'finderType': 'ByMatchPosition',
          'position': 'index',
          'index': 2,
          'of': {'finderType': 'ByType', 'type': 'Column'},
        },
        'matching': {
          'finderType': 'ByText',
          'text': 'Order #',
          'matchType': 'contains',
          'ignoreCase': false,
        },
        'matchRoot': false,
        'firstMatchOnly': true,
      });
      expect(request.args, {
        'command': 'waitFor',
        'finderType': 'Descendant',
        'of':
            '{"finderType":"ByMatchPosition","position":"index",'
            '"index":"2","of":"{\\"finderType\\":\\"ByType\\",'
            '\\"type\\":\\"Column\\"}"}',
        'matching':
            '{"finderType":"ByText","text":"Order #",'
            '"matchType":"contains","ignoreCase":"false"}',
        'matchRoot': 'false',
        'firstMatchOnly': 'true',
        'timeout': '5000',
      });

      final nested = jsonDecode(request.args['of']!) as Map<String, dynamic>;
      expect(nested['of'], isA<String>());
      expect(jsonDecode(nested['of'] as String), {
        'finderType': 'ByType',
        'type': 'Column',
      });
    },
  );

  test('keeps command finder flattening behind canonical construction', () {
    final request = JsonPayloads.commandFromCanonical({
      'command': 'tap',
      'finder': {'finderType': 'ByText', 'text': 'Login'},
    });

    expect(request.args, {
      'command': 'tap',
      'finderType': 'ByText',
      'text': 'Login',
    });
  });
}
