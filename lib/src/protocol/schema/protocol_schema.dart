import 'property_schema.dart';

enum ProtocolSchemaKind { finder, command }

enum ProtocolSchemaGroup { builtIn, custom }

extension ProtocolSchemaGroupLabel on ProtocolSchemaGroup {
  String get label => switch (this) {
    ProtocolSchemaGroup.builtIn => 'Built-in',
    ProtocolSchemaGroup.custom => 'Custom',
  };
}

class ProtocolSchema {
  const ProtocolSchema({
    required this.kind,
    required this.type,
    required this.description,
    required this.properties,
    required this.example,
    this.allowUnknownProperties = false,
    this.group = ProtocolSchemaGroup.builtIn,
  });

  final ProtocolSchemaKind kind;
  final String type;
  final String description;
  final Map<String, PropertySchema> properties;
  final Map<String, dynamic> example;
  final bool allowUnknownProperties;
  final ProtocolSchemaGroup group;

  String get discriminatorProperty => switch (kind) {
    ProtocolSchemaKind.finder => 'finderType',
    ProtocolSchemaKind.command => 'command',
  };
}
