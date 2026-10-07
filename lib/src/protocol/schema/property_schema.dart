enum SchemaValueType {
  any,
  string,
  integer,
  number,
  boolean,
  object,
  array,
  nullValue,
}

enum SchemaReference { finder }

extension SchemaValueTypeLabel on SchemaValueType {
  String get label => switch (this) {
    SchemaValueType.any => 'Any',
    SchemaValueType.string => 'String',
    SchemaValueType.integer => 'int',
    SchemaValueType.number => 'number',
    SchemaValueType.boolean => 'bool',
    SchemaValueType.object => 'object',
    SchemaValueType.array => 'array',
    SchemaValueType.nullValue => 'null',
  };
}

class PropertySchema {
  const PropertySchema({
    required this.name,
    required this.types,
    this.description,
    this.required = false,
    this.enumValues = const [],
    this.constantValue,
    bool? hasConstantValue,
    this.reference,
    this.nestedProperties,
    this.nestedAllowUnknownProperties = false,
  }) : hasConstantValue = hasConstantValue ?? constantValue != null;

  final String name;
  final List<SchemaValueType> types;
  final String? description;
  final bool required;
  final List<Object?> enumValues;
  final Object? constantValue;
  final bool hasConstantValue;
  final SchemaReference? reference;
  final Map<String, PropertySchema>? nestedProperties;
  final bool nestedAllowUnknownProperties;

  String get typeLabel => types.map((type) => type.label).join(' | ');
}
