import 'package:driver_devtools/src/finder_completion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'filters root completions at the caret and preserves the call suffix',
    () {
      const source = 'type("Column").first()';
      final caret = source.indexOf('type') + 2;

      final context = FinderCompletionContextAnalyzer.analyze(source, caret);

      expect(context.prefix, 'ty');
      expect(context.items.map((item) => item.label), ['type']);
      expect(context.replacementStart, 0);
      expect(context.replacementEnd, 4);

      final edit = context.apply(context.items.single, source);
      expect(edit.text, source);
      expect(edit.selectionOffset, 4);
    },
  );

  test('offers root factories inside a nested finder argument', () {
    const source = 'type("Column").descendant(ty';
    final context = FinderCompletionContextAnalyzer.analyze(
      source,
      source.length,
    );

    expect(context.items.map((item) => item.label), contains('type'));
    final edit = context.apply(
      context.items.firstWhere((item) => item.label == 'type'),
      source,
    );
    expect(edit.text, 'type("Column").descendant(type("")');
    expect(edit.selectionOffset, 'type("Column").descendant(type("'.length);
  });

  test('offers enum values after parsing nested parentheses and strings', () {
    const source = 'type("a),b").descendant(textMatch("Login", co';
    final context = FinderCompletionContextAnalyzer.analyze(
      source,
      source.length,
    );

    expect(context.items.map((item) => item.label), contains('contains'));
    final item = context.items.firstWhere(
      (candidate) => candidate.label == 'contains',
    );
    expect(context.apply(item, source).text, contains('contains'));
  });

  test('offers boolean values for the optional semantics label flag', () {
    const source = 'semanticsLabel("Login", ';
    final context = FinderCompletionContextAnalyzer.analyze(
      source,
      source.length,
    );

    expect(context.items.map((item) => item.label), ['true', 'false']);
  });

  test('provides a parameter signature inside an incomplete call', () {
    const source = 'textMatch("Login", ';
    final context = FinderCompletionContextAnalyzer.analyze(
      source,
      source.length,
    );

    expect(context.signature, 'textMatch(text, matchType, ignoreCase?)');
    expect(context.items, isNotEmpty);
  });

  test('offers chain methods after a dot', () {
    const source = 'type("Column").des';
    final context = FinderCompletionContextAnalyzer.analyze(
      source,
      source.length,
    );

    expect(context.items.map((item) => item.label), ['descendant']);
    expect(
      context.apply(context.items.single, source).text,
      'type("Column").descendant()',
    );
  });

  test(
    'inserts a root placeholder and positions the caret in its argument',
    () {
      final context = FinderCompletionContextAnalyzer.analyze('', 0);
      final item = context.items.firstWhere(
        (candidate) => candidate.label == 'type',
      );

      final edit = context.apply(item, '');

      expect(edit.text, 'type("")');
      expect(edit.selectionOffset, 'type("'.length);
    },
  );
}
