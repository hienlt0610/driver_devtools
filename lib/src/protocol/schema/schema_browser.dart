import 'dart:convert';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'protocol_schema.dart';
import 'protocol_schema_registry.dart';
import 'property_schema.dart';

class SchemaBrowserDialog extends StatefulWidget {
  const SchemaBrowserDialog({
    required this.kind,
    required this.registry,
    required this.onUseExample,
    super.key,
  });

  final ProtocolSchemaKind kind;
  final ProtocolSchemaRegistry registry;
  final ValueChanged<String> onUseExample;

  @override
  State<SchemaBrowserDialog> createState() => _SchemaBrowserDialogState();
}

class _SchemaBrowserDialogState extends State<SchemaBrowserDialog> {
  int _selectedIndex = 0;

  List<ProtocolSchema> get _schemas {
    final registeredSchemas = switch (widget.kind) {
      ProtocolSchemaKind.finder => widget.registry.finderSchemas,
      ProtocolSchemaKind.command => widget.registry.commandSchemas,
    };
    return [
      for (final group in ProtocolSchemaGroup.values)
        ...registeredSchemas.where((schema) => schema.group == group),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final schemas = _schemas;
    final selectedSchema =
        schemas.isEmpty
            ? null
            : schemas[_selectedIndex.clamp(0, schemas.length - 1)];
    final title =
        widget.kind == ProtocolSchemaKind.finder
            ? 'Finder Schemas'
            : 'Command Schemas';
    final size = MediaQuery.sizeOf(context);
    final groupedSchemas = <ProtocolSchemaGroup, List<ProtocolSchema>>{};
    for (final schema in schemas) {
      groupedSchemas.putIfAbsent(schema.group, () => []).add(schema);
    }
    var schemaIndex = 0;
    final schemaListItems = <Widget>[];
    for (final group in ProtocolSchemaGroup.values) {
      final groupSchemas = groupedSchemas[group];
      if (groupSchemas == null || groupSchemas.isEmpty) continue;

      schemaListItems.add(
        Padding(
          padding: EdgeInsets.only(top: schemaListItems.isEmpty ? 0 : 12),
          child: Text(
            group.label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      );
      schemaListItems.add(const SizedBox(height: 8));
      for (final schema in groupSchemas) {
        final index = schemaIndex++;
        schemaListItems.add(
          ListTile(
            key: ValueKey<String>(
              'driver_automation.schema_item_${schema.type}',
            ),
            dense: true,
            selected: index == _selectedIndex,
            title: Text(schema.type),
            onTap: () => setState(() => _selectedIndex = index),
          ),
        );
      }
    }

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: size.width < 900 ? size.width * .78 : 820,
        height: size.height < 700 ? size.height * .68 : 540,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 210,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ListView(children: schemaListItems)),
                ],
              ),
            ),
            const VerticalDivider(width: 24),
            Expanded(
              child:
                  selectedSchema == null
                      ? Center(
                        child: Text(
                          'No schemas registered.',
                          style: Theme.of(context).subtleTextStyle,
                        ),
                      )
                      : _SchemaDetails(
                        schema: selectedSchema,
                        onUseExample: widget.onUseExample,
                      ),
            ),
          ],
        ),
      ),
      actions: [
        DevToolsButton(
          key: const ValueKey<String>(
            'driver_automation.schema_browser_close_button',
          ),
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _SchemaDetails extends StatelessWidget {
  const _SchemaDetails({required this.schema, required this.onUseExample});

  final ProtocolSchema schema;
  final ValueChanged<String> onUseExample;

  @override
  Widget build(BuildContext context) {
    final requiredProperties =
        schema.properties.values
            .where((property) => property.required)
            .toList();
    final optionalProperties =
        schema.properties.values
            .where((property) => !property.required)
            .toList();
    final example = const JsonEncoder.withIndent('  ').convert(schema.example);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            schema.type,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(schema.description),
          const SizedBox(height: 20),
          Text(
            'Required fields',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final property in requiredProperties)
            _PropertyDetails(property: property),
          if (optionalProperties.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Optional fields',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final property in optionalProperties)
              _PropertyDetails(property: property),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Example JSON',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              DevToolsButton(
                key: const ValueKey<String>(
                  'driver_automation.schema_copy_button',
                ),
                icon: Icons.copy,
                label: 'Copy',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: example));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Example copied.')),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              DevToolsButton(
                key: const ValueKey<String>(
                  'driver_automation.schema_use_example_button',
                ),
                icon: Icons.input,
                label: 'Use this',
                onPressed: () {
                  onUseExample(example);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              example,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Example is inserted into the editor when you use it.',
            style: Theme.of(context).subtleTextStyle,
          ),
        ],
      ),
    );
  }
}

class _PropertyDetails extends StatelessWidget {
  const _PropertyDetails({required this.property});

  final PropertySchema property;

  @override
  Widget build(BuildContext context) {
    final details = <String>[];
    if (property.hasConstantValue) {
      details.add('constant: ${jsonEncode(property.constantValue)}');
    }
    if (property.enumValues.isNotEmpty) {
      details.add(
        'enum: ${property.enumValues.map(_displayEnumValue).join(' | ')}',
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            property.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(property.typeLabel),
          for (final detail in details)
            Text(detail, style: Theme.of(context).subtleTextStyle),
          if (property.description case final description?)
            Text(description, style: Theme.of(context).subtleTextStyle),
        ],
      ),
    );
  }

  String _displayEnumValue(Object? value) {
    return value is String ? value : jsonEncode(value);
  }
}
