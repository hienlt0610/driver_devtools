import 'protocol_schema.dart';

class CommandSchema extends ProtocolSchema {
  const CommandSchema({
    required super.type,
    required super.description,
    required super.properties,
    required super.example,
    super.allowUnknownProperties,
  }) : super(kind: ProtocolSchemaKind.command);
}
