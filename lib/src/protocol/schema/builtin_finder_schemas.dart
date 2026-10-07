import 'finder_schema.dart';
import 'property_schema.dart';

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
