import 'package:driver_devtools/src/finder_completion.dart';
import 'package:driver_devtools/src/finder_dsl.dart';
import 'package:driver_devtools/src/finder_dsl_metadata.dart';
import 'package:driver_devtools/src/protocol/schema/protocol_schema_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogs every built-in root and chain exactly once', () {
    expect(FinderDslMetadataRegistry.roots, hasLength(8));
    expect(FinderDslMetadataRegistry.chains, hasLength(6));
    expect(
      FinderDslMetadataRegistry.all.map((definition) => definition.name),
      hasLength(14),
    );
    expect(
      FinderDslMetadataRegistry.all
          .map((definition) => definition.name)
          .toSet(),
      hasLength(14),
    );
    for (final definition in FinderDslMetadataRegistry.all) {
      expect(
        ProtocolSchemaRegistry.builtIn.findFinder(definition.finderType),
        isNotNull,
        reason: definition.name,
      );
    }
    expect(FinderDslMetadataRegistry.forFinderType('Ancestor'), hasLength(2));
    expect(
      FinderDslMetadataRegistry.findByCanonicalPosition('index')?.name,
      'at',
    );
  });

  test('completion entries are derived from metadata', () {
    final rootNames = FinderCompletionRegistry.roots.map((item) => item.label);
    final chainNames = FinderCompletionRegistry.chains.map(
      (item) => item.label,
    );
    expect(rootNames, FinderDslMetadataRegistry.roots.map((item) => item.name));
    expect(
      chainNames,
      FinderDslMetadataRegistry.chains.map((item) => item.name),
    );

    for (final definition in FinderDslMetadataRegistry.all) {
      final items =
          definition.memberKind == FinderDslMemberKind.root
              ? FinderCompletionRegistry.roots
              : FinderCompletionRegistry.chains;
      final item = items.singleWhere((item) => item.label == definition.name);
      expect(item.signature, definition.signature);
      expect(item.description, definition.description);
      expect(item.insertion, definition.completionInsertion());
      expect(item.caretOffset, definition.completionCaretOffset());
      expect(
        FinderCompletionRegistry.signatureFor(definition.name),
        definition.signature,
      );
    }
  });

  test('tokens cover every metadata name, enum value, and boolean literal', () {
    final tokens = <String>[
      ...FinderDslMetadataRegistry.all.map((definition) => definition.name),
      ...FinderDslMetadataRegistry.all.expand(
        (definition) =>
            definition.arguments.expand((argument) => argument.enumValues),
      ),
      'true',
      'false',
    ];

    for (final token in tokens) {
      expect(
        FinderCompletionRegistry.dslTokenPattern.hasMatch(token),
        isTrue,
        reason: token,
      );
    }
  });

  test('argument completion follows metadata kinds', () {
    for (final definition in FinderDslMetadataRegistry.all) {
      for (var index = 0; index < definition.arguments.length; index++) {
        final argument = definition.arguments[index];
        final items = FinderCompletionRegistry.itemsForArgument(
          definition,
          index,
        );
        switch (argument.kind) {
          case FinderDslArgumentKind.finder:
            expect(
              items.map((item) => item.label),
              FinderDslMetadataRegistry.roots.map((item) => item.name),
            );
          case FinderDslArgumentKind.enumValue:
            expect(items.map((item) => item.label), argument.enumValues);
          case FinderDslArgumentKind.boolean:
            expect(items.map((item) => item.label), ['true', 'false']);
          case FinderDslArgumentKind.string:
          case FinderDslArgumentKind.integer:
          case FinderDslArgumentKind.stringOrInteger:
            expect(items, isEmpty);
        }
      }
    }
  });

  test('metadata-derived canonical payloads validate and round-trip', () {
    for (final definition in FinderDslMetadataRegistry.all) {
      final ast = _astFor(definition);
      final canonical = FinderDslCodec.toCanonical(ast);
      final validation = ProtocolSchemaRegistry.builtIn.validateFinderPayload(
        canonical,
      );
      expect(validation.isValid, isTrue, reason: definition.name);
      expect(validation.hasSchema, isTrue, reason: definition.name);

      final generated = FinderDslGenerator.generateCanonical(canonical);
      final reconstructed = FinderDslParser.parse(generated);
      expect(
        FinderDslCodec.toCanonical(reconstructed),
        canonical,
        reason: definition.name,
      );
    }
  });

  test('integer keys retain their canonical type', () {
    expect(FinderDslCodec.toCanonical(FinderDslParser.parse('key(7)')), {
      'finderType': 'ByValueKey',
      'keyValueString': '7',
      'keyValueType': 'int',
    });
  });
}

FinderAst _astFor(FinderDslDefinition definition) {
  final arguments = [
    for (final argument in definition.arguments) _valueFor(argument),
  ];
  if (definition.memberKind == FinderDslMemberKind.root) {
    return FinderAst(definition.name, arguments);
  }
  return FinderAst(
    'text',
    [const FinderAstStringValue('base')],
    chain: [FinderAstCall(definition.name, arguments)],
  );
}

FinderAstValue _valueFor(FinderDslArgumentMetadata argument) {
  return switch (argument.kind) {
    FinderDslArgumentKind.string => const FinderAstStringValue('value'),
    FinderDslArgumentKind.integer => const FinderAstIntegerValue(0),
    FinderDslArgumentKind.boolean => const FinderAstBooleanValue(true),
    FinderDslArgumentKind.enumValue => FinderAstEnumValue(
      argument.enumValues.first,
    ),
    FinderDslArgumentKind.finder => FinderAstExpressionValue(
      FinderAst('text', [const FinderAstStringValue('nested')]),
    ),
    FinderDslArgumentKind.stringOrInteger => const FinderAstStringValue(
      'value',
    ),
  };
}
