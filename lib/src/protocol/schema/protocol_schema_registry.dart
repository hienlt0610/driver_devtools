import 'builtin_command_schemas.dart';
import 'builtin_finder_schemas.dart';
import 'command_schema.dart';
import 'finder_schema.dart';
import 'protocol_schema.dart';
import 'property_schema.dart';

class ProtocolSchemaValidationResult {
  const ProtocolSchemaValidationResult({
    this.schema,
    this.errors = const [],
    this.messages = const [],
  });

  final ProtocolSchema? schema;
  final List<String> errors;
  final List<String> messages;

  bool get isValid => errors.isEmpty;
  bool get hasSchema => schema != null;
  bool get canExecute => isValid;
}

class ProtocolSchemaRegistry {
  ProtocolSchemaRegistry({
    Iterable<FinderSchema> finderSchemas = const [],
    Iterable<CommandSchema> commandSchemas = const [],
  }) {
    for (final schema in finderSchemas) {
      registerFinder(schema);
    }
    for (final schema in commandSchemas) {
      registerCommand(schema);
    }
  }

  static final ProtocolSchemaRegistry builtIn = ProtocolSchemaRegistry(
    finderSchemas: builtinFinderSchemas,
    commandSchemas: builtinCommandSchemas,
  );

  factory ProtocolSchemaRegistry.withBuiltIns() {
    return ProtocolSchemaRegistry(
      finderSchemas: builtinFinderSchemas,
      commandSchemas: builtinCommandSchemas,
    );
  }

  final _finders = <String, FinderSchema>{};
  final _commands = <String, CommandSchema>{};

  List<FinderSchema> get finderSchemas => List.unmodifiable(_finders.values);
  List<CommandSchema> get commandSchemas => List.unmodifiable(_commands.values);

  FinderSchema? findFinder(String type) => _finders[type];

  CommandSchema? findCommand(String type) => _commands[type];

  void registerFinder(FinderSchema schema, {bool replace = true}) {
    if (replace || !_finders.containsKey(schema.type)) {
      _finders[schema.type] = schema;
    }
  }

  void registerCommand(CommandSchema schema, {bool replace = true}) {
    if (replace || !_commands.containsKey(schema.type)) {
      _commands[schema.type] = schema;
    }
  }

  void merge({
    Iterable<FinderSchema> finders = const [],
    Iterable<CommandSchema> commands = const [],
    bool replace = true,
  }) {
    for (final schema in finders) {
      registerFinder(schema, replace: replace);
    }
    for (final schema in commands) {
      registerCommand(schema, replace: replace);
    }
  }

  ProtocolSchemaValidationResult validateFinderPayload(
    Map<String, dynamic> payload,
  ) {
    final errors = <String>[];
    final messages = <String>[];
    final schema = _validateDiscriminatedPayload(
      payload,
      discriminator: 'finderType',
      lookup: (type) => _finders[type],
      errors: errors,
      messages: messages,
    );
    return ProtocolSchemaValidationResult(
      schema: schema,
      errors: List.unmodifiable(errors),
      messages: List.unmodifiable(messages),
    );
  }

  ProtocolSchemaValidationResult validateCommandPayload(
    Map<String, dynamic> payload,
  ) {
    final errors = <String>[];
    final messages = <String>[];
    final schema = _validateDiscriminatedPayload(
      payload,
      discriminator: 'command',
      lookup: (type) => _commands[type],
      errors: errors,
      messages: messages,
    );
    return ProtocolSchemaValidationResult(
      schema: schema,
      errors: List.unmodifiable(errors),
      messages: List.unmodifiable(messages),
    );
  }

  ProtocolSchema? _validateDiscriminatedPayload(
    Map<String, dynamic> payload, {
    required String discriminator,
    required ProtocolSchema? Function(String type) lookup,
    required List<String> errors,
    required List<String> messages,
    String path = '',
  }) {
    if (!payload.containsKey(discriminator)) {
      errors.add('Missing required property: ${_path(path, discriminator)}');
      return null;
    }

    final type = payload[discriminator];
    if (type is! String) {
      errors.add(
        'Invalid type for ${_path(path, discriminator)}. Expected: String.',
      );
      return null;
    }

    final schema = lookup(type);
    if (schema == null) {
      messages.add(_schemaUnavailable(type));
      return null;
    }

    _validateObject(payload, schema, path, errors, messages);
    return schema;
  }

  void _validateObject(
    Map<String, dynamic> payload,
    ProtocolSchema schema,
    String path,
    List<String> errors,
    List<String> messages,
  ) {
    _validateProperties(
      payload,
      schema.properties,
      schema.allowUnknownProperties,
      path,
      errors,
      messages,
    );
  }

  void _validateProperties(
    Map<String, dynamic> payload,
    Map<String, PropertySchema> properties,
    bool allowUnknownProperties,
    String path,
    List<String> errors,
    List<String> messages,
  ) {
    for (final property in properties.values) {
      if (property.required && !payload.containsKey(property.name)) {
        errors.add('Missing required property: ${_path(path, property.name)}');
      }
    }

    for (final entry in payload.entries) {
      final property = properties[entry.key];
      if (property == null) {
        if (!allowUnknownProperties) {
          errors.add('Unknown property: ${_path(path, entry.key)}');
        }
        continue;
      }
      _validateProperty(
        entry.value,
        property,
        _path(path, entry.key),
        errors,
        messages,
      );
    }
  }

  void _validateProperty(
    Object? value,
    PropertySchema property,
    String path,
    List<String> errors,
    List<String> messages,
  ) {
    if (!_matchesType(value, property.types)) {
      errors.add(
        'Invalid type for $path. Expected: ${property.typeLabel}. '
        'Received: ${_displayValue(value)}',
      );
      return;
    }

    if (property.hasConstantValue && value != property.constantValue) {
      errors.add(
        'Invalid value for $path.\n'
        'Expected: ${_displayValue(property.constantValue)}\n'
        'Received: ${_displayValue(value)}',
      );
      return;
    }

    if (property.enumValues.isNotEmpty &&
        !property.enumValues.contains(value)) {
      errors.add(
        'Invalid value for $path.\n'
        'Expected: ${property.enumValues.map(_displayValue).join(' | ')}\n'
        'Received: ${_displayValue(value)}',
      );
      return;
    }

    if (property.reference == SchemaReference.finder && value is Map) {
      final nestedPayload = _asJsonObject(value);
      if (nestedPayload == null) {
        return;
      }
      _validateDiscriminatedPayload(
        nestedPayload,
        discriminator: 'finderType',
        lookup: (type) => _finders[type],
        errors: errors,
        messages: messages,
        path: path,
      );
      return;
    }

    if (property.nestedProperties != null && value is Map) {
      final nestedPayload = _asJsonObject(value);
      if (nestedPayload == null) {
        return;
      }
      _validateProperties(
        nestedPayload,
        property.nestedProperties!,
        property.nestedAllowUnknownProperties,
        path,
        errors,
        messages,
      );
    }
  }

  bool _matchesType(Object? value, List<SchemaValueType> types) {
    if (types.contains(SchemaValueType.any)) return true;
    return types.any((type) {
      return switch (type) {
        SchemaValueType.any => true,
        SchemaValueType.string => value is String,
        SchemaValueType.integer => value is int,
        SchemaValueType.number => value is num,
        SchemaValueType.boolean => value is bool,
        SchemaValueType.object => value is Map,
        SchemaValueType.array => value is List,
        SchemaValueType.nullValue => value == null,
      };
    });
  }

  Map<String, dynamic>? _asJsonObject(Map value) {
    if (value.keys.any((key) => key is! String)) return null;
    return value.map((key, value) => MapEntry(key as String, value));
  }

  String _path(String prefix, String property) {
    return prefix.isEmpty ? property : '$prefix.$property';
  }

  String _schemaUnavailable(String type) {
    return 'Schema unavailable for "$type". Raw execution is allowed.';
  }

  String _displayValue(Object? value) {
    if (value is String) return value;
    if (value == null) return 'null';
    return value.toString();
  }
}
