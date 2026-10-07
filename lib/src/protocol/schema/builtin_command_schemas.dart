import 'command_schema.dart';
import 'property_schema.dart';

const _commandFinderField = PropertySchema(
  name: 'finder',
  types: [SchemaValueType.object],
  required: true,
  reference: SchemaReference.finder,
);

const _commandTextField = PropertySchema(
  name: 'text',
  types: [SchemaValueType.string],
  required: true,
);

const _commandTimeoutField = PropertySchema(
  name: 'timeout',
  types: [SchemaValueType.integer],
);

const _commandFinderExample = <String, dynamic>{
  'finderType': 'ByValueKey',
  'keyValueString': 'login_button',
  'keyValueType': 'String',
};

const List<CommandSchema> builtinCommandSchemas = [
  CommandSchema(
    type: 'tap',
    description: 'Tap the widget matched by a Finder.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'tap',
        hasConstantValue: true,
      ),
      'finder': _commandFinderField,
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'tap', 'finder': _commandFinderExample},
  ),
  CommandSchema(
    type: 'enter_text',
    description: 'Enter text into the currently focused text field.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'enter_text',
        hasConstantValue: true,
      ),
      'text': _commandTextField,
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'enter_text', 'text': 'hello'},
  ),
  CommandSchema(
    type: 'get_text',
    description: 'Read the text from the widget matched by a Finder.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'get_text',
        hasConstantValue: true,
      ),
      'finder': _commandFinderField,
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'get_text', 'finder': _commandFinderExample},
  ),
  CommandSchema(
    type: 'scroll',
    description: 'Scroll the widget matched by a Finder.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'scroll',
        hasConstantValue: true,
      ),
      'finder': _commandFinderField,
      'dx': PropertySchema(
        name: 'dx',
        types: [SchemaValueType.number],
        required: true,
      ),
      'dy': PropertySchema(
        name: 'dy',
        types: [SchemaValueType.number],
        required: true,
      ),
      'duration': PropertySchema(
        name: 'duration',
        types: [SchemaValueType.integer],
        required: true,
      ),
      'frequency': PropertySchema(
        name: 'frequency',
        types: [SchemaValueType.integer],
        required: true,
      ),
      'timeout': _commandTimeoutField,
    },
    example: {
      'command': 'scroll',
      'finder': _commandFinderExample,
      'dx': 0,
      'dy': 500,
      'duration': 300,
      'frequency': 30,
    },
  ),
  CommandSchema(
    type: 'scrollIntoView',
    description: 'Scroll until the widget matched by a Finder is visible.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'scrollIntoView',
        hasConstantValue: true,
      ),
      'finder': _commandFinderField,
      'alignment': PropertySchema(
        name: 'alignment',
        types: [SchemaValueType.number],
      ),
      'timeout': _commandTimeoutField,
    },
    example: {
      'command': 'scrollIntoView',
      'finder': _commandFinderExample,
      'alignment': 0.0,
    },
  ),
  CommandSchema(
    type: 'waitFor',
    description: 'Wait until a Finder matches a widget.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'waitFor',
        hasConstantValue: true,
      ),
      'finder': _commandFinderField,
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'waitFor', 'finder': _commandFinderExample},
  ),
  CommandSchema(
    type: 'waitForAbsent',
    description: 'Wait until a Finder no longer matches a widget.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'waitForAbsent',
        hasConstantValue: true,
      ),
      'finder': _commandFinderField,
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'waitForAbsent', 'finder': _commandFinderExample},
  ),
  CommandSchema(
    type: 'waitForTappable',
    description: 'Wait until a Finder matches a tappable widget.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'waitForTappable',
        hasConstantValue: true,
      ),
      'finder': _commandFinderField,
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'waitForTappable', 'finder': _commandFinderExample},
  ),
  CommandSchema(
    type: 'getCenter',
    description: 'Get the center point of a widget matched by a Finder.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'getCenter',
        hasConstantValue: true,
      ),
      'finder': _commandFinderField,
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'getCenter', 'finder': _commandFinderExample},
  ),
  CommandSchema(
    type: 'getTopLeft',
    description: 'Get the top-left point of a widget matched by a Finder.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'getTopLeft',
        hasConstantValue: true,
      ),
      'finder': _commandFinderField,
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'getTopLeft', 'finder': _commandFinderExample},
  ),
  CommandSchema(
    type: 'getTopRight',
    description: 'Get the top-right point of a widget matched by a Finder.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'getTopRight',
        hasConstantValue: true,
      ),
      'finder': _commandFinderField,
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'getTopRight', 'finder': _commandFinderExample},
  ),
  CommandSchema(
    type: 'getBottomRight',
    description: 'Get the bottom-right point of a widget matched by a Finder.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'getBottomRight',
        hasConstantValue: true,
      ),
      'finder': _commandFinderField,
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'getBottomRight', 'finder': _commandFinderExample},
  ),
  CommandSchema(
    type: 'request_data',
    description: 'Send a custom data message through Flutter Driver.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'request_data',
        hasConstantValue: true,
      ),
      'message': PropertySchema(
        name: 'message',
        types: [SchemaValueType.string],
        required: true,
      ),
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'request_data', 'message': 'system.ready'},
  ),
  CommandSchema(
    type: 'set_frame_sync',
    description: 'Enable or disable Flutter Driver frame synchronization.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'set_frame_sync',
        hasConstantValue: true,
      ),
      'enabled': PropertySchema(
        name: 'enabled',
        types: [SchemaValueType.boolean],
        required: true,
      ),
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'set_frame_sync', 'enabled': true},
  ),
  CommandSchema(
    type: 'get_health',
    description: 'Check whether the Flutter Driver extension is available.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'get_health',
        hasConstantValue: true,
      ),
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'get_health'},
  ),
  CommandSchema(
    type: 'set_text_entry_emulation',
    description: 'Enable or disable text entry emulation.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'set_text_entry_emulation',
        hasConstantValue: true,
      ),
      'enabled': PropertySchema(
        name: 'enabled',
        types: [SchemaValueType.boolean],
        required: true,
      ),
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'set_text_entry_emulation', 'enabled': true},
  ),
  CommandSchema(
    type: 'get_offset',
    description: 'Get a position of a widget matched by a Finder.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'get_offset',
        hasConstantValue: true,
      ),
      'finder': _commandFinderField,
      'offsetType': PropertySchema(
        name: 'offsetType',
        types: [SchemaValueType.string],
        required: true,
        enumValues: [
          'topLeft',
          'topRight',
          'bottomLeft',
          'bottomRight',
          'center',
        ],
      ),
      'timeout': _commandTimeoutField,
    },
    example: {
      'command': 'get_offset',
      'finder': _commandFinderExample,
      'offsetType': 'center',
    },
  ),
  CommandSchema(
    type: 'get_semantics_id',
    description: 'Get the semantics node id for a widget matched by a Finder.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'get_semantics_id',
        hasConstantValue: true,
      ),
      'finder': _commandFinderField,
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'get_semantics_id', 'finder': _commandFinderExample},
  ),
  CommandSchema(
    type: 'screenshot',
    description: 'Capture a screenshot from the running Flutter application.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'screenshot',
        hasConstantValue: true,
      ),
      'format': PropertySchema(
        name: 'format',
        types: [SchemaValueType.integer],
        required: true,
        enumValues: [0, 1, 2, 3, 4],
      ),
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'screenshot', 'format': 4},
  ),
  CommandSchema(
    type: 'set_semantics',
    description: 'Enable or disable semantics in the running application.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'set_semantics',
        hasConstantValue: true,
      ),
      'enabled': PropertySchema(
        name: 'enabled',
        types: [SchemaValueType.boolean],
        required: true,
      ),
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'set_semantics', 'enabled': true},
  ),
  CommandSchema(
    type: 'send_text_input_action',
    description: 'Send an action to the currently focused text input.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'send_text_input_action',
        hasConstantValue: true,
      ),
      'action': PropertySchema(
        name: 'action',
        types: [SchemaValueType.string],
        required: true,
      ),
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'send_text_input_action', 'action': 'done'},
  ),
  CommandSchema(
    type: 'get_layer_tree',
    description: 'Get a string representation of the layer tree.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'get_layer_tree',
        hasConstantValue: true,
      ),
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'get_layer_tree'},
  ),
  CommandSchema(
    type: 'get_render_tree',
    description: 'Get a string representation of the render tree.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'get_render_tree',
        hasConstantValue: true,
      ),
      'timeout': _commandTimeoutField,
    },
    example: {'command': 'get_render_tree'},
  ),
  CommandSchema(
    type: 'get_diagnostics_tree',
    description: 'Get diagnostics for a widget matched by a Finder.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'get_diagnostics_tree',
        hasConstantValue: true,
      ),
      'finder': _commandFinderField,
      'diagnosticsType': PropertySchema(
        name: 'diagnosticsType',
        types: [SchemaValueType.string],
        required: true,
        enumValues: ['renderObject', 'widget'],
      ),
      'subtreeDepth': PropertySchema(
        name: 'subtreeDepth',
        types: [SchemaValueType.integer],
        required: true,
      ),
      'includeProperties': PropertySchema(
        name: 'includeProperties',
        types: [SchemaValueType.boolean],
        required: true,
      ),
      'timeout': _commandTimeoutField,
    },
    example: {
      'command': 'get_diagnostics_tree',
      'finder': _commandFinderExample,
      'diagnosticsType': 'widget',
      'subtreeDepth': 0,
      'includeProperties': true,
    },
  ),
  CommandSchema(
    type: 'waitForCondition',
    description: 'Wait until a Flutter Driver condition is satisfied.',
    properties: {
      'command': PropertySchema(
        name: 'command',
        types: [SchemaValueType.string],
        required: true,
        constantValue: 'waitForCondition',
        hasConstantValue: true,
      ),
      'conditionName': PropertySchema(
        name: 'conditionName',
        types: [SchemaValueType.string],
        required: true,
      ),
      'timeout': _commandTimeoutField,
    },
    example: {
      'command': 'waitForCondition',
      'conditionName': 'NoTransientCallbacksCondition',
    },
  ),
];
