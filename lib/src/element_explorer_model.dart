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
    this.collection,
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
    final collection = _parseCollection(payload['collection']);
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
        collection: collection,
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
      collection: collection,
      snapshot: ElementExplorerSnapshot(root: root),
    );
  }

  final int schemaVersion;
  final int matchCount;
  final int returnedNodes;
  final int visitedNodes;
  final bool truncated;
  final ElementExplorerCollection? collection;
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

  ElementExplorerNode? findByInspectorValueId(String valueId) {
    ElementExplorerNode? visit(ElementExplorerNode node) {
      if (node.inspectorValueId == valueId) return node;
      for (final child in node.children) {
        final result = visit(child);
        if (result != null) return result;
      }
      return null;
    }

    return visit(root);
  }
}

class ElementExplorerCollection {
  const ElementExplorerCollection({
    required this.mode,
    required this.ancestorLevelsCollected,
    required this.rootReached,
    required this.contextNodesCollected,
    required this.stopReasons,
    required this.limits,
  });

  final String mode;
  final int ancestorLevelsCollected;
  final bool? rootReached;
  final int contextNodesCollected;
  final List<String> stopReasons;
  final ElementExplorerCollectionLimits limits;
}

class ElementExplorerCollectionLimits {
  const ElementExplorerCollectionLimits({
    required this.maxAncestorDepth,
    required this.maxContextNodes,
    required this.maxVisitedNodes,
    required this.maxReturnedNodes,
  });

  final int maxAncestorDepth;
  final int maxContextNodes;
  final int maxVisitedNodes;
  final int maxReturnedNodes;
}

class ElementExplorerNode {
  const ElementExplorerNode({
    required this.nodeId,
    required this.parentId,
    this.inspectorValueId,
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
  final String? inspectorValueId;
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
    inspectorValueId: _optionalString(payload, 'inspectorValueId'),
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
  return Map<String, dynamic>.unmodifiable(<String, dynamic>{
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  });
}

ElementExplorerCollection? _parseCollection(Object? source) {
  if (source == null) return null;
  final payload = _asMap(source, 'collection');
  final mode = _requiredString(payload, 'mode');
  if (mode != 'limited' && mode != 'toRoot') {
    throw ElementExplorerResponseException('Unknown collection mode: $mode.');
  }
  final rootReachedValue = payload['rootReached'];
  final bool? rootReached;
  if (rootReachedValue == null) {
    rootReached = null;
  } else if (rootReachedValue is bool) {
    rootReached = rootReachedValue;
  } else {
    throw const ElementExplorerResponseException(
      'rootReached must be a boolean or null.',
    );
  }
  final rawStopReasons = payload['stopReasons'];
  if (rawStopReasons is! List ||
      rawStopReasons.any((value) => value is! String)) {
    throw const ElementExplorerResponseException(
      'stopReasons must be a list of strings.',
    );
  }
  final limits = _asMap(payload['limits'], 'collection.limits');
  return ElementExplorerCollection(
    mode: mode,
    ancestorLevelsCollected: _nonNegativeInt(
      payload,
      'ancestorLevelsCollected',
    ),
    rootReached: rootReached,
    contextNodesCollected: _nonNegativeInt(payload, 'contextNodesCollected'),
    stopReasons: List.unmodifiable(rawStopReasons.cast<String>()),
    limits: ElementExplorerCollectionLimits(
      maxAncestorDepth: _positiveInt(limits, 'maxAncestorDepth'),
      maxContextNodes: _positiveOrZeroInt(limits, 'maxContextNodes'),
      maxVisitedNodes: _positiveInt(limits, 'maxVisitedNodes'),
      maxReturnedNodes: _positiveInt(limits, 'maxReturnedNodes'),
    ),
  );
}

int _nonNegativeInt(Map<String, dynamic> payload, String name) {
  final value = _requiredInt(payload, name);
  if (value < 0) {
    throw ElementExplorerResponseException('$name must not be negative.');
  }
  return value;
}

int _positiveInt(Map<String, dynamic> payload, String name) {
  final value = _requiredInt(payload, name);
  if (value <= 0) {
    throw ElementExplorerResponseException('$name must be positive.');
  }
  return value;
}

int _positiveOrZeroInt(Map<String, dynamic> payload, String name) {
  final value = _requiredInt(payload, name);
  if (value < 0) {
    throw ElementExplorerResponseException('$name must not be negative.');
  }
  return value;
}

List<String> _stringList(Object? value) {
  if (value == null) return const <String>[];
  if (value is! List) return const <String>[];
  return List.unmodifiable(value.whereType<String>());
}
