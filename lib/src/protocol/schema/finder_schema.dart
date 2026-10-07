import 'protocol_schema.dart';

class FinderSchema extends ProtocolSchema {
  const FinderSchema({
    required super.type,
    required super.description,
    required super.properties,
    required super.example,
    super.allowUnknownProperties,
    super.group,
  }) : super(kind: ProtocolSchemaKind.finder);
}
