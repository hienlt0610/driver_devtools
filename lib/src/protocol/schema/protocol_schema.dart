import 'property_schema.dart';

enum ProtocolSchemaKind { finder, command }

class ProtocolSchema {
  const ProtocolSchema({
    required this.kind,
    required this.type,
    required this.description,
    required this.properties,
    required this.example,
    this.allowUnknownProperties = false,
  });

  final ProtocolSchemaKind kind;
  final String type;
  final String description;
  final Map<String, PropertySchema> properties;
  final Map<String, dynamic> example;
  final bool allowUnknownProperties;

  String get discriminatorProperty => switch (kind) {
    ProtocolSchemaKind.finder => 'finderType',
    ProtocolSchemaKind.command => 'command',
  };
}
