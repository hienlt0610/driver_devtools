import 'package:driver_devtools/src/java_finder_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates a Java byValueKey finder', () {
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'ByValueKey',
        'keyValueString': 'login.submit',
        'keyValueType': 'String',
      }),
      'Flutter.byKey("login.submit")',
    );
  });

  test('generates a Java byType finder', () {
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'ByType',
        'type': 'TextField',
      }),
      'Flutter.byType("TextField")',
    );
  });

  test('generates a Java byText finder', () {
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'ByText',
        'text': 'Đăng nhập',
      }),
      'Flutter.byText("Đăng nhập")',
    );
  });

  test('generates text match with the Java enum and ignoreCase', () {
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'ByText',
        'text': 'Completed',
        'matchType': 'contains',
        'ignoreCase': true,
      }),
      'Flutter.byTextMatch("Completed", '
      'Flutter.TextMatchType.CONTAINS, true)',
    );
  });

  test('generates semantics label regex and tooltip finders', () {
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'BySemanticsLabel',
        'label': r'^Open .*',
        'isRegExp': true,
      }),
      'Flutter.bySemanticsLabelRegex("^Open .*")',
    );
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'ByTooltipMessage',
        'text': 'Open menu',
      }),
      'Flutter.byTooltip("Open menu")',
    );
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'BySemanticsIdentifier',
        'identifier': 'checkout.submit',
      }),
      'Flutter.bySemanticsIdentifier("checkout.submit")',
    );
    expect(
      JavaFinderGenerator.generate({'finderType': 'PageBack'}),
      'Flutter.pageBack()',
    );
  });

  test('rejects an empty semantics identifier', () {
    expect(
      () => JavaFinderGenerator.generate({
        'finderType': 'BySemanticsIdentifier',
        'identifier': '  ',
      }),
      throwsA(
        isA<JavaFinderGenerationException>().having(
          (error) => error.path,
          'path',
          'identifier',
        ),
      ),
    );
  });

  test('maps text match strategies and omits a false ignoreCase flag', () {
    for (final entry
        in {
          'contains': 'CONTAINS',
          'startsWith': 'STARTS_WITH',
          'endsWith': 'ENDS_WITH',
          'regex': 'REGEX',
        }.entries) {
      expect(
        JavaFinderGenerator.generate({
          'finderType': 'ByText',
          'text': 'Order',
          'matchType': entry.key,
          'ignoreCase': false,
        }),
        'Flutter.byTextMatch("Order", Flutter.TextMatchType.${entry.value})',
      );
    }
  });

  test('generates a descendant chain and omits default flags', () {
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'Descendant',
        'matchRoot': false,
        'firstMatchOnly': false,
        'of': {
          'finderType': 'ByValueKey',
          'keyValueString': 'qr_payment.account_holder_item',
          'keyValueType': 'String',
        },
        'matching': {'finderType': 'ByType', 'type': 'Expanded'},
      }),
      'Flutter.byKey("qr_payment.account_holder_item")'
      '.descendant(Flutter.byType("Expanded"))',
    );
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'Descendant',
        'matchRoot': true,
        'firstMatchOnly': false,
        'of': {'finderType': 'ByType', 'type': 'Column'},
        'matching': {'finderType': 'ByText', 'text': 'Settings'},
      }),
      'Flutter.byType("Column").descendant('
      'Flutter.byText("Settings"), true, false)',
    );
  });

  test('prefers containing for the exact ancestor pattern', () {
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'Ancestor',
        'matchRoot': false,
        'firstMatchOnly': true,
        'of': {'finderType': 'ByText', 'text': 'Completed'},
        'matching': {'finderType': 'ByType', 'type': 'Card'},
      }),
      'Flutter.byType("Card").containing(Flutter.byText("Completed"))',
    );
  });

  test('falls back to ancestor when containing is not equivalent', () {
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'Ancestor',
        'matchRoot': false,
        'firstMatchOnly': false,
        'of': {'finderType': 'ByText', 'text': 'Completed'},
        'matching': {'finderType': 'ByType', 'type': 'Card'},
      }),
      'Flutter.byText("Completed").ancestor(Flutter.byType("Card"))',
    );
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'Ancestor',
        'matchRoot': true,
        'firstMatchOnly': true,
        'of': {'finderType': 'ByText', 'text': 'Completed'},
        'matching': {'finderType': 'ByType', 'type': 'Card'},
      }),
      'Flutter.byText("Completed").ancestor('
      'Flutter.byType("Card"), true, true)',
    );
  });

  test('renders nested containing after a descendant chain', () {
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'Ancestor',
        'matchRoot': false,
        'firstMatchOnly': true,
        'of': {'finderType': 'ByText', 'text': 'Completed'},
        'matching': {
          'finderType': 'Descendant',
          'matchRoot': false,
          'firstMatchOnly': false,
          'of': {
            'finderType': 'ByValueKey',
            'keyValueString': 'orders.list',
            'keyValueType': 'String',
          },
          'matching': {'finderType': 'ByType', 'type': 'OrderCard'},
        },
      }),
      'Flutter.byKey("orders.list")'
      '.descendant(Flutter.byType("OrderCard"))'
      '.containing(Flutter.byText("Completed"))',
    );
  });

  test('generates all match positions', () {
    final finder = {'finderType': 'ByType', 'type': 'ListTile'};
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'ByMatchPosition',
        'position': 'index',
        'index': 2,
        'of': finder,
      }),
      'Flutter.byType("ListTile").at(2)',
    );
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'ByMatchPosition',
        'position': 'first',
        'of': finder,
      }),
      'Flutter.byType("ListTile").first()',
    );
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'ByMatchPosition',
        'position': 'last',
        'of': finder,
      }),
      'Flutter.byType("ListTile").last()',
    );
  });

  test('escapes Java string literals without changing regex content', () {
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'ByText',
        'text': 'line "one"\\n',
        'matchType': 'regex',
      }),
      'Flutter.byTextMatch("line \\"one\\"\\\\n", '
      'Flutter.TextMatchType.REGEX)',
    );
  });

  test('rejects an unsupported finder with its path', () {
    expect(
      () => JavaFinderGenerator.generate({'finderType': 'ByTooltip'}),
      throwsA(
        isA<JavaFinderGenerationException>()
            .having((error) => error.path, 'path', 'finderType')
            .having(
              (error) => error.message,
              'message',
              'Unsupported finder type "ByTooltip".',
            ),
      ),
    );
  });

  test('rejects a key type Java cannot preserve', () {
    expect(
      () => JavaFinderGenerator.generate({
        'finderType': 'ByValueKey',
        'keyValueString': '123',
        'keyValueType': 'String',
      }),
      throwsA(isA<JavaFinderGenerationException>()),
    );
    expect(
      JavaFinderGenerator.generate({
        'finderType': 'ByValueKey',
        'keyValueString': '123',
        'keyValueType': 'int',
      }),
      'Flutter.byKey("123")',
    );
  });

  test('reports invalid match position values', () {
    expect(
      () => JavaFinderGenerator.generate({
        'finderType': 'ByMatchPosition',
        'position': 'index',
        'index': -1,
        'of': {'finderType': 'ByType', 'type': 'ListTile'},
      }),
      throwsA(
        isA<JavaFinderGenerationException>().having(
          (error) => error.path,
          'path',
          'index',
        ),
      ),
    );
  });

  test('reports the nested path for unsupported finders', () {
    expect(
      () => JavaFinderGenerator.generate({
        'finderType': 'Descendant',
        'of': {'finderType': 'ByType', 'type': 'Column'},
        'matching': {'finderType': 'CustomFinder'},
      }),
      throwsA(
        isA<JavaFinderGenerationException>().having(
          (error) => error.path,
          'path',
          'matching.finderType',
        ),
      ),
    );
  });
}
