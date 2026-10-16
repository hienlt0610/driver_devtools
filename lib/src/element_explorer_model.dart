import 'dart:convert';

const int elementExplorerResponseSchemaVersion = 1;

const _childrenStates = <String>{
  'notRequested',
  'empty',
  'complete',
  'partial',
  'truncated',
};

class ElementExplorerResponseException implements Exception {
  const ElementExplorerResponseException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ElementExplorerResponse {
  const ElementExplorerResponse({
    required this.schemaVersion,
    required this.matchCount,
    required this.returnedNodes,
    required this.visitedNodes,
    required this.truncated,
    this.snapshot,
    this.error,
  });

  factory ElementExplorerResponse.parse(Object? source) {
    final payload = _asMap(source, 'response');
    final schemaVersion = _requiredInt(payload, 'schemaVersion');
    if (schemaVersion != elementExplorerResponseSchemaVersion) {
      throw ElementExplorerResponseException(
        'Unsupported Element Explorer schema version: $schemaVersion',
      );
    }

    final matchCount = _requiredInt(payload, 'matchCount');
    final returnedNodes = _requiredInt(payload, 'returnedNodes');
    final visitedNodes = _requiredInt(payload, 'visitedNodes');
    final truncated = _requiredBool(payload, 'truncated');
    final rawError = payload['error'];

    if (rawError != null) {
      final error = _parseError(rawError, matchCount);
      if (payload['root'] != null) {
        throw const ElementExplorerResponseException(
          'Error responses must not contain a root node.',
        );
      }
      if (returnedNodes != 0) {
        throw const ElementExplorerResponseException(
          'Error responses must report zero returned nodes.',
        );
      }
      return ElementExplorerResponse(
        schemaVersion: schemaVersion,
        matchCount: matchCount,
        returnedNodes: returnedNodes,
        visitedNodes: visitedNodes,
        truncated: truncated,
        error: error,
      );
    }

    if (matchCount != 1) {
      throw ElementExplorerResponseException(
        'Successful responses must report matchCount=1, got $matchCount.',
      );
    }
    final root = _parseNode(payload['root'], expectedParentId: null);
    final actualNodeCount = root.nodeCount;
    if (actualNodeCount != returnedNodes) {
      throw ElementExplorerResponseException(
        'returnedNodes=$returnedNodes does not match the serialized '
        'node count $actualNodeCount.',
      );
    }
    if (root.targetCount != 1) {
      throw ElementExplorerResponseException(
        'A successful response must contain exactly one target node, '
        'got ${root.targetCount}.',
      );
    }

    return ElementExplorerResponse(
      schemaVersion: schemaVersion,
      matchCount: matchCount,
      returnedNodes: returnedNodes,
      visitedNodes: visitedNodes,
      truncated: truncated,
      snapshot: ElementExplorerSnapshot(root: root),
    );
  }

  final int schemaVersion;
  final int matchCount;
  final int returnedNodes;
  final int visitedNodes;
  final bool truncated;
  final ElementExplorerSnapshot? snapshot;
  final ElementExplorerError? error;

  bool get isError => error != null;
}

class ElementExplorerError {
  const ElementExplorerError({
    required this.code,
    required this.message,
    required this.matchCount,
  });

  final String code;
  final String message;
  final int matchCount;
}

class ElementExplorerSnapshot {
  const ElementExplorerSnapshot({required this.root});

  final ElementExplorerNode root;
}

class ElementExplorerNode {
  const ElementExplorerNode({
    required this.nodeId,
    required this.parentId,
    required this.widgetType,
    required this.elementType,
    required this.key,
    required this.text,
    required this.semanticsIdentifier,
    required this.isTarget,
    required this.childrenState,
    required this.children,
    required this.metadataErrors,
  });

  final String nodeId;
  final String? parentId;
  final String widgetType;
  final String elementType;
  final Map<String, dynamic>? key;
  final String? text;
  final String? semanticsIdentifier;
  final bool isTarget;
  final String childrenState;
  final List<ElementExplorerNode> children;
  final List<String> metadataErrors;

  int get nodeCount =>
      1 + children.fold(0, (total, child) => total + child.nodeCount);

  int get targetCount =>
      (isTarget ? 1 : 0) +
      children.fold(0, (total, child) => total + child.targetCount);
}

ElementExplorerNode _parseNode(
  Object? source, {
  required String? expectedParentId,
  Set<String>? nodeIds,
}) {
  final ids = nodeIds ?? <String>{};
  final payload = _asMap(source, 'node');
  final nodeId = _requiredString(payload, 'nodeId');
  if (!ids.add(nodeId)) {
    throw ElementExplorerResponseException('Duplicate nodeId: $nodeId');
  }

  final parentId = _optionalString(payload, 'parentId');
  if (parentId != expectedParentId) {
    throw ElementExplorerResponseException(
      'Node $nodeId has parentId=$parentId; expected $expectedParentId.',
    );
  }

  final childrenState = _requiredString(payload, 'childrenState');
  if (!_childrenStates.contains(childrenState)) {
    throw ElementExplorerResponseException(
      'Unknown childrenState for $nodeId: $childrenState',
    );
  }

  final rawChildren = payload['children'];
  if (rawChildren is! List) {
    throw ElementExplorerResponseException(
      'Node $nodeId must contain a children list.',
    );
  }

  final children = <ElementExplorerNode>[];
  for (final child in rawChildren) {
    children.add(_parseNode(child, expectedParentId: nodeId, nodeIds: ids));
  }

  return ElementExplorerNode(
    nodeId: nodeId,
    parentId: parentId,
    widgetType: _requiredString(payload, 'widgetType'),
    elementType: _requiredString(payload, 'elementType'),
    key: _optionalMap(payload, 'key'),
    text: _optionalString(payload, 'text'),
    semanticsIdentifier: _optionalString(payload, 'semanticsIdentifier'),
    isTarget: _requiredBool(payload, 'isTarget'),
    childrenState: childrenState,
    children: List.unmodifiable(children),
    metadataErrors: _stringList(payload['metadataErrors']),
  );
}

ElementExplorerError _parseError(Object source, int matchCount) {
  final payload = _asMap(source, 'error');
  return ElementExplorerError(
    code: _requiredString(payload, 'code'),
    message: _requiredString(payload, 'message'),
    matchCount: matchCount,
  );
}

Map<String, dynamic> _asMap(Object? source, String name) {
  if (source is String) {
    try {
      source = jsonDecode(source);
    } on FormatException catch (error) {
      throw ElementExplorerResponseException(
        'Invalid Element Explorer $name JSON: ${error.message}',
      );
    }
  }
  if (source is! Map) {
    throw ElementExplorerResponseException(
      'Element Explorer $name must be a JSON object.',
    );
  }
  return <String, dynamic>{
    for (final entry in source.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

String _requiredString(Map<String, dynamic> payload, String name) {
  final value = payload[name];
  if (value is String && value.isNotEmpty) return value;
  throw ElementExplorerResponseException('$name must be a non-empty string.');
}

String? _optionalString(Map<String, dynamic> payload, String name) {
  final value = payload[name];
  if (value == null) return null;
  if (value is String) return value;
  throw ElementExplorerResponseException('$name must be a string or null.');
}

int _requiredInt(Map<String, dynamic> payload, String name) {
  final value = payload[name];
  if (value is int) return value;
  throw ElementExplorerResponseException('$name must be an integer.');
}

bool _requiredBool(Map<String, dynamic> payload, String name) {
  final value = payload[name];
  if (value is bool) return value;
  throw ElementExplorerResponseException('$name must be a boolean.');
}

Map<String, dynamic>? _optionalMap(Map<String, dynamic> payload, String name) {
  final value = payload[name];
  if (value == null) return null;
  if (value is! Map) {
    throw ElementExplorerResponseException('$name must be an object or null.');
  }
  return <String, dynamic>{
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

List<String> _stringList(Object? value) {
  if (value == null) return const <String>[];
  if (value is! List) return const <String>[];
  return List.unmodifiable(value.whereType<String>());
}
