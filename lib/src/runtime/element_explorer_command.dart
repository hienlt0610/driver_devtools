// Copy this file into the Flutter application that owns the widget tree.
// Register it before runApp:
//
//   enableFlutterDriverExtension(
//     commands: <CommandExtension>[ElementExplorerCommandExtension()],
//   );

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
  });

  static const int maxDepth = 32;
  static const int maxNodeBudget = 2000;

  final int ancestorDepth;
  final int descendantDepth;
  final bool includeSiblings;
  final int siblingDepth;
  final int maxNodes;

  factory ElementExplorerOptions.fromParams(Map<String, String> params) {
    final int ancestorDepth = _readInt(
      params,
      'ancestorDepth',
      defaultValue: 3,
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
    final int maxNodes = _readInt(params, 'maxNodes', defaultValue: 200);

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

    return ElementExplorerOptions(
      ancestorDepth: ancestorDepth,
      descendantDepth: descendantDepth,
      includeSiblings: includeSiblings,
      siblingDepth: siblingDepth,
      maxNodes: maxNodes,
    );
  }

  Map<String, String> toParams() => <String, String>{
    'ancestorDepth': '$ancestorDepth',
    'descendantDepth': '$descendantDepth',
    'includeSiblings': '$includeSiblings',
    'siblingDepth': '$siblingDepth',
    'maxNodes': '$maxNodes',
  };

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

    try {
      finder = finderFactory.deserializeFinder(params);
    } catch (error) {
      argumentError ??= 'Invalid Finder: $error';
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

/// Flutter Driver command that snapshots the active Element hierarchy around
/// exactly one Finder match without waiting, tapping, scrolling, or mutating
/// application state.
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
    if (command.argumentError != null || command.finder == null) {
      return ElementExplorerResult.error(
        code: 'INVALID_ARGUMENT',
        message: command.argumentError ?? 'A serialized Finder is required',
      );
    }

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

    final Element target = matches.single;
    if (!target.mounted) {
      return ElementExplorerResult.error(
        code: 'INSPECTION_FAILED',
        message: 'The matched Element was unmounted before inspection',
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
  int _returnedNodes = 0;
  int _visitedNodes = 0;
  bool _truncated = false;

  _ElementSnapshotData build() {
    if (!target.mounted) {
      throw const _ElementExplorerFailure(
        'INSPECTION_FAILED',
        'The target Element is no longer mounted',
      );
    }

    final List<Element> ancestors = <Element>[];
    if (options.ancestorDepth > 0) {
      target.visitAncestorElements((Element ancestor) {
        ancestors.add(ancestor);
        return ancestors.length < options.ancestorDepth;
      });
    }
    _path.addAll(ancestors.reversed);
    _path.add(target);
    if (options.maxNodes < _path.length) {
      throw const _ElementExplorerFailure(
        'NODE_BUDGET_TOO_SMALL',
        'maxNodes is smaller than the required ancestor path',
      );
    }

    for (int index = 0; index < _path.length; index++) {
      _pathIndexes[_path[index]] = index;
      _visitedNodes++;
      if (index + 1 < _path.length) {
        _pathChildren[_path[index]] = _path[index + 1];
      }
    }

    final Map<String, dynamic> root = _buildPathNode(_path.first, null);
    return _ElementSnapshotData(
      root: root,
      returnedNodes: _returnedNodes,
      visitedNodes: _visitedNodes,
      truncated: _truncated,
    );
  }

  Map<String, dynamic> _buildPathNode(Element element, String? parentId) {
    final int pathIndex = _pathIndexes[element]!;
    final Map<String, dynamic> node = _newNode(element, parentId);
    if (pathIndex == _path.length - 1) {
      _populateDepthChildren(
        node,
        element,
        options.descendantDepth,
        isTarget: true,
      );
    } else {
      _populatePathChildren(node, element, pathIndex);
    }
    return node;
  }

  Map<String, dynamic> _buildDepthNode(
    Element element,
    String parentId,
    int remainingDepth,
  ) {
    final Map<String, dynamic> node = _newNode(element, parentId);
    _populateDepthChildren(node, element, remainingDepth);
    return node;
  }

  Map<String, dynamic> _newNode(Element element, String? parentId) {
    if (!element.mounted) {
      throw const _ElementExplorerFailure(
        'INSPECTION_FAILED',
        'An Element was unmounted during inspection',
      );
    }
    if (_returnedNodes >= options.maxNodes) {
      throw const _ElementExplorerFailure(
        'NODE_BUDGET_TOO_SMALL',
        'maxNodes cannot contain the required Element path',
      );
    }

    final Map<String, dynamic> node = <String, dynamic>{
      'nodeId': 'n$_returnedNodes',
      'parentId': parentId,
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
    _addMetadata(node, element);
    return node;
  }

  void _populatePathChildren(
    Map<String, dynamic> node,
    Element element,
    int pathIndex,
  ) {
    final List<Element> children = _childrenOf(element);
    final Element pathChild = _pathChildren[element]!;
    final Map<Element, Map<String, dynamic>> serialized =
        <Element, Map<String, dynamic>>{};

    // Build the required path branch first so optional siblings cannot consume
    // the budget needed to keep the target reachable.
    serialized[pathChild] = _buildPathNode(pathChild, node['nodeId'] as String);
    bool omittedSibling = false;
    for (final Element child in children) {
      if (identical(child, pathChild)) {
        continue;
      }
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
      if (serializedChild != null) {
        outputChildren.add(serializedChild);
      }
    }
    node['children'] = outputChildren;
    node['childrenState'] =
        omittedSibling
            ? (options.includeSiblings ? 'truncated' : 'partial')
            : 'complete';
  }

  Map<String, dynamic>? _tryBuildSibling(Element element, String parentId) {
    if (_returnedNodes >= options.maxNodes) {
      _truncated = true;
      return null;
    }
    return _buildDepthNode(element, parentId, options.siblingDepth);
  }

  void _populateDepthChildren(
    Map<String, dynamic> node,
    Element element,
    int remainingDepth, {
    bool isTarget = false,
  }) {
    if (remainingDepth <= 0) {
      node['childrenState'] = 'notRequested';
      return;
    }

    final List<Element> children = _childrenOf(element);
    final List<Map<String, dynamic>> outputChildren = <Map<String, dynamic>>[];
    bool omittedChild = false;
    for (final Element child in children) {
      if (_returnedNodes >= options.maxNodes) {
        _truncated = true;
        omittedChild = true;
        continue;
      }
      outputChildren.add(
        _buildDepthNode(child, node['nodeId'] as String, remainingDepth - 1),
      );
    }
    node['children'] = outputChildren;
    node['childrenState'] =
        omittedChild ? 'truncated' : (children.isEmpty ? 'empty' : 'complete');
  }

  List<Element> _childrenOf(Element element) {
    if (!element.mounted) {
      throw const _ElementExplorerFailure(
        'INSPECTION_FAILED',
        'An Element was unmounted during inspection',
      );
    }
    final List<Element> children = <Element>[];
    element.visitChildren((Element child) {
      _visitedNodes++;
      children.add(child);
    });
    return children;
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

class _ElementSnapshotData {
  const _ElementSnapshotData({
    required this.root,
    required this.returnedNodes,
    required this.visitedNodes,
    required this.truncated,
  });

  final Map<String, dynamic> root;
  final int returnedNodes;
  final int visitedNodes;
  final bool truncated;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'matchCount': 1,
    'returnedNodes': returnedNodes,
    'visitedNodes': visitedNodes,
    'truncated': truncated,
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
