import 'finder_dsl_metadata.dart';

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

  static final List<FinderCompletionItem> roots = _definitionItems(
    FinderDslMemberKind.root,
  );

  static final List<FinderCompletionItem> chains = _definitionItems(
    FinderDslMemberKind.chain,
  );

  static final List<FinderCompletionItem> textMatchValues = _enumItems(
    FinderDslMetadataRegistry.all
        .firstWhere(
          (definition) => definition.mapping == FinderDslMappingKind.textMatch,
        )
        .argumentAt(1)!,
    description: (value) => 'Use the $value text matching strategy.',
  );

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

  static String? signatureFor(String name) {
    return FinderDslMetadataRegistry.find(name)?.signature;
  }

  static List<FinderCompletionItem> itemsForArgument(
    FinderDslDefinition? definition,
    int argumentIndex,
  ) {
    final argument = definition?.argumentAt(argumentIndex);
    if (argument == null) return const [];

    return switch (argument.kind) {
      FinderDslArgumentKind.finder => roots,
      FinderDslArgumentKind.enumValue =>
        definition?.mapping == FinderDslMappingKind.textMatch
            ? textMatchValues
            : _enumItems(argument),
      FinderDslArgumentKind.boolean => booleans,
      _ => const [],
    };
  }

  static List<FinderCompletionItem> _definitionItems(
    FinderDslMemberKind memberKind,
  ) {
    return List.unmodifiable(
      FinderDslMetadataRegistry.all
          .where((definition) => definition.memberKind == memberKind)
          .map(
            (definition) => FinderCompletionItem(
              label: definition.name,
              signature: definition.signature,
              description: definition.description,
              kind:
                  memberKind == FinderDslMemberKind.root
                      ? FinderCompletionKind.root
                      : FinderCompletionKind.chain,
              insertion: definition.completionInsertion(),
              caretOffset: definition.completionCaretOffset(),
            ),
          ),
    );
  }

  static List<FinderCompletionItem> _enumItems(
    FinderDslArgumentMetadata argument, {
    String Function(String value)? description,
  }) {
    return List.unmodifiable([
      for (final value in argument.enumValues)
        FinderCompletionItem(
          label: value,
          signature: value,
          description:
              description?.call(value) ??
              'Use the $value ${argument.name} value.',
          kind: FinderCompletionKind.enumValue,
          insertion: value,
          caretOffset: value.length,
        ),
    ]);
  }

  static RegExp _buildDslTokenPattern() {
    final names =
        {
            for (final item in [
              ...roots,
              ...chains,
              ...FinderDslMetadataRegistry.all.expand(
                (definition) => definition.arguments.expand(
                  (argument) => _enumItems(argument),
                ),
              ),
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
      final definition = FinderDslMetadataRegistry.find(frame.name);
      signature = definition?.signature;
      candidates = FinderCompletionRegistry.itemsForArgument(
        definition,
        frame.argumentIndex,
      );
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
