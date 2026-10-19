import 'element_explorer_model.dart';

enum ElementExplorerDisplayMode { pruned, raw }

enum ElementExplorerRelevanceRole {
  target,
  identity,
  context,
  structural,
  frameworkWrapper,
  unexplored,
  unknown,
}

enum ElementExplorerPruningDecision { keep, collapse, group, prune }

class ElementExplorerProjectionNode {
  const ElementExplorerProjectionNode({
    required this.projectionId,
    required this.rawNodeId,
    required this.rawNode,
    required this.children,
    required this.decision,
    required this.reason,
    this.synthetic = false,
    this.label,
    this.hiddenNodeIds = const <String>[],
  });

  final String projectionId;
  final String? rawNodeId;
  final ElementExplorerNode? rawNode;
  final List<ElementExplorerProjectionNode> children;
  final ElementExplorerPruningDecision decision;
  final String reason;
  final bool synthetic;
  final String? label;
  final List<String> hiddenNodeIds;
}

class ElementExplorerHiddenPath {
  const ElementExplorerHiddenPath({
    required this.nodeIds,
    required this.parentNodeId,
    required this.decision,
    required this.reason,
  });

  final List<String> nodeIds;
  final String? parentNodeId;
  final ElementExplorerPruningDecision decision;
  final String reason;
}

class ElementExplorerProjection {
  const ElementExplorerProjection({
    required this.root,
    required this.originalNodeCount,
    required this.visibleNodeCount,
    required this.hiddenNodeIds,
    required this.hiddenPaths,
  });

  final ElementExplorerProjectionNode root;
  final int originalNodeCount;
  final int visibleNodeCount;
  final Set<String> hiddenNodeIds;
  final Map<String, ElementExplorerHiddenPath> hiddenPaths;

  int get hiddenNodeCount => hiddenNodeIds.length;

  ElementExplorerProjectionNode? findByRawNodeId(String nodeId) {
    ElementExplorerProjectionNode? visit(ElementExplorerProjectionNode node) {
      if (node.rawNodeId == nodeId) return node;
      for (final child in node.children) {
        final result = visit(child);
        if (result != null) return result;
      }
      return null;
    }

    return visit(root);
  }
}

class ElementExplorerPruningEngine {
  const ElementExplorerPruningEngine._();

  static ElementExplorerProjection project(
    ElementExplorerSnapshot snapshot, {
    Set<String> revealedNodeIds = const <String>{},
  }) {
    final nodesById = <String, ElementExplorerNode>{};
    final parentById = <String, String?>{};

    void index(ElementExplorerNode node) {
      nodesById[node.nodeId] = node;
      parentById[node.nodeId] = node.parentId;
      for (final child in node.children) {
        index(child);
      }
    }

    index(snapshot.root);
    final rawTarget = nodesById.values.where((node) => node.isTarget);
    final target = rawTarget.isEmpty ? null : rawTarget.single;
    final targetPath = <String>{};
    String? pathNodeId = target?.nodeId;
    while (pathNodeId != null) {
      targetPath.add(pathNodeId);
      pathNodeId = parentById[pathNodeId];
    }

    final mustKeep = <String>{...targetPath};
    for (final revealedId in revealedNodeIds) {
      var current = revealedId;
      while (true) {
        mustKeep.add(current);
        final parent = parentById[current];
        if (parent == null) break;
        current = parent;
      }
    }

    final hiddenNodeIds = <String>{};
    final hiddenPaths = <String, ElementExplorerHiddenPath>{};

    ElementExplorerProjectionNode? build(ElementExplorerNode node) {
      final roles = _rolesFor(node, targetPath);
      final keep =
          mustKeep.contains(node.nodeId) ||
          roles.contains(ElementExplorerRelevanceRole.target) ||
          roles.contains(ElementExplorerRelevanceRole.identity) ||
          roles.contains(ElementExplorerRelevanceRole.context) ||
          roles.contains(ElementExplorerRelevanceRole.structural) ||
          roles.contains(ElementExplorerRelevanceRole.unknown);

      if (!keep && roles.contains(ElementExplorerRelevanceRole.unexplored)) {
        hiddenNodeIds.add(node.nodeId);
        hiddenPaths[node.nodeId] = ElementExplorerHiddenPath(
          nodeIds: <String>[node.nodeId],
          parentNodeId: node.parentId,
          decision: ElementExplorerPruningDecision.group,
          reason: 'Unexplored branch',
        );
        return ElementExplorerProjectionNode(
          projectionId: 'group:${node.nodeId}',
          rawNodeId: null,
          rawNode: null,
          children: const <ElementExplorerProjectionNode>[],
          decision: ElementExplorerPruningDecision.group,
          reason: 'Unexplored branch',
          synthetic: true,
          label: 'Unexplored branch',
          hiddenNodeIds: <String>[node.nodeId],
        );
      }

      if (!keep && node.children.isEmpty) {
        hiddenNodeIds.add(node.nodeId);
        hiddenPaths[node.nodeId] = ElementExplorerHiddenPath(
          nodeIds: <String>[node.nodeId],
          parentNodeId: node.parentId,
          decision: ElementExplorerPruningDecision.prune,
          reason: 'No finder or structural signal',
        );
        return null;
      }

      final children = <ElementExplorerProjectionNode>[];
      final omittedIds = <String>[];
      for (final child in node.children) {
        final projectionChild = build(child);
        if (projectionChild == null) {
          omittedIds.add(child.nodeId);
        } else {
          children.add(projectionChild);
        }
      }
      if (omittedIds.isNotEmpty) {
        final groupId = 'group:${node.nodeId}';
        children.add(
          ElementExplorerProjectionNode(
            projectionId: groupId,
            rawNodeId: null,
            rawNode: null,
            children: const <ElementExplorerProjectionNode>[],
            decision: ElementExplorerPruningDecision.group,
            reason: 'Hidden Elements can be revealed',
            synthetic: true,
            label: 'Hidden ${omittedIds.length} Elements',
            hiddenNodeIds: List.unmodifiable(omittedIds),
          ),
        );
      }

      if (!keep && children.isNotEmpty) {
        final hiddenId = 'collapse:${node.nodeId}';
        hiddenNodeIds.add(node.nodeId);
        hiddenPaths[node.nodeId] = ElementExplorerHiddenPath(
          nodeIds: <String>[node.nodeId],
          parentNodeId: node.parentId,
          decision: ElementExplorerPruningDecision.collapse,
          reason: 'Framework wrapper without finder signal',
        );
        return ElementExplorerProjectionNode(
          projectionId: hiddenId,
          rawNodeId: null,
          rawNode: null,
          children: List.unmodifiable(children),
          decision: ElementExplorerPruningDecision.collapse,
          reason: 'Framework wrapper without finder signal',
          synthetic: true,
          label: node.widgetType,
          hiddenNodeIds: <String>[node.nodeId],
        );
      }

      return ElementExplorerProjectionNode(
        projectionId: node.nodeId,
        rawNodeId: node.nodeId,
        rawNode: node,
        children: List.unmodifiable(children),
        decision: ElementExplorerPruningDecision.keep,
        reason: roles.join(', '),
      );
    }

    final root = build(snapshot.root)!;
    final visibleNodeCount = _countRawNodes(root);
    return ElementExplorerProjection(
      root: root,
      originalNodeCount: nodesById.length,
      visibleNodeCount: visibleNodeCount,
      hiddenNodeIds: Set.unmodifiable(hiddenNodeIds),
      hiddenPaths: Map.unmodifiable(hiddenPaths),
    );
  }

  static ElementExplorerProjection raw(ElementExplorerSnapshot snapshot) {
    ElementExplorerProjectionNode build(ElementExplorerNode node) {
      return ElementExplorerProjectionNode(
        projectionId: node.nodeId,
        rawNodeId: node.nodeId,
        rawNode: node,
        children: node.children.map(build).toList(growable: false),
        decision: ElementExplorerPruningDecision.keep,
        reason: 'Original snapshot',
      );
    }

    final root = build(snapshot.root);
    return ElementExplorerProjection(
      root: root,
      originalNodeCount: snapshot.root.nodeCount,
      visibleNodeCount: snapshot.root.nodeCount,
      hiddenNodeIds: const <String>{},
      hiddenPaths: const <String, ElementExplorerHiddenPath>{},
    );
  }

  static Set<ElementExplorerRelevanceRole> _rolesFor(
    ElementExplorerNode node,
    Set<String> targetPath,
  ) {
    final roles = <ElementExplorerRelevanceRole>{};
    if (node.isTarget) roles.add(ElementExplorerRelevanceRole.target);
    if (targetPath.contains(node.nodeId)) {
      roles.add(ElementExplorerRelevanceRole.context);
    }
    if (node.key?['finderCompatible'] == true ||
        (node.semanticsIdentifier?.isNotEmpty ?? false) ||
        (node.text?.isNotEmpty ?? false)) {
      roles.add(ElementExplorerRelevanceRole.identity);
    }
    if (node.childrenState == 'partial' ||
        node.childrenState == 'truncated' ||
        node.children.length > 1 ||
        (node.childrenState == 'complete' && node.children.isNotEmpty)) {
      roles.add(ElementExplorerRelevanceRole.structural);
    }
    if (node.childrenState == 'notRequested' && !node.isTarget) {
      roles.add(ElementExplorerRelevanceRole.unexplored);
    }
    if (node.metadataErrors.isNotEmpty) {
      roles.add(ElementExplorerRelevanceRole.unknown);
    }
    if (roles.isEmpty && node.children.length == 1) {
      roles.add(ElementExplorerRelevanceRole.frameworkWrapper);
    }
    return roles;
  }

  static int _countRawNodes(ElementExplorerProjectionNode node) {
    return (node.rawNodeId == null ? 0 : 1) +
        node.children.fold<int>(
          0,
          (total, child) => total + _countRawNodes(child),
        );
  }
}
