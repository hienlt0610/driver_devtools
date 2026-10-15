enum FinderDslMemberKind { root, chain }

enum FinderDslArgumentKind {
  string,
  integer,
  boolean,
  enumValue,
  finder,
  stringOrInteger,
}

enum FinderDslMappingKind {
  byType,
  valueKey,
  byText,
  textMatch,
  semanticsLabel,
  semanticsIdentifier,
  tooltipMessage,
  tooltip,
  pageBack,
  relation,
  containing,
  matchPosition,
}

class FinderDslArgumentMetadata {
  const FinderDslArgumentMetadata({
    required this.name,
    required this.kind,
    this.required = true,
    this.enumValues = const [],
    this.defaultValue,
    this.hasDefaultValue = false,
  });

  final String name;
  final FinderDslArgumentKind kind;
  final bool required;
  final List<String> enumValues;
  final Object? defaultValue;
  final bool hasDefaultValue;
}

class FinderDslDefinition {
  const FinderDslDefinition({
    required this.name,
    required this.memberKind,
    required this.finderType,
    required this.mapping,
    required this.arguments,
    required this.signature,
    required this.description,
    this.canonicalPosition,
  });

  final String name;
  final FinderDslMemberKind memberKind;
  final String finderType;
  final FinderDslMappingKind mapping;
  final List<FinderDslArgumentMetadata> arguments;
  final String signature;
  final String description;
  final String? canonicalPosition;

  int get requiredArgumentCount =>
      arguments.where((argument) => argument.required).length;

  FinderDslArgumentMetadata? argumentAt(int index) {
    if (index < 0 || index >= arguments.length) return null;
    return arguments[index];
  }

  String completionInsertion() {
    final argumentsText = arguments
        .where((argument) => argument.required)
        .map(_completionValue)
        .join(', ');
    return '$name($argumentsText)';
  }

  int completionCaretOffset() {
    final requiredArguments = arguments
        .where((argument) => argument.required)
        .toList(growable: false);
    if (requiredArguments.isEmpty) return completionInsertion().length;

    final first = requiredArguments.first;
    final firstArgumentOffset = name.length + 1;
    final caretInsideValue = switch (first.kind) {
      FinderDslArgumentKind.string ||
      FinderDslArgumentKind.stringOrInteger => 1,
      _ => 0,
    };
    return firstArgumentOffset + caretInsideValue;
  }

  String _completionValue(FinderDslArgumentMetadata argument) {
    return switch (argument.kind) {
      FinderDslArgumentKind.string ||
      FinderDslArgumentKind.stringOrInteger => '""',
      FinderDslArgumentKind.integer => '0',
      FinderDslArgumentKind.boolean => 'false',
      FinderDslArgumentKind.enumValue => argument.enumValues.first,
      FinderDslArgumentKind.finder => '',
    };
  }
}

class FinderDslMetadataRegistry {
  FinderDslMetadataRegistry._();

  static const List<FinderDslDefinition> roots = [
    FinderDslDefinition(
      name: 'type',
      memberKind: FinderDslMemberKind.root,
      finderType: 'ByType',
      mapping: FinderDslMappingKind.byType,
      arguments: [
        FinderDslArgumentMetadata(
          name: 'value',
          kind: FinderDslArgumentKind.string,
        ),
      ],
      signature: 'type(value: String)',
      description: 'Match widgets by runtime type.',
    ),
    FinderDslDefinition(
      name: 'key',
      memberKind: FinderDslMemberKind.root,
      finderType: 'ByValueKey',
      mapping: FinderDslMappingKind.valueKey,
      arguments: [
        FinderDslArgumentMetadata(
          name: 'value',
          kind: FinderDslArgumentKind.stringOrInteger,
        ),
      ],
      signature: 'key(value: String | int)',
      description: 'Match a ValueKey.',
    ),
    FinderDslDefinition(
      name: 'text',
      memberKind: FinderDslMemberKind.root,
      finderType: 'ByText',
      mapping: FinderDslMappingKind.byText,
      arguments: [
        FinderDslArgumentMetadata(
          name: 'value',
          kind: FinderDslArgumentKind.string,
        ),
      ],
      signature: 'text(value: String)',
      description: 'Match widgets by exact text.',
    ),
    FinderDslDefinition(
      name: 'textMatch',
      memberKind: FinderDslMemberKind.root,
      finderType: 'ByTextMatch',
      mapping: FinderDslMappingKind.textMatch,
      arguments: [
        FinderDslArgumentMetadata(
          name: 'text',
          kind: FinderDslArgumentKind.string,
        ),
        FinderDslArgumentMetadata(
          name: 'matchType',
          kind: FinderDslArgumentKind.enumValue,
          enumValues: ['contains', 'startsWith', 'endsWith', 'regex'],
        ),
        FinderDslArgumentMetadata(
          name: 'ignoreCase',
          kind: FinderDslArgumentKind.boolean,
          required: false,
          defaultValue: false,
          hasDefaultValue: true,
        ),
      ],
      signature: 'textMatch(text, matchType, ignoreCase?)',
      description: 'Match widget text with a supported match strategy.',
    ),
    FinderDslDefinition(
      name: 'semanticsLabel',
      memberKind: FinderDslMemberKind.root,
      finderType: 'BySemanticsLabel',
      mapping: FinderDslMappingKind.semanticsLabel,
      arguments: [
        FinderDslArgumentMetadata(
          name: 'label',
          kind: FinderDslArgumentKind.string,
        ),
        FinderDslArgumentMetadata(
          name: 'isRegExp',
          kind: FinderDslArgumentKind.boolean,
          required: false,
        ),
      ],
      signature: 'semanticsLabel(label, isRegExp?)',
      description: 'Match a semantics label.',
    ),
    FinderDslDefinition(
      name: 'semanticsId',
      memberKind: FinderDslMemberKind.root,
      finderType: 'BySemanticsIdentifier',
      mapping: FinderDslMappingKind.semanticsIdentifier,
      arguments: [
        FinderDslArgumentMetadata(
          name: 'identifier',
          kind: FinderDslArgumentKind.string,
        ),
      ],
      signature: 'semanticsId(identifier: String)',
      description: 'Match a semantics identifier.',
    ),
    FinderDslDefinition(
      name: 'tooltip',
      memberKind: FinderDslMemberKind.root,
      finderType: 'ByTooltipMessage',
      mapping: FinderDslMappingKind.tooltipMessage,
      arguments: [
        FinderDslArgumentMetadata(
          name: 'text',
          kind: FinderDslArgumentKind.string,
        ),
      ],
      signature: 'tooltip(text: String)',
      description: 'Match a tooltip message.',
    ),
    FinderDslDefinition(
      name: 'tooltipText',
      memberKind: FinderDslMemberKind.root,
      finderType: 'ByTooltip',
      mapping: FinderDslMappingKind.tooltip,
      arguments: [
        FinderDslArgumentMetadata(
          name: 'text',
          kind: FinderDslArgumentKind.string,
        ),
      ],
      signature: 'tooltipText(text: String)',
      description: 'Match tooltip text.',
    ),
    FinderDslDefinition(
      name: 'pageBack',
      memberKind: FinderDslMemberKind.root,
      finderType: 'PageBack',
      mapping: FinderDslMappingKind.pageBack,
      arguments: [],
      signature: 'pageBack()',
      description: 'Match the page-back finder.',
    ),
  ];

  static const List<FinderDslDefinition> chains = [
    FinderDslDefinition(
      name: 'descendant',
      memberKind: FinderDslMemberKind.chain,
      finderType: 'Descendant',
      mapping: FinderDslMappingKind.relation,
      arguments: [
        FinderDslArgumentMetadata(
          name: 'matching',
          kind: FinderDslArgumentKind.finder,
        ),
        FinderDslArgumentMetadata(
          name: 'matchRoot',
          kind: FinderDslArgumentKind.boolean,
          required: false,
        ),
        FinderDslArgumentMetadata(
          name: 'firstMatchOnly',
          kind: FinderDslArgumentKind.boolean,
          required: false,
        ),
      ],
      signature: 'descendant(matching, matchRoot?, firstMatchOnly?)',
      description: 'Find a descendant matching a nested finder.',
    ),
    FinderDslDefinition(
      name: 'ancestor',
      memberKind: FinderDslMemberKind.chain,
      finderType: 'Ancestor',
      mapping: FinderDslMappingKind.relation,
      arguments: [
        FinderDslArgumentMetadata(
          name: 'matching',
          kind: FinderDslArgumentKind.finder,
        ),
        FinderDslArgumentMetadata(
          name: 'matchRoot',
          kind: FinderDslArgumentKind.boolean,
          required: false,
        ),
        FinderDslArgumentMetadata(
          name: 'firstMatchOnly',
          kind: FinderDslArgumentKind.boolean,
          required: false,
        ),
      ],
      signature: 'ancestor(matching, matchRoot?, firstMatchOnly?)',
      description: 'Find an ancestor matching a nested finder.',
    ),
    FinderDslDefinition(
      name: 'containing',
      memberKind: FinderDslMemberKind.chain,
      finderType: 'Ancestor',
      mapping: FinderDslMappingKind.containing,
      arguments: [
        FinderDslArgumentMetadata(
          name: 'matching',
          kind: FinderDslArgumentKind.finder,
        ),
      ],
      signature: 'containing(matching)',
      description: 'Find the first ancestor containing a nested finder.',
    ),
    FinderDslDefinition(
      name: 'first',
      memberKind: FinderDslMemberKind.chain,
      finderType: 'ByMatchPosition',
      mapping: FinderDslMappingKind.matchPosition,
      arguments: [],
      signature: 'first()',
      description: 'Select the first match.',
      canonicalPosition: 'first',
    ),
    FinderDslDefinition(
      name: 'last',
      memberKind: FinderDslMemberKind.chain,
      finderType: 'ByMatchPosition',
      mapping: FinderDslMappingKind.matchPosition,
      arguments: [],
      signature: 'last()',
      description: 'Select the last match.',
      canonicalPosition: 'last',
    ),
    FinderDslDefinition(
      name: 'at',
      memberKind: FinderDslMemberKind.chain,
      finderType: 'ByMatchPosition',
      mapping: FinderDslMappingKind.matchPosition,
      arguments: [
        FinderDslArgumentMetadata(
          name: 'index',
          kind: FinderDslArgumentKind.integer,
        ),
      ],
      signature: 'at(index: int)',
      description: 'Select the match at a non-negative index.',
      canonicalPosition: 'index',
    ),
  ];

  static final List<FinderDslDefinition> all = _validate([...roots, ...chains]);

  static List<FinderDslDefinition> _validate(
    List<FinderDslDefinition> definitions,
  ) {
    final names = <String>{};
    final positions = <String>{};
    for (final definition in definitions) {
      if (!names.add(definition.name)) {
        throw StateError('Duplicate Finder DSL member "${definition.name}".');
      }

      var optionalSeen = false;
      for (final argument in definition.arguments) {
        if (!argument.required) optionalSeen = true;
        if (argument.required && optionalSeen) {
          throw StateError(
            'Required argument follows an optional argument in '
            '"${definition.name}".',
          );
        }
        if (argument.kind == FinderDslArgumentKind.enumValue &&
            argument.enumValues.isEmpty) {
          throw StateError(
            'Enum argument "${argument.name}" in "${definition.name}" '
            'has no values.',
          );
        }
      }

      final isPosition =
          definition.mapping == FinderDslMappingKind.matchPosition;
      if ((definition.canonicalPosition != null) != isPosition) {
        throw StateError(
          'Only match-position definitions may declare a canonical position.',
        );
      }
      if (definition.canonicalPosition != null &&
          !positions.add(definition.canonicalPosition!)) {
        throw StateError(
          'Duplicate canonical position "${definition.canonicalPosition}".',
        );
      }
      if ((definition.mapping == FinderDslMappingKind.relation ||
              definition.mapping == FinderDslMappingKind.containing) &&
          !definition.arguments.any(
            (argument) => argument.kind == FinderDslArgumentKind.finder,
          )) {
        throw StateError(
          'Relation definition "${definition.name}" needs a finder argument.',
        );
      }
    }
    return List.unmodifiable(definitions);
  }

  static FinderDslDefinition? find(
    String name, {
    FinderDslMemberKind? memberKind,
  }) {
    for (final definition in all) {
      if (definition.name == name &&
          (memberKind == null || definition.memberKind == memberKind)) {
        return definition;
      }
    }
    return null;
  }

  static List<FinderDslDefinition> forCanonicalType(String type) {
    return forFinderType(type);
  }

  static List<FinderDslDefinition> forFinderType(String finderType) {
    return List.unmodifiable(
      all.where((definition) => definition.finderType == finderType),
    );
  }

  static FinderDslDefinition? findByCanonicalPosition(String position) {
    for (final definition in all) {
      if (definition.canonicalPosition == position) return definition;
    }
    return null;
  }
}
