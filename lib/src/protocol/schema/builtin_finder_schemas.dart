import 'finder_schema.dart';
import 'property_schema.dart';
import 'protocol_schema.dart';

const List<FinderSchema> builtinFinderSchemas = [
  FinderSchema(
    type: 'ByValueKey',
    description: 'Find widget by ValueKey.',
    properties: {
      'finderType': PropertySchema(
        name: 'finderType',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'ByValueKey',
        hasConstantValue: true,
      ),
      'keyValueString': PropertySchema(
        name: 'keyValueString',
        types: [SchemaValueType.string],
        required: true,
      ),
      'keyValueType': PropertySchema(
        name: 'keyValueType',
        types: [SchemaValueType.string],
        required: true,
        enumValues: ['String', 'int'],
      ),
    },
    example: {
      'finderType': 'ByValueKey',
      'keyValueString': 'login_button',
      'keyValueType': 'String',
    },
  ),
  FinderSchema(
    type: 'ByText',
    description: 'Find widget by its visible text.',
    properties: {
      'finderType': PropertySchema(
        name: 'finderType',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'ByText',
        hasConstantValue: true,
      ),
      'text': PropertySchema(
        name: 'text',
        types: [SchemaValueType.string],
        required: true,
      ),
    },
    example: {'finderType': 'ByText', 'text': 'Login'},
  ),
  FinderSchema(
    type: 'ByTextMatch',
    description:
        'Find widget by text using contains, startsWith, endsWith, or regex.',
    group: ProtocolSchemaGroup.custom,
    properties: {
      'finderType': PropertySchema(
        name: 'finderType',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'ByTextMatch',
        hasConstantValue: true,
      ),
      'text': PropertySchema(
        name: 'text',
        types: [SchemaValueType.string],
        required: true,
      ),
      'matchType': PropertySchema(
        name: 'matchType',
        types: [SchemaValueType.string],
        required: true,
        enumValues: ['contains', 'startsWith', 'endsWith', 'regex'],
      ),
      'ignoreCase': PropertySchema(
        name: 'ignoreCase',
        types: [SchemaValueType.boolean],
        description: 'Whether matching ignores case. Defaults to false.',
      ),
    },
    example: {
      'finderType': 'ByTextMatch',
      'text': 'Order #',
      'matchType': 'contains',
      'ignoreCase': false,
    },
  ),
  FinderSchema(
    type: 'ByType',
    description: 'Find widget by its runtime type name.',
    properties: {
      'finderType': PropertySchema(
        name: 'finderType',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'ByType',
        hasConstantValue: true,
      ),
      'type': PropertySchema(
        name: 'type',
        types: [SchemaValueType.string],
        required: true,
      ),
    },
    example: {'finderType': 'ByType', 'type': 'ElevatedButton'},
  ),
  FinderSchema(
    type: 'ByTooltip',
    description: 'Find widget by its tooltip text.',
    properties: {
      'finderType': PropertySchema(
        name: 'finderType',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'ByTooltip',
        hasConstantValue: true,
      ),
      'text': PropertySchema(
        name: 'text',
        types: [SchemaValueType.string],
        required: true,
      ),
    },
    example: {'finderType': 'ByTooltip', 'text': 'Open menu'},
  ),
  FinderSchema(
    type: 'ByTooltipMessage',
    description: 'Find widget by its tooltip message.',
    properties: {
      'finderType': PropertySchema(
        name: 'finderType',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'ByTooltipMessage',
        hasConstantValue: true,
      ),
      'text': PropertySchema(
        name: 'text',
        types: [SchemaValueType.string],
        required: true,
      ),
    },
    example: {'finderType': 'ByTooltipMessage', 'text': 'Open menu'},
  ),
  FinderSchema(
    type: 'BySemanticsLabel',
    description: 'Find widget by its semantics label.',
    properties: {
      'finderType': PropertySchema(
        name: 'finderType',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'BySemanticsLabel',
        hasConstantValue: true,
      ),
      'label': PropertySchema(
        name: 'label',
        types: [SchemaValueType.string],
        required: true,
      ),
      'isRegExp': PropertySchema(
        name: 'isRegExp',
        types: [SchemaValueType.boolean],
      ),
    },
    example: {
      'finderType': 'BySemanticsLabel',
      'label': 'Log in',
      'isRegExp': false,
    },
  ),
  FinderSchema(
    type: 'BySemanticsIdentifier',
    description:
        'Find a widget by exact Semantics.identifier, not Semantics.label.',
    group: ProtocolSchemaGroup.custom,
    properties: {
      'finderType': PropertySchema(
        name: 'finderType',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'BySemanticsIdentifier',
        hasConstantValue: true,
      ),
      'identifier': PropertySchema(
        name: 'identifier',
        types: [SchemaValueType.string],
        required: true,
        description: 'Required and must not be empty.',
      ),
    },
    example: {
      'finderType': 'BySemanticsIdentifier',
      'identifier': 'checkout.submit',
    },
  ),
  FinderSchema(
    type: 'Ancestor',
    description: 'Find ancestors of one finder matching another finder.',
    properties: {
      'finderType': PropertySchema(
        name: 'finderType',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'Ancestor',
        hasConstantValue: true,
      ),
      'of': PropertySchema(
        name: 'of',
        types: [SchemaValueType.object],
        required: true,
        reference: SchemaReference.finder,
      ),
      'matching': PropertySchema(
        name: 'matching',
        types: [SchemaValueType.object],
        required: true,
        reference: SchemaReference.finder,
      ),
      'matchRoot': PropertySchema(
        name: 'matchRoot',
        types: [SchemaValueType.boolean],
      ),
      'firstMatchOnly': PropertySchema(
        name: 'firstMatchOnly',
        types: [SchemaValueType.boolean],
      ),
    },
    example: {
      'finderType': 'Ancestor',
      'of': {'finderType': 'ByText', 'text': 'Login'},
      'matching': {'finderType': 'ByType', 'type': 'Card'},
      'matchRoot': false,
      'firstMatchOnly': true,
    },
  ),
  FinderSchema(
    type: 'Descendant',
    description: 'Find descendants of one finder matching another finder.',
    properties: {
      'finderType': PropertySchema(
        name: 'finderType',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'Descendant',
        hasConstantValue: true,
      ),
      'of': PropertySchema(
        name: 'of',
        types: [SchemaValueType.object],
        required: true,
        reference: SchemaReference.finder,
      ),
      'matching': PropertySchema(
        name: 'matching',
        types: [SchemaValueType.object],
        required: true,
        reference: SchemaReference.finder,
      ),
      'matchRoot': PropertySchema(
        name: 'matchRoot',
        types: [SchemaValueType.boolean],
      ),
      'firstMatchOnly': PropertySchema(
        name: 'firstMatchOnly',
        types: [SchemaValueType.boolean],
      ),
    },
    example: {
      'finderType': 'Descendant',
      'of': {'finderType': 'ByType', 'type': 'ListView'},
      'matching': {'finderType': 'ByText', 'text': 'Settings'},
      'matchRoot': false,
      'firstMatchOnly': true,
    },
  ),
  FinderSchema(
    type: 'ByMatchPosition',
    description: 'Select the first, last, or zero-based indexed match.',
    group: ProtocolSchemaGroup.custom,
    properties: {
      'finderType': PropertySchema(
        name: 'finderType',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'ByMatchPosition',
        hasConstantValue: true,
      ),
      'position': PropertySchema(
        name: 'position',
        types: [SchemaValueType.string],
        required: true,
        enumValues: ['first', 'index', 'last'],
      ),
      'index': PropertySchema(
        name: 'index',
        types: [SchemaValueType.integer],
        description:
            'Required for position "index"; zero-based and must not be negative.',
      ),
      'of': PropertySchema(
        name: 'of',
        types: [SchemaValueType.object],
        required: true,
        reference: SchemaReference.finder,
      ),
    },
    example: {
      'finderType': 'ByMatchPosition',
      'position': 'index',
      'index': 2,
      'of': {'finderType': 'ByType', 'type': 'OrderCard'},
    },
  ),
  FinderSchema(
    type: 'PageBack',
    description: 'Find the current page back control.',
    properties: {
      'finderType': PropertySchema(
        name: 'finderType',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'PageBack',
        hasConstantValue: true,
      ),
    },
    example: {'finderType': 'PageBack'},
  ),
];
