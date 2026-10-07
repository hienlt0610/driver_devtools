import 'package:driver_devtools/src/protocol/schema/command_schema.dart';
import 'package:driver_devtools/src/protocol/schema/finder_schema.dart';
import 'package:driver_devtools/src/protocol/schema/property_schema.dart';
import 'package:driver_devtools/src/protocol/schema/protocol_schema_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProtocolSchemaRegistry', () {
    late ProtocolSchemaRegistry registry;

    setUp(() {
      registry = ProtocolSchemaRegistry.withBuiltIns();
    });

    test('exposes the built-in ByValueKey schema as documentation', () {
      final schema = registry.findFinder('ByValueKey');

      expect(schema, isNotNull);
      expect(schema!.description, 'Find widget by ValueKey.');
      expect(schema.properties['finderType']!.required, isTrue);
      expect(schema.properties['finderType']!.constantValue, 'ByValueKey');
      expect(schema.properties['keyValueString']!.types, [
        SchemaValueType.string,
      ]);
      expect(schema.properties['keyValueType']!.enumValues, ['String', 'int']);
      expect(schema.example['keyValueString'], 'login_button');
    });

    test('reports missing required finder fields', () {
      final result = registry.validateFinderPayload({
        'finderType': 'ByValueKey',
        'keyValueString': 'login_button',
      });

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        contains('Missing required property: keyValueType'),
      );
    });

    test(
      'reports enum violations with the expected values and received value',
      () {
        final result = registry.validateFinderPayload({
          'finderType': 'ByValueKey',
          'keyValueString': 'login_button',
          'keyValueType': 'foo',
        });

        expect(result.isValid, isFalse);
        expect(
          result.errors,
          contains(
            'Invalid value for keyValueType.\n'
            'Expected: String | int\n'
            'Received: foo',
          ),
        );
      },
    );

    test('reports constants, types, and unknown properties', () {
      final result = registry.validateFinderPayload({
        'finderType': 'ByText',
        'text': 42,
        'unexpected': true,
      });

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        contains('Invalid type for text. Expected: String.'),
      );
      expect(result.errors, contains('Unknown property: unexpected'));

      final constantResult = registry.validateFinderPayload({
        'finderType': 'ByValueKey',
        'keyValueString': 'login_button',
        'keyValueType': 'String',
      });
      expect(constantResult.isValid, isTrue);
    });

    test('validates a nested finder inside a command', () {
      final result = registry.validateCommandPayload({
        'command': 'tap',
        'finder': {
          'finderType': 'ByValueKey',
          'keyValueString': 'login_button',
        },
      });

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        contains('Missing required property: finder.keyValueType'),
      );
    });

    test('allows raw execution when a finder schema is unavailable', () {
      final result = registry.validateFinderPayload({
        'finderType': 'CustomFinder',
        'foo': 'bar',
      });

      expect(result.isValid, isTrue);
      expect(result.schema, isNull);
      expect(
        result.messages,
        contains(
          'Schema unavailable for "CustomFinder". Raw execution is allowed.',
        ),
      );
    });

    test('allows raw execution when a command schema is unavailable', () {
      final result = registry.validateCommandPayload({
        'command': 'custom_command',
        'foo': 'bar',
      });

      expect(result.isValid, isTrue);
      expect(result.schema, isNull);
      expect(result.messages.single, contains('custom_command'));
    });

    test('supports registering schemas from an external source', () {
      const customSchema = FinderSchema(
        type: 'CustomFinder',
        description: 'A runtime finder.',
        properties: {
          'finderType': PropertySchema(
            name: 'finderType',
            types: [SchemaValueType.string],
            required: true,
            constantValue: 'CustomFinder',
            hasConstantValue: true,
          ),
        },
        example: {'finderType': 'CustomFinder'},
      );

      registry.registerFinder(customSchema);

      expect(registry.findFinder('CustomFinder'), same(customSchema));
      expect(
        registry.validateFinderPayload({'finderType': 'CustomFinder'}).isValid,
        isTrue,
      );
    });

    test('lists built-in command schemas', () {
      expect(registry.findCommand('tap'), isA<CommandSchema>());
      expect(registry.findCommand('enter_text'), isA<CommandSchema>());
      expect(
        registry.commandSchemas.map((schema) => schema.type),
        contains('scroll'),
      );
    });
  });
}
