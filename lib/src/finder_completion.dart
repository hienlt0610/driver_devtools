enum FinderCompletionKind { root, chain, enumValue, booleanValue }

class FinderCompletionItem {
  const FinderCompletionItem({
    required this.label,
    required this.signature,
    required this.description,
    required this.kind,
    required this.insertion,
    required this.caretOffset,
  });

  final String label;
  final String signature;
  final String description;
  final FinderCompletionKind kind;
  final String insertion;
  final int caretOffset;

  FinderCompletionItem forExistingCall(bool existingCall) {
    if (!existingCall ||
        kind == FinderCompletionKind.enumValue ||
        kind == FinderCompletionKind.booleanValue) {
      return this;
    }
    return FinderCompletionItem(
      label: label,
      signature: signature,
      description: description,
      kind: kind,
      insertion: label,
      caretOffset: label.length,
    );
  }
}

class FinderCompletionRegistry {
  FinderCompletionRegistry._();

  static final List<FinderCompletionItem> roots = List.unmodifiable([
    _call(
      'type',
      'type(value: String)',
      'Match widgets by runtime type.',
      '""',
      1,
    ),
    _call('key', 'key(value: String | int)', 'Match a ValueKey.', '""', 1),
    _call(
      'text',
      'text(value: String)',
      'Match widgets by exact text.',
      '""',
      1,
    ),
    _call(
      'textMatch',
      'textMatch(text, matchType, ignoreCase?)',
      'Match widget text with a supported match strategy.',
      '"", contains',
      1,
    ),
    _call(
      'semanticsLabel',
      'semanticsLabel(label, isRegExp?)',
      'Match a semantics label.',
      '""',
      1,
    ),
    _call(
      'semanticsId',
      'semanticsId(identifier: String)',
      'Match a semantics identifier.',
      '""',
      1,
    ),
    _call(
      'tooltip',
      'tooltip(text: String)',
      'Match a tooltip message.',
      '""',
      1,
    ),
    _call(
      'tooltipText',
      'tooltipText(text: String)',
      'Match tooltip text.',
      '""',
      1,
    ),
    const FinderCompletionItem(
      label: 'pageBack',
      signature: 'pageBack()',
      description: 'Match the page-back finder.',
      kind: FinderCompletionKind.root,
      insertion: 'pageBack()',
      caretOffset: 10,
    ),
  ]);

  static final List<FinderCompletionItem> chains = List.unmodifiable([
    _call(
      'descendant',
      'descendant(matching, matchRoot?, firstMatchOnly?)',
      'Find a descendant matching a nested finder.',
      '',
      0,
      kind: FinderCompletionKind.chain,
    ),
    _call(
      'ancestor',
      'ancestor(matching, matchRoot?, firstMatchOnly?)',
      'Find an ancestor matching a nested finder.',
      '',
      0,
      kind: FinderCompletionKind.chain,
    ),
    _call(
      'containing',
      'containing(matching)',
      'Find the first ancestor containing a nested finder.',
      '',
      0,
      kind: FinderCompletionKind.chain,
    ),
    const FinderCompletionItem(
      label: 'first',
      signature: 'first()',
      description: 'Select the first match.',
      kind: FinderCompletionKind.chain,
      insertion: 'first()',
      caretOffset: 7,
    ),
    const FinderCompletionItem(
      label: 'last',
      signature: 'last()',
      description: 'Select the last match.',
      kind: FinderCompletionKind.chain,
      insertion: 'last()',
      caretOffset: 6,
    ),
    const FinderCompletionItem(
      label: 'at',
      signature: 'at(index: int)',
      description: 'Select the match at a non-negative index.',
      kind: FinderCompletionKind.chain,
      insertion: 'at(0)',
      caretOffset: 3,
    ),
  ]);

  static final List<FinderCompletionItem> textMatchValues = List.unmodifiable([
    for (final value in ['contains', 'startsWith', 'endsWith', 'regex'])
      FinderCompletionItem(
        label: value,
        signature: value,
        description: 'Use the $value text matching strategy.',
        kind: FinderCompletionKind.enumValue,
        insertion: value,
        caretOffset: value.length,
      ),
  ]);

  static final List<FinderCompletionItem> booleans = List.unmodifiable([
    for (final value in ['true', 'false'])
      FinderCompletionItem(
        label: value,
        signature: value,
        description: 'Use the boolean value $value.',
        kind: FinderCompletionKind.booleanValue,
        insertion: value,
        caretOffset: value.length,
      ),
  ]);

  static final RegExp dslTokenPattern = _buildDslTokenPattern();

  static FinderCompletionItem _call(
    String label,
    String signature,
    String description,
    String arguments,
    int argumentCaretOffset, {
    FinderCompletionKind kind = FinderCompletionKind.root,
  }) {
    final insertion = '$label($arguments)';
    return FinderCompletionItem(
      label: label,
      signature: signature,
      description: description,
      kind: kind,
      insertion: insertion,
      caretOffset: label.length + 1 + argumentCaretOffset,
    );
  }

  static String? signatureFor(String name) {
    for (final item in [...roots, ...chains]) {
      if (item.label == name) return item.signature;
    }
    return null;
  }

  static RegExp _buildDslTokenPattern() {
    final names =
        {
            for (final item in [
              ...roots,
              ...chains,
              ...textMatchValues,
              ...booleans,
            ])
              item.label,
          }.toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    return RegExp(r'"(?:\\.|[^"\\])*"|-?\d+|\b(?:' + names.join('|') + r')\b');
  }
}

class FinderCompletionEdit {
  const FinderCompletionEdit({
    required this.text,
    required this.selectionOffset,
  });

  final String text;
  final int selectionOffset;
}

class FinderCompletionContext {
  const FinderCompletionContext({
    required this.prefix,
    required this.replacementStart,
    required this.replacementEnd,
    required this.items,
    this.signature,
  });

  final String prefix;
  final int replacementStart;
  final int replacementEnd;
  final List<FinderCompletionItem> items;
  final String? signature;

  FinderCompletionEdit apply(FinderCompletionItem item, String source) {
    final before = source.substring(0, replacementStart);
    final after = source.substring(replacementEnd);
    return FinderCompletionEdit(
      text: '$before${item.insertion}$after',
      selectionOffset: replacementStart + item.caretOffset,
    );
  }
}

class FinderCompletionContextAnalyzer {
  const FinderCompletionContextAnalyzer._();

  static FinderCompletionContext analyze(
    String source,
    int caretOffset, {
    bool explicit = false,
  }) {
    final caret = caretOffset.clamp(0, source.length);
    final allTokens = _CompletionScanner(source).scan();
    final prefixSource = source.substring(0, caret);
    final prefixScan = _CompletionScanner(prefixSource).scanResult();
    final identifier = _identifierAt(allTokens, caret);
    final replacementStart = identifier?.start ?? caret;
    final replacementEnd = identifier?.end ?? caret;
    final prefix = source.substring(
      replacementStart,
      caret.clamp(replacementStart, replacementEnd),
    );

    if (prefixScan.insideString) {
      return FinderCompletionContext(
        prefix: prefix,
        replacementStart: replacementStart,
        replacementEnd: replacementEnd,
        items: const [],
      );
    }

    final tokens = prefixScan.tokens;
    final last = tokens.isEmpty ? null : tokens.last;
    final previous = tokens.length < 2 ? null : tokens[tokens.length - 2];
    final afterDot =
        last?.kind == _CompletionTokenKind.dot ||
        (last?.kind == _CompletionTokenKind.identifier &&
            previous?.kind == _CompletionTokenKind.dot);
    final frame = prefixScan.frames.isEmpty ? null : prefixScan.frames.last;

    List<FinderCompletionItem> candidates;
    String? signature;
    if (afterDot ||
        (explicit && last?.kind == _CompletionTokenKind.rightParen)) {
      candidates = FinderCompletionRegistry.chains;
    } else if (frame != null) {
      signature = FinderCompletionRegistry.signatureFor(frame.name);
      candidates = switch ((frame.name, frame.argumentIndex)) {
        ('descendant', 0) ||
        ('ancestor', 0) ||
        ('containing', 0) => FinderCompletionRegistry.roots,
        ('textMatch', 1) => FinderCompletionRegistry.textMatchValues,
        ('textMatch', 2) ||
        ('descendant', 1) ||
        ('ancestor', 1) ||
        ('descendant', 2) ||
        ('ancestor', 2) => FinderCompletionRegistry.booleans,
        _ => const [],
      };
    } else if (last == null || last.kind == _CompletionTokenKind.identifier) {
      candidates = FinderCompletionRegistry.roots;
    } else {
      candidates = const [];
    }

    final existingCall = RegExp(
      r'^\s*\(',
    ).hasMatch(source.substring(replacementEnd));
    final items = candidates
        .where(
          (item) => item.label.toLowerCase().startsWith(prefix.toLowerCase()),
        )
        .map((item) => item.forExistingCall(existingCall))
        .toList(growable: false);

    return FinderCompletionContext(
      prefix: prefix,
      replacementStart: replacementStart,
      replacementEnd: replacementEnd,
      items: items,
      signature: signature,
    );
  }

  static _CompletionToken? _identifierAt(
    List<_CompletionToken> tokens,
    int caret,
  ) {
    for (final token in tokens) {
      if (token.kind != _CompletionTokenKind.identifier) continue;
      if (token.start <= caret && caret <= token.end) return token;
    }
    return null;
  }
}

enum _CompletionTokenKind {
  identifier,
  string,
  leftParen,
  rightParen,
  comma,
  dot,
  other,
}

class _CompletionToken {
  const _CompletionToken(this.kind, this.start, this.end, [this.text]);

  final _CompletionTokenKind kind;
  final int start;
  final int end;
  final String? text;
}

class _CompletionCallFrame {
  _CompletionCallFrame(this.name);

  final String name;
  int argumentIndex = 0;
}

class _CompletionScanResult {
  const _CompletionScanResult(this.tokens, this.frames, this.insideString);

  final List<_CompletionToken> tokens;
  final List<_CompletionCallFrame> frames;
  final bool insideString;
}

class _CompletionScanner {
  _CompletionScanner(this.source);

  final String source;

  List<_CompletionToken> scan() => scanResult().tokens;

  _CompletionScanResult scanResult() {
    final tokens = <_CompletionToken>[];
    var index = 0;
    var insideString = false;
    while (index < source.length) {
      final start = index;
      final char = source[index];
      if (char.trim().isEmpty) {
        index++;
        continue;
      }
      if (char == '"') {
        index++;
        var escaped = false;
        var closed = false;
        while (index < source.length) {
          final current = source[index];
          if (escaped) {
            escaped = false;
          } else if (current == '\\') {
            escaped = true;
          } else if (current == '"') {
            index++;
            closed = true;
            break;
          }
          index++;
        }
        tokens.add(_CompletionToken(_CompletionTokenKind.string, start, index));
        insideString = !closed;
        if (insideString) break;
        continue;
      }
      if (_isIdentifierStart(char)) {
        index++;
        while (index < source.length && _isIdentifierPart(source[index])) {
          index++;
        }
        tokens.add(
          _CompletionToken(
            _CompletionTokenKind.identifier,
            start,
            index,
            source.substring(start, index),
          ),
        );
        continue;
      }
      final kind = switch (char) {
        '(' => _CompletionTokenKind.leftParen,
        ')' => _CompletionTokenKind.rightParen,
        ',' => _CompletionTokenKind.comma,
        '.' => _CompletionTokenKind.dot,
        _ => _CompletionTokenKind.other,
      };
      tokens.add(_CompletionToken(kind, start, start + 1, char));
      index++;
    }

    final frames = <_CompletionCallFrame>[];
    for (var tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
      final token = tokens[tokenIndex];
      switch (token.kind) {
        case _CompletionTokenKind.identifier:
          final next =
              tokenIndex + 1 < tokens.length ? tokens[tokenIndex + 1] : null;
          if (next?.kind == _CompletionTokenKind.leftParen) {
            frames.add(_CompletionCallFrame(token.text!));
          }
        case _CompletionTokenKind.comma:
          if (frames.isNotEmpty) frames.last.argumentIndex++;
        case _CompletionTokenKind.rightParen:
          if (frames.isNotEmpty) frames.removeLast();
        case _:
          break;
      }
    }
    return _CompletionScanResult(tokens, frames, insideString);
  }

  bool _isIdentifierStart(String char) {
    final code = char.codeUnitAt(0);
    return code == 95 ||
        code == 36 ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122);
  }

  bool _isIdentifierPart(String char) {
    final code = char.codeUnitAt(0);
    return _isIdentifierStart(char) || (code >= 48 && code <= 57);
  }
}
