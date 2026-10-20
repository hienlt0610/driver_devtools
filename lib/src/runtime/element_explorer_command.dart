// Copy this file into the Flutter application that owns the widget tree.
// Register it before runApp:
//
//   enableFlutterDriverExtension(
//     commands: <CommandExtension>[ElementExplorerCommandExtension()],
//   );
// Flutter exposes Inspector identity methods as protected VM-inspector APIs.
// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:flutter_test/flutter_test.dart';

const String elementExplorerCommandKind = 'element_explorer';
const int elementExplorerSchemaVersion = 1;

/// The bounded options accepted by [ElementExplorerCommandExtension].
class ElementExplorerOptions {
  const ElementExplorerOptions({
    this.ancestorDepth = 3,
    this.descendantDepth = 1,
    this.includeSiblings = true,
    this.siblingDepth = 0,
    this.maxNodes = 200,
    this.mode = 'limited',
    this.maxAncestorDepth = 256,
    this.maxContextNodes = 200,
    this.maxVisitedNodes = 1000,
    this.maxReturnedNodes = 500,
    this.usesV2 = false,
    this.inspectorValueId,
    this.inspectorObjectGroup,
  });

  static const int maxDepth = 32;
  static const int maxAncestorDepthBudget = 256;
  static const int maxNodeBudget = 2000;
  static const int maxVisitedNodeBudget = 10000;

  final int ancestorDepth;
  final int descendantDepth;
  final bool includeSiblings;
  final int siblingDepth;
  final int maxNodes;
  final String mode;
  final int maxAncestorDepth;
  final int maxContextNodes;
  final int maxVisitedNodes;
  final int maxReturnedNodes;
  final bool usesV2;
  final String? inspectorValueId;
  final String? inspectorObjectGroup;

  factory ElementExplorerOptions.fromParams(Map<String, String> params) {
    final bool usesV2 = params.keys.any(
      <String>{
        'mode',
        'maxAncestorDepth',
        'maxContextNodes',
        'maxVisitedNodes',
        'maxReturnedNodes',
      }.contains,
    );
    final String mode = params['mode'] ?? 'limited';
    if (mode != 'limited' && mode != 'toRoot') {
      throw FormatException('mode must be limited or toRoot');
    }
    final int ancestorDepth = _readInt(
      params,
      'ancestorDepth',
      defaultValue: usesV2 ? maxDepth : 3,
    );
    final int descendantDepth = _readInt(
      params,
      'descendantDepth',
      defaultValue: 1,
    );
    final bool includeSiblings = _readBool(
      params,
      'includeSiblings',
      defaultValue: true,
    );
    final int siblingDepth = _readInt(params, 'siblingDepth', defaultValue: 0);
    final int maxNodes = _readInt(
      params,
      'maxNodes',
      defaultValue: usesV2 ? 500 : 200,
    );
    final int maxAncestorDepth = _readInt(
      params,
      'maxAncestorDepth',
      defaultValue: maxAncestorDepthBudget,
    );
    final int maxContextNodes = _readInt(
      params,
      'maxContextNodes',
      defaultValue: 200,
    );
    final int maxVisitedNodes = _readInt(
      params,
      'maxVisitedNodes',
      defaultValue: 1000,
    );
    final int maxReturnedNodes = _readInt(
      params,
      'maxReturnedNodes',
      defaultValue: maxNodes,
    );
    final String? inspectorValueId = params['inspectorValueId'];
    final String? inspectorObjectGroup = params['inspectorObjectGroup'];
    if (inspectorValueId != null && inspectorValueId.isEmpty) {
      throw FormatException('inspectorValueId must not be empty');
    }
    if (inspectorObjectGroup != null && inspectorObjectGroup.isEmpty) {
      throw FormatException('inspectorObjectGroup must not be empty');
    }

    for (final MapEntry<String, int> entry in <MapEntry<String, int>>[
      MapEntry<String, int>('ancestorDepth', ancestorDepth),
      MapEntry<String, int>('descendantDepth', descendantDepth),
      MapEntry<String, int>('siblingDepth', siblingDepth),
    ]) {
      if (entry.value < 0 || entry.value > maxDepth) {
        throw FormatException('${entry.key} must be between 0 and $maxDepth');
      }
    }
    if (maxNodes <= 0 || maxNodes > maxNodeBudget) {
      throw FormatException('maxNodes must be between 1 and $maxNodeBudget');
    }
    if (maxAncestorDepth <= 0 || maxAncestorDepth > maxAncestorDepthBudget) {
      throw FormatException(
        'maxAncestorDepth must be between 1 and $maxAncestorDepthBudget',
      );
    }
    if (maxContextNodes < 0 || maxContextNodes > maxNodeBudget) {
      throw FormatException(
        'maxContextNodes must be between 0 and $maxNodeBudget',
      );
    }
    if (maxVisitedNodes <= 0 || maxVisitedNodes > maxVisitedNodeBudget) {
      throw FormatException(
        'maxVisitedNodes must be between 1 and $maxVisitedNodeBudget',
      );
    }
    if (maxReturnedNodes <= 0 || maxReturnedNodes > maxNodeBudget) {
      throw FormatException(
        'maxReturnedNodes must be between 1 and $maxNodeBudget',
      );
    }

    return ElementExplorerOptions(
      ancestorDepth: ancestorDepth,
      descendantDepth: descendantDepth,
      includeSiblings: includeSiblings,
      siblingDepth: siblingDepth,
      maxNodes: maxNodes,
      mode: mode,
      maxAncestorDepth: maxAncestorDepth,
      maxContextNodes: maxContextNodes,
      maxVisitedNodes: maxVisitedNodes,
      maxReturnedNodes: maxReturnedNodes,
      usesV2: usesV2,
      inspectorValueId: inspectorValueId,
      inspectorObjectGroup: inspectorObjectGroup,
    );
  }

  Map<String, String> toParams() {
    final params = <String, String>{
      'ancestorDepth': '$ancestorDepth',
      'descendantDepth': '$descendantDepth',
      'includeSiblings': '$includeSiblings',
      'siblingDepth': '$siblingDepth',
      'maxNodes': '$maxNodes',
    };
    if (usesV2) {
      params.addAll(<String, String>{
        'mode': mode,
        'maxAncestorDepth': '$maxAncestorDepth',
        'maxContextNodes': '$maxContextNodes',
        'maxVisitedNodes': '$maxVisitedNodes',
        'maxReturnedNodes': '$maxReturnedNodes',
      });
    }
    if (inspectorValueId != null) {
      params['inspectorValueId'] = inspectorValueId!;
    }
    if (inspectorObjectGroup != null) {
      params['inspectorObjectGroup'] = inspectorObjectGroup!;
    }
    return params;
  }

  static int _readInt(
    Map<String, String> params,
    String name, {
    required int defaultValue,
  }) {
    final String? raw = params[name];
    if (raw == null) {
      return defaultValue;
    }
    final int? value = int.tryParse(raw);
    if (value == null) {
      throw FormatException('$name must be an integer');
    }
    return value;
  }

  static bool _readBool(
    Map<String, String> params,
    String name, {
    required bool defaultValue,
  }) {
    final String? raw = params[name];
    if (raw == null) {
      return defaultValue;
    }
    if (raw == 'true') {
      return true;
    }
    if (raw == 'false') {
      return false;
    }
    throw FormatException('$name must be true or false');
  }
}

/// A command object that keeps the serialized Finder and inspection options.
class ElementExplorerCommand extends Command {
  ElementExplorerCommand({
    required this.finder,
    required this.options,
    this.argumentError,
    super.timeout,
  });

  factory ElementExplorerCommand.deserialize(
    Map<String, String> params,
    DeserializeFinderFactory finderFactory,
  ) {
    SerializableFinder? finder;
    String? argumentError;
    Duration? timeout;

    try {
      timeout = _parseTimeout(params);
    } on FormatException catch (error) {
      argumentError = error.message;
    }

    if (params['inspectorValueId'] != null) {
      if (params.containsKey('finderType')) {
        argumentError =
            'A request cannot contain both a Finder and inspectorValueId';
      }
    } else {
      try {
        finder = finderFactory.deserializeFinder(params);
      } catch (error) {
        argumentError ??= 'Invalid Finder: $error';
      }
    }

    ElementExplorerOptions options;
    try {
      options = ElementExplorerOptions.fromParams(params);
    } catch (error) {
      options = const ElementExplorerOptions();
      argumentError ??= 'Invalid inspection options: $error';
    }

    return ElementExplorerCommand(
      finder: finder,
      options: options,
      argumentError: argumentError,
      timeout: timeout,
    );
  }

  final SerializableFinder? finder;
  final ElementExplorerOptions options;
  final String? argumentError;

  @override
  String get kind => elementExplorerCommandKind;

  @override
  Map<String, String> serialize() {
    final Map<String, String> result = super.serialize();
    if (finder != null) {
      result.addAll(finder!.serialize());
    }
    result.addAll(options.toParams());
    return result;
  }

  static Duration? _parseTimeout(Map<String, String> params) {
    final String? raw = params['timeout'];
    if (raw == null) {
      return null;
    }
    final int? milliseconds = int.tryParse(raw);
    if (milliseconds == null) {
      throw FormatException(
        'timeout must be an integer number of milliseconds',
      );
    }
    return Duration(milliseconds: milliseconds);
  }
}

/// Flutter Driver command that snapshots a bounded Element hierarchy around
/// either exactly one Finder match or an Inspector [Element] value ID without
/// waiting, tapping, scrolling, or mutating application state.
class ElementExplorerCommandExtension extends CommandExtension {
  @override
  String get commandKind => elementExplorerCommandKind;

  @override
  Command deserialize(
    Map<String, String> params,
    DeserializeFinderFactory finderFactory,
    DeserializeCommandFactory commandFactory,
  ) {
    return ElementExplorerCommand.deserialize(params, finderFactory);
  }

  @override
  Future<Result> call(
    Command command,
    WidgetController prober,
    CreateFinderFactory finderFactory,
    CommandHandlerFactory handlerFactory,
  ) async {
    if (command is! ElementExplorerCommand) {
      return ElementExplorerResult.error(
        code: 'INSPECTION_FAILED',
        message: 'Unexpected command type for $elementExplorerCommandKind',
      );
    }
    if (command.argumentError != null ||
        (command.finder == null && command.options.inspectorValueId == null)) {
      return ElementExplorerResult.error(
        code: 'INVALID_ARGUMENT',
        message:
            command.argumentError ??
            'A serialized Finder or Inspector valueId is required',
      );
    }

    final Element target;
    if (command.options.inspectorValueId != null) {
      try {
        final Object? resolved = WidgetInspectorService.instance.toObject(
          command.options.inspectorValueId,
          command.options.inspectorObjectGroup,
        );
        if (resolved is! Element) {
          return ElementExplorerResult.error(
            code: 'INSPECTOR_ID_INVALID',
            message: 'Inspector valueId does not refer to an Element',
          );
        }
        target = resolved;
      } catch (error) {
        return ElementExplorerResult.error(
          code: 'INSPECTOR_ID_INVALID',
          message: 'Inspector valueId is unavailable: $error',
        );
      }
    } else {
      final Finder finder;
      try {
        finder = finderFactory.createFinder(command.finder!);
      } catch (error) {
        return ElementExplorerResult.error(
          code: 'INVALID_ARGUMENT',
          message: 'Finder is not supported by this Flutter runtime: $error',
        );
      }

      final List<Element> matches;
      try {
        matches = finder.evaluate().toList(growable: false);
      } catch (error) {
        return ElementExplorerResult.error(
          code: 'INSPECTION_FAILED',
          message: 'Finder evaluation failed: $error',
        );
      }

      if (matches.isEmpty) {
        return ElementExplorerResult.error(
          code: 'TARGET_NOT_FOUND',
          message: 'The Finder did not match an Element',
          matchCount: 0,
        );
      }
      if (matches.length != 1) {
        return ElementExplorerResult.error(
          code: 'AMBIGUOUS_TARGET',
          message: 'The Finder matched ${matches.length} Elements',
          matchCount: matches.length,
        );
      }
      target = matches.single;
    }

    if (!target.mounted) {
      return ElementExplorerResult.error(
        code:
            command.options.inspectorValueId == null
                ? 'INSPECTION_FAILED'
                : 'INSPECTOR_ID_INVALID',
        message:
            command.options.inspectorValueId == null
                ? 'The matched Element was unmounted before inspection'
                : 'The Inspector Element is no longer mounted',
        matchCount: 1,
      );
    }

    try {
      final _ElementSnapshotData snapshot =
          _ElementSnapshot(target: target, options: command.options).build();
      return ElementExplorerResult.success(snapshot.toJson());
    } on _ElementExplorerFailure catch (error) {
      return ElementExplorerResult.error(
        code: error.code,
        message: error.message,
        matchCount: 1,
      );
    } catch (error) {
      return ElementExplorerResult.error(
        code: 'INSPECTION_FAILED',
        message: 'Element inspection failed: $error',
        matchCount: 1,
      );
    }
  }
}

class ElementExplorerResult extends Result {
  const ElementExplorerResult._(this._payload);

  factory ElementExplorerResult.success(Map<String, dynamic> snapshot) {
    return ElementExplorerResult._(<String, dynamic>{
      'schemaVersion': elementExplorerSchemaVersion,
      ...snapshot,
    });
  }

  factory ElementExplorerResult.error({
    required String code,
    required String message,
    int matchCount = 0,
  }) {
    return ElementExplorerResult._(<String, dynamic>{
      'schemaVersion': elementExplorerSchemaVersion,
      'matchCount': matchCount,
      'returnedNodes': 0,
      'visitedNodes': 0,
      'truncated': false,
      'error': <String, dynamic>{'code': code, 'message': message},
    });
  }

  final Map<String, dynamic> _payload;

  @override
  Map<String, dynamic> toJson() => _payload;
}

class _ElementExplorerFailure implements Exception {
  const _ElementExplorerFailure(this.code, this.message);

  final String code;
  final String message;
}

class _ElementSnapshot {
  _ElementSnapshot({required this.target, required this.options});

  final Element target;
  final ElementExplorerOptions options;
  final List<Element> _path = <Element>[];
  final Map<Element, Element> _pathChildren = <Element, Element>{};
  final Map<Element, int> _pathIndexes = <Element, int>{};
  final Set<Element> _visited = Set<Element>.identity();
  final Set<String> _stopReasons = <String>{};
  int _returnedNodes = 0;
  int _contextNodes = 0;
  int _legacyVisitedNodes = 0;
  bool _truncated = false;
  bool _ancestorDepthLimitReached = false;
  bool _visitLimitReached = false;

  int get _returnedLimit =>
      options.usesV2 ? options.maxReturnedNodes : options.maxNodes;

  _ElementSnapshotData build() {
    if (!target.mounted) {
      throw const _ElementExplorerFailure(
        'INSPECTION_FAILED',
        'The target Element is no longer mounted',
      );
    }

    _markVisited(target);
    final List<Element> ancestors = <Element>[];
    bool reachedRoot = false;
    if (options.mode == 'toRoot' && options.usesV2) {
      target.visitAncestorElements((Element ancestor) {
        if (!_markVisited(ancestor)) return false;
        if (ancestors.length >= options.maxAncestorDepth) {
          _ancestorDepthLimitReached = true;
          _stopReasons.add('ANCESTOR_DEPTH_LIMIT');
          return false;
        }
        ancestors.add(ancestor);
        return true;
      });
      reachedRoot = !_ancestorDepthLimitReached && !_visitLimitReached;
    } else if (options.ancestorDepth > 0) {
      target.visitAncestorElements((Element ancestor) {
        if (!_markVisited(ancestor)) return false;
        ancestors.add(ancestor);
        return ancestors.length < options.ancestorDepth;
      });
    }

    _path.addAll(ancestors.reversed);
    _path.add(target);
    if (!options.usesV2 && options.maxNodes < _path.length) {
      throw const _ElementExplorerFailure(
        'NODE_BUDGET_TOO_SMALL',
        'maxNodes is smaller than the required ancestor path',
      );
    }
    if (options.usesV2 && _returnedLimit < _path.length) {
      final int ancestorSlots = (_returnedLimit - 1).clamp(0, ancestors.length);
      final int firstAncestor = ancestors.length - ancestorSlots;
      _path
        ..clear()
        ..addAll(ancestors.reversed.skip(firstAncestor))
        ..add(target);
      _stopReasons.add('RESPONSE_NODE_LIMIT');
    }

    for (int index = 0; index < _path.length; index++) {
      _pathIndexes[_path[index]] = index;
      if (index + 1 < _path.length) {
        _pathChildren[_path[index]] = _path[index + 1];
      }
    }

    final Map<String, dynamic> root = _buildPathNode(_path.first, null);
    final bool truncated =
        options.usesV2 ? _stopReasons.isNotEmpty : _truncated;
    return _ElementSnapshotData(
      root: root,
      returnedNodes: _returnedNodes,
      visitedNodes: options.usesV2 ? _visited.length : _legacyVisitedNodes,
      truncated: truncated,
      collection:
          options.usesV2
              ? <String, dynamic>{
                'mode': options.mode,
                'ancestorLevelsCollected': ancestors.length,
                'rootReached': options.mode == 'toRoot' ? reachedRoot : null,
                'contextNodesCollected': _contextNodes,
                'stopReasons': _stopReasons.toList(growable: false),
                'limits': <String, dynamic>{
                  'maxAncestorDepth': options.maxAncestorDepth,
                  'maxContextNodes': options.maxContextNodes,
                  'maxVisitedNodes': options.maxVisitedNodes,
                  'maxReturnedNodes': options.maxReturnedNodes,
                },
              }
              : null,
    );
  }

  bool _markVisited(Element element) {
    if (!options.usesV2) {
      _legacyVisitedNodes++;
      return true;
    }
    if (_visited.contains(element)) return true;
    if (options.usesV2 && _visited.length >= options.maxVisitedNodes) {
      _visitLimitReached = true;
      _stopReasons.add('NODE_VISIT_LIMIT');
      return false;
    }
    _visited.add(element);
    return true;
  }

  bool _canBuildContext() {
    if (_returnedNodes >= _returnedLimit) {
      _truncated = true;
      _stopReasons.add('RESPONSE_NODE_LIMIT');
      return false;
    }
    if (options.usesV2 && _contextNodes >= options.maxContextNodes) {
      _stopReasons.add('CONTEXT_NODE_LIMIT');
      return false;
    }
    return true;
  }

  Map<String, dynamic> _buildPathNode(Element element, String? parentId) {
    final int pathIndex = _pathIndexes[element]!;
    final Map<String, dynamic> node = _newNode(element, parentId);
    if (pathIndex == _path.length - 1) {
      _populateDepthChildren(node, element, options.descendantDepth);
    } else {
      _populatePathChildren(node, element);
    }
    return node;
  }

  Map<String, dynamic> _buildDepthNode(
    Element element,
    String parentId,
    int remainingDepth,
  ) {
    final Map<String, dynamic> node = _newNode(
      element,
      parentId,
      context: true,
    );
    _populateDepthChildren(node, element, remainingDepth);
    return node;
  }

  Map<String, dynamic> _newNode(
    Element element,
    String? parentId, {
    bool context = false,
  }) {
    if (!element.mounted) {
      throw const _ElementExplorerFailure(
        'INSPECTION_FAILED',
        'An Element was unmounted during inspection',
      );
    }
    if (_returnedNodes >= _returnedLimit) {
      throw const _ElementExplorerFailure(
        'NODE_BUDGET_TOO_SMALL',
        'The response budget cannot contain the required Element path',
      );
    }

    final Map<String, dynamic> node = <String, dynamic>{
      'nodeId': 'n$_returnedNodes',
      'parentId': parentId,
      if (options.inspectorObjectGroup != null)
        'inspectorValueId': WidgetInspectorService.instance.toId(
          element,
          options.inspectorObjectGroup!,
        ),
      'widgetType': element.widget.runtimeType.toString(),
      'elementType': element.runtimeType.toString(),
      'key': null,
      'text': null,
      'semanticsIdentifier': null,
      'isTarget': identical(element, target),
      'childrenState': 'notRequested',
      'children': <Map<String, dynamic>>[],
    };
    _returnedNodes++;
    if (context) _contextNodes++;
    _addMetadata(node, element);
    return node;
  }

  void _populatePathChildren(Map<String, dynamic> node, Element element) {
    final _ChildrenResult result = _childrenOf(element);
    final List<Element> children = result.children;
    final Element? pathChild = _pathChildren[element];
    if (pathChild == null) {
      node['childrenState'] = result.omitted ? 'truncated' : 'complete';
      return;
    }
    final Map<Element, Map<String, dynamic>> serialized =
        <Element, Map<String, dynamic>>{};

    // Build the required path branch first so optional siblings cannot consume
    // the budget needed to keep the target reachable.
    serialized[pathChild] = _buildPathNode(pathChild, node['nodeId'] as String);
    bool omittedSibling = result.omitted;
    for (final Element child in children) {
      if (identical(child, pathChild)) continue;
      if (!options.includeSiblings) {
        omittedSibling = true;
        continue;
      }
      final Map<String, dynamic>? sibling = _tryBuildSibling(
        child,
        node['nodeId'] as String,
      );
      if (sibling == null) {
        omittedSibling = true;
      } else {
        serialized[child] = sibling;
      }
    }

    final List<Map<String, dynamic>> outputChildren = <Map<String, dynamic>>[];
    for (final Element child in children) {
      final Map<String, dynamic>? serializedChild = serialized[child];
      if (serializedChild != null) outputChildren.add(serializedChild);
    }
    node['children'] = outputChildren;
    node['childrenState'] =
        omittedSibling
            ? (options.includeSiblings ? 'truncated' : 'partial')
            : 'complete';
  }

  Map<String, dynamic>? _tryBuildSibling(Element element, String parentId) {
    if (!_canBuildContext()) return null;
    return _buildDepthNode(element, parentId, options.siblingDepth);
  }

  void _populateDepthChildren(
    Map<String, dynamic> node,
    Element element,
    int remainingDepth,
  ) {
    if (remainingDepth <= 0) {
      node['childrenState'] = 'notRequested';
      return;
    }

    final _ChildrenResult result = _childrenOf(element);
    final List<Element> outputChildren = <Element>[];
    bool omittedChild = result.omitted;
    final List<Map<String, dynamic>> serialized = <Map<String, dynamic>>[];
    for (final Element child in result.children) {
      if (!_canBuildContext()) {
        omittedChild = true;
        continue;
      }
      serialized.add(
        _buildDepthNode(child, node['nodeId'] as String, remainingDepth - 1),
      );
      outputChildren.add(child);
    }
    node['children'] = serialized;
    node['childrenState'] =
        omittedChild
            ? 'truncated'
            : (outputChildren.isEmpty ? 'empty' : 'complete');
  }

  _ChildrenResult _childrenOf(Element element) {
    if (!element.mounted) {
      throw const _ElementExplorerFailure(
        'INSPECTION_FAILED',
        'An Element was unmounted during inspection',
      );
    }
    final List<Element> children = <Element>[];
    bool omitted = false;
    // visitChildren cannot stop enumeration early; the budget stops recording
    // and recursive collection after the limit is reached.
    element.visitChildren((Element child) {
      if (_markVisited(child)) {
        children.add(child);
      } else {
        omitted = true;
      }
    });
    return _ChildrenResult(children, omitted);
  }

  void _addMetadata(Map<String, dynamic> node, Element element) {
    final List<String> metadataErrors = <String>[];
    try {
      node['key'] = _serializeKey(element.widget.key);
    } catch (error) {
      metadataErrors.add('key: $error');
    }
    try {
      node['text'] = _directText(element.widget);
    } catch (error) {
      metadataErrors.add('text: $error');
    }
    try {
      node['semanticsIdentifier'] = _semanticsIdentifier(element);
    } catch (error) {
      metadataErrors.add('semanticsIdentifier: $error');
    }
    if (metadataErrors.isNotEmpty) {
      node['metadataErrors'] = metadataErrors;
    }
  }
}

class _ChildrenResult {
  const _ChildrenResult(this.children, this.omitted);

  final List<Element> children;
  final bool omitted;
}

class _ElementSnapshotData {
  const _ElementSnapshotData({
    required this.root,
    required this.returnedNodes,
    required this.visitedNodes,
    required this.truncated,
    this.collection,
  });

  final Map<String, dynamic> root;
  final int returnedNodes;
  final int visitedNodes;
  final bool truncated;
  final Map<String, dynamic>? collection;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'matchCount': 1,
    'returnedNodes': returnedNodes,
    'visitedNodes': visitedNodes,
    'truncated': truncated,
    if (collection != null) 'collection': collection,
    'root': root,
  };
}

String? _directText(Widget widget) {
  if (widget is Text) {
    return widget.data ??
        widget.textSpan?.toPlainText(
          includeSemanticsLabels: false,
          includePlaceholders: false,
        );
  }
  if (widget is RichText) {
    return widget.text.toPlainText(
      includeSemanticsLabels: false,
      includePlaceholders: false,
    );
  }
  if (widget is TextField) {
    return widget.controller?.text;
  }
  if (widget is TextFormField) {
    return widget.controller?.text;
  }
  if (widget is EditableText) {
    return widget.controller.text;
  }
  return null;
}

Map<String, dynamic>? _serializeKey(Key? key) {
  if (key == null) {
    return null;
  }
  if (key is ValueKey<Object?>) {
    final Object? value = key.value;
    final bool finderCompatible = value is String || value is int;
    return <String, dynamic>{
      'kind': 'ValueKey',
      'keyRuntimeType': key.runtimeType.toString(),
      'valueType': value?.runtimeType.toString() ?? 'null',
      'value': _jsonSafeScalar(value),
      'serializable': _jsonSafeScalar(value) != null || value == null,
      'finderCompatible': finderCompatible,
    };
  }
  if (key is ObjectKey) {
    return <String, dynamic>{
      'kind': 'ObjectKey',
      'keyRuntimeType': key.runtimeType.toString(),
      'valueType': key.value?.runtimeType.toString() ?? 'null',
      'serializable': false,
      'finderCompatible': false,
    };
  }
  if (key is GlobalKey) {
    return <String, dynamic>{
      'kind': 'GlobalKey',
      'keyRuntimeType': key.runtimeType.toString(),
      'serializable': false,
      'finderCompatible': false,
    };
  }
  return <String, dynamic>{
    'kind': key.runtimeType.toString(),
    'serializable': false,
    'finderCompatible': false,
  };
}

Object? _jsonSafeScalar(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  return null;
}

String? _semanticsIdentifier(Element element) {
  RenderObject? renderObject;
  if (element is RenderObjectElement) {
    renderObject = element.renderObject;
  } else if (element.widget is Text) {
    // Text is a StatelessElement whose own render object is its direct
    // RichText child. Do not recurse through arbitrary wrapper subtrees.
    element.visitChildren((Element child) {
      if (renderObject == null && child is RenderObjectElement) {
        renderObject = child.renderObject;
      }
    });
  }
  while (renderObject != null) {
    final RenderObject current = renderObject!;
    final SemanticsNode? semanticsNode = current.debugSemantics;
    final String? identifier = semanticsNode?.identifier;
    if (identifier != null && identifier.isNotEmpty) {
      return identifier;
    }
    renderObject = current.parent;
  }
  return null;
}
