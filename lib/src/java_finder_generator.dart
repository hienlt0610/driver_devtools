class JavaFinderGenerationException implements Exception {
  const JavaFinderGenerationException(this.message, {this.path});

  final String message;
  final String? path;

  @override
  String toString() => path == null ? message : '$path: $message';
}

class JavaFinderGenerator {
  const JavaFinderGenerator._();

  static String generate(Map<String, dynamic> payload) {
    return _renderFinder(payload, path: '');
  }

  static String _renderFinder(
    Map<String, dynamic> finder, {
    required String path,
  }) {
    final finderType = _requiredString(finder, 'finderType', path);
    switch (finderType) {
      case 'ByValueKey':
        return _renderByValueKey(finder, path);
      case 'ByText':
        return _renderByText(finder, path);
      case 'ByType':
        return _renderCall('byType', [
          _stringLiteral(_requiredString(finder, 'type', path)),
        ]);
      case 'ByTooltip':
        throw _error(
          _finderTypePath(path),
          'Unsupported finder type "ByTooltip".',
        );
      case 'ByTooltipMessage':
        return _renderCall('byTooltip', [
          _stringLiteral(_requiredString(finder, 'text', path)),
        ]);
      case 'BySemanticsLabel':
        return _renderSemanticsLabel(finder, path);
      case 'BySemanticsIdentifier':
        final identifier = _requiredString(finder, 'identifier', path);
        if (identifier.trim().isEmpty) {
          throw _error(
            _propertyPath(path, 'identifier'),
            'A non-empty string is required.',
          );
        }
        return _renderCall('bySemanticsIdentifier', [
          _stringLiteral(identifier),
        ]);
      case 'Ancestor':
        return _renderRelation(finder, path, method: 'ancestor');
      case 'Descendant':
        return _renderRelation(finder, path, method: 'descendant');
      case 'ByMatchPosition':
        return _renderByMatchPosition(finder, path);
      case 'PageBack':
        return 'Flutter.pageBack()';
      default:
        throw _error(
          _finderTypePath(path),
          'Unsupported finder type "$finderType".',
        );
    }
  }

  static String _renderByValueKey(Map<String, dynamic> finder, String path) {
    final value = _requiredString(finder, 'keyValueString', path);
    final keyType = _requiredString(finder, 'keyValueType', path);
    final numeric = _isAsciiInteger(value);
    if (keyType == 'String' && numeric) {
      throw _error(
        _propertyPath(path, 'keyValueType'),
        'A numeric String key is inferred as int by FlutterBy and cannot be preserved.',
      );
    }
    if (keyType == 'int' && !numeric) {
      throw _error(
        _propertyPath(path, 'keyValueString'),
        'An int key must contain only decimal digits.',
      );
    }
    if (keyType != 'String' && keyType != 'int') {
      throw _error(
        _propertyPath(path, 'keyValueType'),
        'Unsupported key type "$keyType".',
      );
    }
    return _renderCall('byKey', [_stringLiteral(value)]);
  }

  static String _renderByText(Map<String, dynamic> finder, String path) {
    final text = _stringLiteral(_requiredString(finder, 'text', path));
    final matchTypeValue = finder['matchType'];
    if (matchTypeValue != null && matchTypeValue is! String) {
      throw _error(_propertyPath(path, 'matchType'), 'A string is required.');
    }
    final matchType = matchTypeValue as String? ?? 'exact';
    final ignoreCase = _optionalBool(finder, 'ignoreCase', path) ?? false;
    if (matchType == 'exact') {
      if (ignoreCase) {
        throw _error(
          _propertyPath(path, 'ignoreCase'),
          'Java generation cannot represent exact matching with ignoreCase.',
        );
      }
      return _renderCall('byText', [text]);
    }
    final enumValue = switch (matchType) {
      'contains' => 'CONTAINS',
      'startsWith' => 'STARTS_WITH',
      'endsWith' => 'ENDS_WITH',
      'regex' => 'REGEX',
      _ =>
        throw _error(
          _propertyPath(path, 'matchType'),
          'Unsupported match type "$matchType".',
        ),
    };
    final arguments = <String>[text, 'Flutter.TextMatchType.$enumValue'];
    if (ignoreCase) {
      arguments.add('true');
    }
    return _renderCall('byTextMatch', arguments);
  }

  static String _renderSemanticsLabel(
    Map<String, dynamic> finder,
    String path,
  ) {
    final label = _stringLiteral(_requiredString(finder, 'label', path));
    final isRegExp = _optionalBool(finder, 'isRegExp', path) ?? false;
    return isRegExp
        ? _renderCall('bySemanticsLabelRegex', [label])
        : _renderCall('bySemanticsLabel', [label]);
  }

  static String _renderRelation(
    Map<String, dynamic> finder,
    String path, {
    required String method,
  }) {
    final of = _requiredFinder(finder, 'of', path);
    final matching = _requiredFinder(finder, 'matching', path);
    final ofPath = _propertyPath(path, 'of');
    final matchingPath = _propertyPath(path, 'matching');
    final ofCode = _renderFinder(of, path: ofPath);
    final matchingCode = _renderFinder(matching, path: matchingPath);
    final matchRoot = _optionalBool(finder, 'matchRoot', path) ?? false;
    final firstMatchOnly =
        _optionalBool(finder, 'firstMatchOnly', path) ?? false;

    if (method == 'ancestor' &&
        finder.containsKey('matchRoot') &&
        finder.containsKey('firstMatchOnly') &&
        matchRoot == false &&
        firstMatchOnly == true) {
      return '$matchingCode.containing($ofCode)';
    }

    final flags =
        matchRoot == false && firstMatchOnly == false
            ? ''
            : ', $matchRoot, $firstMatchOnly';
    return '$ofCode.$method($matchingCode$flags)';
  }

  static String _renderByMatchPosition(
    Map<String, dynamic> finder,
    String path,
  ) {
    final position = _requiredString(finder, 'position', path);
    final of = _renderFinder(
      _requiredFinder(finder, 'of', path),
      path: _propertyPath(path, 'of'),
    );
    switch (position) {
      case 'first':
        return '$of.first()';
      case 'last':
        return '$of.last()';
      case 'index':
        final index = finder['index'];
        if (index is! int || index < 0) {
          throw _error(
            _propertyPath(path, 'index'),
            'A non-negative integer is required.',
          );
        }
        return '$of.at($index)';
      default:
        throw _error(
          _propertyPath(path, 'position'),
          'Unsupported position "$position".',
        );
    }
  }

  static String _renderCall(String method, List<String> arguments) {
    return 'Flutter.$method(${arguments.join(', ')})';
  }

  static Map<String, dynamic> _requiredFinder(
    Map<String, dynamic> finder,
    String key,
    String path,
  ) {
    final value = finder[key];
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw _error(_propertyPath(path, key), 'A finder object is required.');
  }

  static String _requiredString(
    Map<String, dynamic> finder,
    String key,
    String path,
  ) {
    final value = finder[key];
    if (value is String) {
      return value;
    }
    throw _error(_propertyPath(path, key), 'A string is required.');
  }

  static bool? _optionalBool(
    Map<String, dynamic> finder,
    String key,
    String path,
  ) {
    final value = finder[key];
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    throw _error(_propertyPath(path, key), 'A boolean is required.');
  }

  static JavaFinderGenerationException _error(String path, String message) {
    return JavaFinderGenerationException(
      message,
      path: path.isEmpty ? null : path,
    );
  }

  static String _finderTypePath(String path) {
    return _propertyPath(path, 'finderType');
  }

  static String _propertyPath(String path, String property) {
    return path.isEmpty ? property : '$path.$property';
  }

  static bool _isAsciiInteger(String value) {
    return value.isNotEmpty &&
        value.codeUnits.every((unit) => unit >= 0x30 && unit <= 0x39);
  }

  static String _stringLiteral(String value) {
    final escaped = StringBuffer();
    for (final rune in value.runes) {
      switch (rune) {
        case 0x08:
          escaped.write(r'\b');
        case 0x09:
          escaped.write(r'\t');
        case 0x0a:
          escaped.write(r'\n');
        case 0x0c:
          escaped.write(r'\f');
        case 0x0d:
          escaped.write(r'\r');
        case 0x22:
          escaped.write(r'\"');
        case 0x5c:
          escaped.write(r'\\');
        default:
          if (rune < 0x20) {
            escaped.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
          } else {
            escaped.writeCharCode(rune);
          }
      }
    }
    return '"$escaped"';
  }
}
