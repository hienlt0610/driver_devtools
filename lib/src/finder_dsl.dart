import 'dart:convert';

import 'finder_dsl_metadata.dart';
import 'protocol/schema/protocol_schema_registry.dart';

/// The parsed, temporary representation of a Finder DSL expression.
class FinderAst {
  FinderAst(
    this.name,
    Iterable<FinderAstValue> arguments, {
    Iterable<FinderAstCall> chain = const [],
  }) : arguments = List.unmodifiable(arguments),
       chain = List.unmodifiable(chain);

  final String name;
  final List<FinderAstValue> arguments;
  final List<FinderAstCall> chain;

  FinderAst append(FinderAstCall call) {
    return FinderAst(name, arguments, chain: [...chain, call]);
  }
}

class FinderAstCall {
  FinderAstCall(this.name, Iterable<FinderAstValue> arguments)
    : arguments = List.unmodifiable(arguments);

  final String name;
  final List<FinderAstValue> arguments;
}

sealed class FinderAstValue {
  const FinderAstValue();
}

class FinderAstStringValue extends FinderAstValue {
  const FinderAstStringValue(this.value);

  final String value;
}

class FinderAstIntegerValue extends FinderAstValue {
  const FinderAstIntegerValue(this.value);

  final int value;
}

class FinderAstBooleanValue extends FinderAstValue {
  const FinderAstBooleanValue(this.value);

  final bool value;
}

class FinderAstEnumValue extends FinderAstValue {
  const FinderAstEnumValue(this.value);

  final String value;
}

class FinderAstExpressionValue extends FinderAstValue {
  const FinderAstExpressionValue(this.value);

  final FinderAst value;
}

class FinderDslException implements Exception {
  const FinderDslException(
    this.message, {
    this.offset = 0,
    this.line = 1,
    this.column = 1,
    this.path,
  });

  final String message;
  final int offset;
  final int line;
  final int column;
  final String? path;

  @override
  String toString() {
    final location = 'Line $line, Column $column';
    final field = path == null ? '' : ' at $path';
    return '$message$field ($location)';
  }
}

class FinderDslParser {
  const FinderDslParser._();

  static FinderAst parse(String source) {
    return _FinderDslParser(source).parse();
  }
}

class FinderDslCodec {
  const FinderDslCodec._();

  static Map<String, dynamic> toCanonical(
    FinderAst ast, {
    ProtocolSchemaRegistry? registry,
  }) {
    final canonical = _lowerExpression(ast);
    _validateCanonical(canonical, registry ?? ProtocolSchemaRegistry.builtIn);
    return canonical;
  }

  static FinderAst fromCanonical(
    Map<String, dynamic> canonical, {
    ProtocolSchemaRegistry? registry,
  }) {
    final schemaRegistry = registry ?? ProtocolSchemaRegistry.builtIn;
    _validateCanonical(canonical, schemaRegistry);
    return _fromCanonical(canonical);
  }

  static void _validateCanonical(
    Map<String, dynamic> canonical,
    ProtocolSchemaRegistry registry,
  ) {
    final result = registry.validateFinderPayload(canonical);
    if (!result.isValid) {
      throw FinderDslException(
        result.errors.join('\n'),
        path: result.errors.first.split(':').first,
      );
    }
    if (!result.hasSchema) {
      final type = canonical['finderType'];
      throw FinderDslException(
        'Finder type "$type" is not representable in the DSL.',
        path: 'finderType',
      );
    }
  }

  static Map<String, dynamic> _lowerExpression(FinderAst ast) {
    var canonical = _lowerRoot(ast.name, ast.arguments);
    for (final call in ast.chain) {
      canonical = _lowerChain(canonical, call);
    }
    return canonical;
  }

  static Map<String, dynamic> _lowerRoot(
    String name,
    List<FinderAstValue> arguments,
  ) {
    final definition = _definition(name, FinderDslMemberKind.root);
    _validateArguments(definition, arguments);
    switch (definition.mapping) {
      case FinderDslMappingKind.byType:
        return {
          'finderType': definition.finderType,
          'type': _stringArgument(definition, arguments, 0),
        };
      case FinderDslMappingKind.valueKey:
        final value = arguments.single;
        return switch (value) {
          FinderAstStringValue() => {
            'finderType': definition.finderType,
            'keyValueString': value.value,
            'keyValueType': 'String',
          },
          FinderAstIntegerValue() => {
            'finderType': definition.finderType,
            'keyValueString': value.value.toString(),
            'keyValueType': 'int',
          },
          _ => throw _argumentError(definition.name, 0, 'a string or integer'),
        };
      case FinderDslMappingKind.byText:
        final result = <String, dynamic>{
          'finderType': definition.finderType,
          'text': _stringArgument(definition, arguments, 0),
        };
        if (arguments.length >= 2) {
          result['matchType'] = _enumArgument(definition, arguments, 1);
        }
        if (arguments.length == 3) {
          result['ignoreCase'] = _boolArgument(definition, arguments, 2);
        }
        return result;
      case FinderDslMappingKind.semanticsLabel:
        final result = <String, dynamic>{
          'finderType': definition.finderType,
          'label': _stringArgument(definition, arguments, 0),
        };
        if (arguments.length == 2) {
          result['isRegExp'] = _boolArgument(definition, arguments, 1);
        }
        return result;
      case FinderDslMappingKind.semanticsIdentifier:
        return {
          'finderType': definition.finderType,
          'identifier': _stringArgument(definition, arguments, 0),
        };
      case FinderDslMappingKind.tooltipMessage:
      case FinderDslMappingKind.tooltip:
        return {
          'finderType': definition.finderType,
          'text': _stringArgument(definition, arguments, 0),
        };
      case FinderDslMappingKind.pageBack:
        return {'finderType': definition.finderType};
      case FinderDslMappingKind.relation:
      case FinderDslMappingKind.containing:
      case FinderDslMappingKind.matchPosition:
        throw FinderDslException('Unsupported finder function "$name".');
    }
  }

  static Map<String, dynamic> _lowerChain(
    Map<String, dynamic> base,
    FinderAstCall call,
  ) {
    final definition = _definition(call.name, FinderDslMemberKind.chain);
    _validateArguments(definition, call.arguments);
    switch (definition.mapping) {
      case FinderDslMappingKind.relation:
        final matching = _lowerExpression(
          _finderArgument(definition, call.arguments, 0),
        );
        final result = <String, dynamic>{
          'finderType': definition.finderType,
          'of': base,
          'matching': matching,
        };
        if (call.arguments.length == 3) {
          result['matchRoot'] = _boolArgument(definition, call.arguments, 1);
          result['firstMatchOnly'] = _boolArgument(
            definition,
            call.arguments,
            2,
          );
        }
        return result;
      case FinderDslMappingKind.containing:
        return {
          'finderType': definition.finderType,
          'of': _lowerExpression(
            _finderArgument(definition, call.arguments, 0),
          ),
          'matching': base,
          'matchRoot': false,
          'firstMatchOnly': true,
        };
      case FinderDslMappingKind.matchPosition:
        final position = definition.canonicalPosition;
        if (position == 'index') {
          final index = _integerArgument(definition, call.arguments, 0);
          if (index < 0) {
            throw _argumentError(definition.name, 0, 'a non-negative integer');
          }
          return {
            'finderType': definition.finderType,
            'position': position,
            'index': index,
            'of': base,
          };
        }
        return {
          'finderType': definition.finderType,
          'position': position,
          'of': base,
        };
      case FinderDslMappingKind.byType:
      case FinderDslMappingKind.valueKey:
      case FinderDslMappingKind.byText:
      case FinderDslMappingKind.semanticsLabel:
      case FinderDslMappingKind.semanticsIdentifier:
      case FinderDslMappingKind.tooltipMessage:
      case FinderDslMappingKind.tooltip:
      case FinderDslMappingKind.pageBack:
        throw FinderDslException('Unsupported finder method "${call.name}".');
    }
  }

  static FinderAst _fromCanonical(Map<String, dynamic> finder) {
    final type = finder['finderType'];
    if (type is! String) {
      throw const FinderDslException(
        'Finder property "finderType" must be a string.',
        path: 'finderType',
      );
    }

    final definitions = FinderDslMetadataRegistry.forFinderType(type);
    if (definitions.isEmpty) {
      throw FinderDslException(
        'Finder type "$type" is not representable in the DSL.',
        path: 'finderType',
      );
    }
    final definition = _definitionForCanonical(finder, definitions);
    switch (definition.mapping) {
      case FinderDslMappingKind.byType:
        return FinderAst(definition.name, [
          FinderAstStringValue(_requiredString(finder, 'type', 'type')),
        ]);
      case FinderDslMappingKind.valueKey:
        final keyType = _requiredString(finder, 'keyValueType', 'keyValueType');
        final key = _requiredString(finder, 'keyValueString', 'keyValueString');
        return FinderAst(definition.name, [
          keyType == 'int'
              ? FinderAstIntegerValue(_parseInteger(key, 'keyValueString'))
              : FinderAstStringValue(key),
        ]);
      case FinderDslMappingKind.byText:
        final arguments = <FinderAstValue>[
          FinderAstStringValue(_requiredString(finder, 'text', 'text')),
        ];
        if (finder.containsKey('matchType')) {
          arguments.add(
            FinderAstEnumValue(
              _requiredString(finder, 'matchType', 'matchType'),
            ),
          );
        } else if (finder.containsKey('ignoreCase')) {
          arguments.add(const FinderAstEnumValue('exact'));
        }
        if (finder.containsKey('ignoreCase')) {
          arguments.add(
            FinderAstBooleanValue(_requiredBool(finder, 'ignoreCase')),
          );
        }
        return FinderAst(definition.name, arguments);
      case FinderDslMappingKind.semanticsLabel:
        final arguments = <FinderAstValue>[
          FinderAstStringValue(_requiredString(finder, 'label', 'label')),
        ];
        if (finder.containsKey('isRegExp')) {
          arguments.add(
            FinderAstBooleanValue(_requiredBool(finder, 'isRegExp')),
          );
        }
        return FinderAst(definition.name, arguments);
      case FinderDslMappingKind.semanticsIdentifier:
        return FinderAst(definition.name, [
          FinderAstStringValue(
            _requiredString(finder, 'identifier', 'identifier'),
          ),
        ]);
      case FinderDslMappingKind.tooltipMessage:
      case FinderDslMappingKind.tooltip:
        return FinderAst(definition.name, [
          FinderAstStringValue(_requiredString(finder, 'text', 'text')),
        ]);
      case FinderDslMappingKind.pageBack:
        return FinderAst(definition.name, const []);
      case FinderDslMappingKind.relation:
        final base = _fromCanonical(_requiredFinder(finder, 'of'));
        final matching = FinderAstExpressionValue(
          _fromCanonical(_requiredFinder(finder, 'matching')),
        );
        final matchRoot = finder['matchRoot'];
        final firstMatchOnly = finder['firstMatchOnly'];
        final exactContaining =
            type == 'Ancestor' &&
            finder.containsKey('matchRoot') &&
            finder.containsKey('firstMatchOnly') &&
            matchRoot == false &&
            firstMatchOnly == true;
        if (exactContaining) {
          return matching.value.append(
            FinderAstCall(definition.name, [FinderAstExpressionValue(base)]),
          );
        }

        final arguments = <FinderAstValue>[matching];
        if (matchRoot == true || firstMatchOnly == true) {
          arguments.add(FinderAstBooleanValue(matchRoot == true));
          arguments.add(FinderAstBooleanValue(firstMatchOnly == true));
        }
        return base.append(FinderAstCall(definition.name, arguments));
      case FinderDslMappingKind.containing:
        final base = _fromCanonical(_requiredFinder(finder, 'of'));
        final matching = _fromCanonical(_requiredFinder(finder, 'matching'));
        return matching.append(
          FinderAstCall(definition.name, [FinderAstExpressionValue(base)]),
        );
      case FinderDslMappingKind.matchPosition:
        final base = _fromCanonical(_requiredFinder(finder, 'of'));
        final position = _requiredString(finder, 'position', 'position');
        if (position == 'index') {
          return base.append(
            FinderAstCall(definition.name, [
              FinderAstIntegerValue(_requiredInt(finder, 'index', 'index')),
            ]),
          );
        }
        if (position == 'first' || position == 'last') {
          return base.append(FinderAstCall(definition.name, const []));
        }
        throw FinderDslException(
          'Unsupported match position "$position".',
          path: 'position',
        );
    }
  }

  static FinderDslDefinition _definition(
    String name,
    FinderDslMemberKind memberKind,
  ) {
    final definition = FinderDslMetadataRegistry.find(
      name,
      memberKind: memberKind,
    );
    if (definition == null) {
      final kind =
          memberKind == FinderDslMemberKind.root ? 'function' : 'method';
      throw FinderDslException('Unsupported finder $kind "$name".');
    }
    return definition;
  }

  static FinderDslDefinition _definitionForCanonical(
    Map<String, dynamic> finder,
    List<FinderDslDefinition> definitions,
  ) {
    if (definitions.length == 1) return definitions.single;

    for (final definition in definitions) {
      if (definition.mapping == FinderDslMappingKind.containing &&
          finder['matchRoot'] == false &&
          finder['firstMatchOnly'] == true) {
        return definition;
      }
      if (definition.mapping == FinderDslMappingKind.relation &&
          !(finder['matchRoot'] == false && finder['firstMatchOnly'] == true)) {
        return definition;
      }
    }
    final position = finder['position'];
    if (position is String) {
      final definition = FinderDslMetadataRegistry.findByCanonicalPosition(
        position,
      );
      if (definition != null && definitions.contains(definition)) {
        return definition;
      }
    }
    throw FinderDslException(
      'Finder fields do not identify a supported DSL form.',
      path: 'finderType',
    );
  }

  static Map<String, dynamic> _requiredFinder(
    Map<String, dynamic> finder,
    String name,
  ) {
    final value = finder[name];
    if (value is! Map<String, dynamic>) {
      throw FinderDslException(
        'Finder property "$name" must be an object.',
        path: name,
      );
    }
    return value;
  }

  static String _requiredString(
    Map<String, dynamic> finder,
    String name,
    String path,
  ) {
    final value = finder[name];
    if (value is! String) {
      throw FinderDslException(
        'Finder property "$name" must be a string.',
        path: path,
      );
    }
    return value;
  }

  static bool _requiredBool(Map<String, dynamic> finder, String name) {
    final value = finder[name];
    if (value is! bool) {
      throw FinderDslException(
        'Finder property "$name" must be a boolean.',
        path: name,
      );
    }
    return value;
  }

  static int _requiredInt(
    Map<String, dynamic> finder,
    String name,
    String path,
  ) {
    final value = finder[name];
    if (value is! int || value < 0) {
      throw FinderDslException(
        'Finder property "$name" must be a non-negative integer.',
        path: path,
      );
    }
    return value;
  }

  static int _parseInteger(String value, String path) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw FinderDslException(
        'An integer key must contain an integer string.',
        path: path,
      );
    }
    return parsed;
  }

  static void _validateArguments(
    FinderDslDefinition definition,
    List<FinderAstValue> arguments,
  ) {
    final required = definition.requiredArgumentCount;
    final maximum = definition.arguments.length;
    final validCount =
        definition.mapping == FinderDslMappingKind.relation
            ? arguments.length == 1 || arguments.length == 3
            : arguments.length >= required && arguments.length <= maximum;
    if (!validCount) {
      final expected =
          definition.mapping == FinderDslMappingKind.relation
              ? '1 or 3'
              : required == maximum
              ? required.toString()
              : '$required or $maximum';
      throw _countError(definition.name, expected);
    }

    for (var index = 0; index < arguments.length; index++) {
      final argument = definition.arguments[index];
      final value = arguments[index];
      final valid = switch (argument.kind) {
        FinderDslArgumentKind.string => value is FinderAstStringValue,
        FinderDslArgumentKind.integer => value is FinderAstIntegerValue,
        FinderDslArgumentKind.boolean => value is FinderAstBooleanValue,
        FinderDslArgumentKind.enumValue =>
          value is FinderAstEnumValue || value is FinderAstStringValue,
        FinderDslArgumentKind.finder => value is FinderAstExpressionValue,
        FinderDslArgumentKind.stringOrInteger =>
          value is FinderAstStringValue || value is FinderAstIntegerValue,
      };
      if (!valid) {
        throw _argumentError(
          definition.name,
          index,
          _argumentDescription(argument),
        );
      }
      if (argument.kind == FinderDslArgumentKind.enumValue) {
        final enumValue = switch (value) {
          FinderAstEnumValue() => value.value,
          FinderAstStringValue() => value.value,
          _ => null,
        };
        if (!argument.enumValues.contains(enumValue)) {
          throw _argumentError(
            definition.name,
            index,
            argument.enumValues.join(', '),
          );
        }
      }
    }
  }

  static String _argumentDescription(FinderDslArgumentMetadata argument) {
    return switch (argument.kind) {
      FinderDslArgumentKind.string => 'a string',
      FinderDslArgumentKind.integer => 'an integer',
      FinderDslArgumentKind.boolean => 'a boolean',
      FinderDslArgumentKind.enumValue => argument.enumValues.join(', '),
      FinderDslArgumentKind.finder => 'a nested finder expression',
      FinderDslArgumentKind.stringOrInteger => 'a string or integer',
    };
  }

  static FinderAst _finderArgument(
    FinderDslDefinition definition,
    List<FinderAstValue> arguments,
    int index,
  ) {
    final value = arguments[index];
    if (value is! FinderAstExpressionValue) {
      throw _argumentError(
        definition.name,
        index,
        'a nested finder expression',
      );
    }
    return value.value;
  }

  static String _stringArgument(
    FinderDslDefinition definition,
    List<FinderAstValue> arguments,
    int index,
  ) {
    final value = arguments[index];
    if (value is! FinderAstStringValue) {
      throw _argumentError(definition.name, index, 'a string');
    }
    return value.value;
  }

  static String _enumArgument(
    FinderDslDefinition definition,
    List<FinderAstValue> arguments,
    int index,
  ) {
    final value = arguments[index];
    final enumValue = switch (value) {
      FinderAstEnumValue() => value.value,
      FinderAstStringValue() => value.value,
      _ => null,
    };
    final values = definition.arguments[index].enumValues;
    if (enumValue == null || !values.contains(enumValue)) {
      throw _argumentError(definition.name, index, values.join(', '));
    }
    return enumValue;
  }

  static bool _boolArgument(
    FinderDslDefinition definition,
    List<FinderAstValue> arguments,
    int index,
  ) {
    final value = arguments[index];
    if (value is! FinderAstBooleanValue) {
      throw _argumentError(definition.name, index, 'a boolean');
    }
    return value.value;
  }

  static int _integerArgument(
    FinderDslDefinition definition,
    List<FinderAstValue> arguments,
    int index,
  ) {
    final value = arguments[index];
    if (value is! FinderAstIntegerValue) {
      throw _argumentError(definition.name, index, 'an integer');
    }
    return value.value;
  }

  static FinderDslException _countError(String name, String expected) {
    return FinderDslException(
      'Finder function "$name" expects $expected argument(s).',
    );
  }

  static FinderDslException _argumentError(
    String name,
    int index,
    String expected,
  ) {
    return FinderDslException(
      'Argument ${index + 1} of "$name" must be $expected.',
    );
  }
}

class FinderDslGenerator {
  const FinderDslGenerator._();

  static String generate(FinderAst ast) =>
      _formatExpression(ast, nested: false);

  static String generateCanonical(
    Map<String, dynamic> canonical, {
    ProtocolSchemaRegistry? registry,
  }) {
    return generate(
      FinderDslCodec.fromCanonical(canonical, registry: registry),
    );
  }

  static String _formatExpression(
    FinderAst expression, {
    required bool nested,
  }) {
    var result =
        '${expression.name}(${expression.arguments.map(_formatValue).join(', ')})';
    for (final call in expression.chain) {
      final separator = nested ? '.' : '\n  .';
      result +=
          '$separator${call.name}(${call.arguments.map(_formatValue).join(', ')})';
    }
    return result;
  }

  static String _formatValue(FinderAstValue value) {
    return switch (value) {
      FinderAstStringValue() => jsonEncode(value.value),
      FinderAstIntegerValue() => value.value.toString(),
      FinderAstBooleanValue() => value.value.toString(),
      FinderAstEnumValue() => value.value,
      FinderAstExpressionValue() => _formatExpression(
        value.value,
        nested: true,
      ),
    };
  }
}

enum _FinderTokenKind {
  identifier,
  string,
  integer,
  boolean,
  leftParen,
  rightParen,
  comma,
  dot,
  eof,
}

class _FinderToken {
  const _FinderToken(this.kind, this.offset, {this.text, this.value});

  final _FinderTokenKind kind;
  final int offset;
  final String? text;
  final Object? value;
}

class _FinderLexer {
  _FinderLexer(this.source);

  final String source;

  List<_FinderToken> tokenize() {
    final tokens = <_FinderToken>[];
    var index = 0;
    while (index < source.length) {
      final char = source[index];
      if (_isWhitespace(char)) {
        index++;
        continue;
      }
      switch (char) {
        case '(':
          tokens.add(_FinderToken(_FinderTokenKind.leftParen, index));
          index++;
        case ')':
          tokens.add(_FinderToken(_FinderTokenKind.rightParen, index));
          index++;
        case ',':
          tokens.add(_FinderToken(_FinderTokenKind.comma, index));
          index++;
        case '.':
          tokens.add(_FinderToken(_FinderTokenKind.dot, index));
          index++;
        case '"':
          final result = _readString(index);
          tokens.add(result.$1);
          index = result.$2;
        default:
          if (char == '-' || _isDigit(char)) {
            final result = _readInteger(index);
            tokens.add(result.$1);
            index = result.$2;
          } else if (_isIdentifierStart(char)) {
            final result = _readIdentifier(index);
            tokens.add(result.$1);
            index = result.$2;
          } else {
            throw FinderDslException(
              'Unexpected character "$char".',
              offset: index,
            );
          }
      }
    }
    tokens.add(_FinderToken(_FinderTokenKind.eof, source.length));
    return tokens;
  }

  (_FinderToken, int) _readString(int start) {
    var index = start + 1;
    var escaped = false;
    while (index < source.length) {
      final char = source[index];
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '"') {
        final raw = source.substring(start, index + 1);
        try {
          final value = jsonDecode(raw);
          if (value is! String) throw const FormatException();
          return (
            _FinderToken(_FinderTokenKind.string, start, value: value),
            index + 1,
          );
        } on FormatException {
          throw FinderDslException('Invalid string literal.', offset: start);
        }
      }
      index++;
    }
    throw FinderDslException('Unterminated string literal.', offset: start);
  }

  (_FinderToken, int) _readInteger(int start) {
    var index = start;
    if (source[index] == '-') index++;
    final digitsStart = index;
    while (index < source.length && _isDigit(source[index])) {
      index++;
    }
    if (index == digitsStart) {
      throw FinderDslException(
        'An integer requires at least one digit.',
        offset: start,
      );
    }
    final text = source.substring(start, index);
    return (
      _FinderToken(
        _FinderTokenKind.integer,
        start,
        text: text,
        value: int.parse(text),
      ),
      index,
    );
  }

  (_FinderToken, int) _readIdentifier(int start) {
    var index = start + 1;
    while (index < source.length && _isIdentifierPart(source[index])) {
      index++;
    }
    final text = source.substring(start, index);
    final kind =
        text == 'true' || text == 'false'
            ? _FinderTokenKind.boolean
            : _FinderTokenKind.identifier;
    final value = kind == _FinderTokenKind.boolean ? text == 'true' : null;
    return (_FinderToken(kind, start, text: text, value: value), index);
  }

  bool _isWhitespace(String char) => char.trim().isEmpty;

  bool _isDigit(String char) =>
      char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;

  bool _isIdentifierStart(String char) {
    final code = char.codeUnitAt(0);
    return code == 95 ||
        code == 36 ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122);
  }

  bool _isIdentifierPart(String char) {
    return _isIdentifierStart(char) || _isDigit(char);
  }
}

class _FinderDslParser {
  _FinderDslParser(this.source) : tokens = _FinderLexer(source).tokenize();

  final String source;
  final List<_FinderToken> tokens;
  int index = 0;

  FinderAst parse() {
    if (_current.kind == _FinderTokenKind.eof) {
      throw _error('A finder expression is required.');
    }
    final expression = _parseExpression();
    if (_current.kind != _FinderTokenKind.eof) {
      throw _error('Unexpected token after finder expression.');
    }
    return expression;
  }

  FinderAst _parseExpression() {
    final root = _parseCall();
    final chain = <FinderAstCall>[];
    while (_match(_FinderTokenKind.dot)) {
      chain.add(_parseCall());
    }
    return FinderAst(root.name, root.arguments, chain: chain);
  }

  FinderAstCall _parseCall() {
    final name = _expect(_FinderTokenKind.identifier, 'an identifier').text!;
    _expect(_FinderTokenKind.leftParen, '"("');
    final arguments = <FinderAstValue>[];
    if (_current.kind != _FinderTokenKind.rightParen) {
      arguments.add(_parseArgument());
      while (_match(_FinderTokenKind.comma)) {
        arguments.add(_parseArgument());
      }
    }
    _expect(_FinderTokenKind.rightParen, '")"');
    return FinderAstCall(name, arguments);
  }

  FinderAstValue _parseArgument() {
    final token = _current;
    switch (token.kind) {
      case _FinderTokenKind.string:
        index++;
        return FinderAstStringValue(token.value! as String);
      case _FinderTokenKind.integer:
        index++;
        return FinderAstIntegerValue(token.value! as int);
      case _FinderTokenKind.boolean:
        index++;
        return FinderAstBooleanValue(token.value! as bool);
      case _FinderTokenKind.identifier:
        if (_peek.kind == _FinderTokenKind.leftParen) {
          return FinderAstExpressionValue(_parseExpression());
        }
        index++;
        return FinderAstEnumValue(token.text!);
      default:
        throw _error('Expected a string, integer, boolean, enum, or finder.');
    }
  }

  _FinderToken get _current => tokens[index];

  _FinderToken get _peek =>
      index + 1 < tokens.length ? tokens[index + 1] : tokens.last;

  bool _match(_FinderTokenKind kind) {
    if (_current.kind != kind) return false;
    index++;
    return true;
  }

  _FinderToken _expect(_FinderTokenKind kind, String description) {
    if (_current.kind != kind) {
      throw _error('Expected $description.');
    }
    return tokens[index++];
  }

  FinderDslException _error(String message) {
    final offset = _current.offset.clamp(0, source.length);
    final before = source.substring(0, offset);
    final line = '\n'.allMatches(before).length + 1;
    final lastBreak = before.lastIndexOf('\n');
    return FinderDslException(
      message,
      offset: offset,
      line: line,
      column: offset - lastBreak,
    );
  }
}
