import 'package:driver_devtools/src/element_explorer_model.dart';
import 'package:driver_devtools/src/element_explorer_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps target and finder identity while hiding redundant leaves', () {
    final snapshot = _snapshot();

    final projection = ElementExplorerPruningEngine.project(snapshot);

    expect(projection.root.rawNodeId, 'root');
    expect(projection.findByRawNodeId('target'), isNotNull);
    expect(projection.hiddenNodeIds, contains('noise'));
    expect(projection.findByRawNodeId('identity'), isNotNull);
    expect(projection.findByRawNodeId('target')!.rawNode!.parentId, 'root');
  });

  test('reveals a hidden node without changing raw parent relationships', () {
    final snapshot = _snapshot();

    final projection = ElementExplorerPruningEngine.project(
      snapshot,
      revealedNodeIds: const <String>{'noise'},
    );

    expect(projection.findByRawNodeId('noise'), isNotNull);
    expect(projection.findByRawNodeId('noise')!.rawNode!.parentId, 'root');
    expect(projection.originalNodeCount, 4);
  });
}

ElementExplorerSnapshot _snapshot() {
  return ElementExplorerSnapshot(
    root: ElementExplorerNode(
      nodeId: 'root',
      parentId: null,
      widgetType: 'Column',
      elementType: 'ColumnElement',
      key: null,
      text: null,
      semanticsIdentifier: null,
      isTarget: false,
      childrenState: 'complete',
      children: <ElementExplorerNode>[
        ElementExplorerNode(
          nodeId: 'identity',
          parentId: 'root',
          widgetType: 'Container',
          elementType: 'StatelessElement',
          key: <String, dynamic>{'kind': 'ValueKey', 'finderCompatible': true},
          text: null,
          semanticsIdentifier: null,
          isTarget: false,
          childrenState: 'empty',
          children: const <ElementExplorerNode>[],
          metadataErrors: const <String>[],
        ),
        ElementExplorerNode(
          nodeId: 'noise',
          parentId: 'root',
          widgetType: 'Padding',
          elementType: 'PaddingElement',
          key: null,
          text: null,
          semanticsIdentifier: null,
          isTarget: false,
          childrenState: 'empty',
          children: const <ElementExplorerNode>[],
          metadataErrors: const <String>[],
        ),
        ElementExplorerNode(
          nodeId: 'target',
          parentId: 'root',
          widgetType: 'Text',
          elementType: 'StatelessElement',
          key: null,
          text: 'Target',
          semanticsIdentifier: null,
          isTarget: true,
          childrenState: 'notRequested',
          children: const <ElementExplorerNode>[],
          metadataErrors: const <String>[],
        ),
      ],
      metadataErrors: const <String>[],
    ),
  );
}
