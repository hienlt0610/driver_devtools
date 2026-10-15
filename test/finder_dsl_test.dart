import 'package:driver_devtools/src/finder_dsl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinderDslParser and FinderDslCodec', () {
    test('lowers a nested chain to canonical finder JSON', () {
      final ast = FinderDslParser.parse(
        'type("Column").descendant(text("Đăng nhập")).ancestor('
        'type("InkWell")).first()',
      );

      expect(FinderDslCodec.toCanonical(ast), {
        'finderType': 'ByMatchPosition',
        'position': 'first',
        'of': {
          'finderType': 'Ancestor',
          'of': {
            'finderType': 'Descendant',
            'of': {'finderType': 'ByType', 'type': 'Column'},
            'matching': {'finderType': 'ByText', 'text': 'Đăng nhập'},
          },
          'matching': {'finderType': 'ByType', 'type': 'InkWell'},
        },
      });
    });

    test('preserves native booleans and integers in canonical JSON', () {
      final canonical = FinderDslCodec.toCanonical(
        FinderDslParser.parse(
          'textMatch("Order #", regex, true).descendant('
          'type("Row"), true, false).at(2)',
        ),
      );

      expect(canonical['position'], 'index');
      expect(canonical['index'], 2);
      final descendant = canonical['of'] as Map<String, dynamic>;
      expect(descendant['matchRoot'], isTrue);
      expect(descendant['firstMatchOnly'], isFalse);
      final textMatch = descendant['of'] as Map<String, dynamic>;
      expect(textMatch['ignoreCase'], isTrue);
    });

    test('supports all root finder mappings', () {
      expect(
        FinderDslCodec.toCanonical(FinderDslParser.parse('key("login")')),
        {
          'finderType': 'ByValueKey',
          'keyValueString': 'login',
          'keyValueType': 'String',
        },
      );
      expect(FinderDslCodec.toCanonical(FinderDslParser.parse('key(123)')), {
        'finderType': 'ByValueKey',
        'keyValueString': '123',
        'keyValueType': 'int',
      });
      expect(
        FinderDslCodec.toCanonical(
          FinderDslParser.parse('semanticsLabel("Login", true)'),
        ),
        {'finderType': 'BySemanticsLabel', 'label': 'Login', 'isRegExp': true},
      );
      expect(
        FinderDslCodec.toCanonical(FinderDslParser.parse('semanticsId("id")')),
        {'finderType': 'BySemanticsIdentifier', 'identifier': 'id'},
      );
      expect(
        FinderDslCodec.toCanonical(FinderDslParser.parse('tooltip("message")')),
        {'finderType': 'ByTooltipMessage', 'text': 'message'},
      );
      expect(
        FinderDslCodec.toCanonical(
          FinderDslParser.parse('tooltipText("text")'),
        ),
        {'finderType': 'ByTooltip', 'text': 'text'},
      );
      expect(FinderDslCodec.toCanonical(FinderDslParser.parse('pageBack()')), {
        'finderType': 'PageBack',
      });
    });

    test('uses containing only for its exact canonical flag combination', () {
      final canonical = {
        'finderType': 'Ancestor',
        'matchRoot': false,
        'firstMatchOnly': true,
        'of': {'finderType': 'ByText', 'text': 'Login'},
        'matching': {'finderType': 'ByType', 'type': 'Card'},
      };

      expect(
        FinderDslGenerator.generateCanonical(canonical),
        'type("Card")\n  .containing(text("Login"))',
      );
      expect(
        FinderDslCodec.toCanonical(
          FinderDslParser.parse(
            FinderDslGenerator.generateCanonical(canonical),
          ),
        ),
        canonical,
      );
    });

    test('falls back to ancestor while preserving non-containing flags', () {
      final canonical = {
        'finderType': 'Ancestor',
        'matchRoot': true,
        'firstMatchOnly': false,
        'of': {'finderType': 'ByText', 'text': 'Login'},
        'matching': {'finderType': 'ByType', 'type': 'Card'},
      };

      final dsl = FinderDslGenerator.generateCanonical(canonical);

      expect(dsl, 'text("Login")\n  .ancestor(type("Card"), true, false)');
      expect(FinderDslCodec.toCanonical(FinderDslParser.parse(dsl)), canonical);
    });

    test('prefers containing recursively inside composed finders', () {
      final canonical = {
        'finderType': 'Descendant',
        'of': {'finderType': 'ByType', 'type': 'Column'},
        'matching': {
          'finderType': 'Ancestor',
          'matchRoot': false,
          'firstMatchOnly': true,
          'of': {'finderType': 'ByText', 'text': 'Login'},
          'matching': {
            'finderType': 'Ancestor',
            'matchRoot': false,
            'firstMatchOnly': true,
            'of': {'finderType': 'ByType', 'type': 'Panel'},
            'matching': {'finderType': 'ByType', 'type': 'Card'},
          },
        },
      };

      final dsl = FinderDslGenerator.generateCanonical(canonical);

      expect(
        dsl,
        'type("Column")\n  .descendant(type("Card").containing('
        'type("Panel")).containing(text("Login")))',
      );
      expect(FinderDslCodec.toCanonical(FinderDslParser.parse(dsl)), canonical);
    });

    test('round-trips escaped Unicode strings and nested chains', () {
      final canonical = {
        'finderType': 'Descendant',
        'of': {'finderType': 'ByType', 'type': 'Column'},
        'matching': {'finderType': 'ByText', 'text': 'Đăng nhập "now"'},
        'matchRoot': false,
        'firstMatchOnly': true,
      };

      final dsl = FinderDslGenerator.generateCanonical(canonical);

      expect(FinderDslCodec.toCanonical(FinderDslParser.parse(dsl)), canonical);
      expect(dsl, contains(r'Đăng nhập \"now\"'));
    });

    test('reports syntax errors with a source position', () {
      expect(
        () => FinderDslParser.parse('type("Column"'),
        throwsA(
          isA<FinderDslException>()
              .having((error) => error.line, 'line', 1)
              .having((error) => error.column, 'column', greaterThan(1)),
        ),
      );
    });

    test('rejects unsupported methods and invalid arguments', () {
      expect(
        () => FinderDslCodec.toCanonical(
          FinderDslParser.parse('type("Column").unknown()'),
        ),
        throwsA(isA<FinderDslException>()),
      );
      expect(
        () => FinderDslCodec.toCanonical(
          FinderDslParser.parse('type("Column").at(-1)'),
        ),
        throwsA(isA<FinderDslException>()),
      );
      expect(
        () => FinderDslCodec.fromCanonical({
          'finderType': 'CustomFinder',
          'value': 'kept in JSON mode',
        }),
        throwsA(isA<FinderDslException>()),
      );
    });
  });
}
