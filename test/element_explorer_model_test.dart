import 'package:driver_devtools/src/element_explorer_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a successful snapshot and preserves hierarchy', () {
    final result = ElementExplorerResponse.parse(<String, dynamic>{
      'schemaVersion': 1,
      'matchCount': 1,
      'returnedNodes': 2,
      'visitedNodes': 4,
      'truncated': false,
      'root': <String, dynamic>{
        'nodeId': 'n0',
        'parentId': null,
        'widgetType': 'Column',
        'elementType': 'ColumnElement',
        'key': <String, dynamic>{
          'kind': 'ValueKey',
          'valueType': 'String',
          'value': 'contract.details',
          'finderCompatible': true,
        },
        'text': null,
        'semanticsIdentifier': null,
        'isTarget': false,
        'childrenState': 'complete',
        'children': <Map<String, dynamic>>[
          <String, dynamic>{
            'nodeId': 'n1',
            'parentId': 'n0',
            'widgetType': 'Text',
            'elementType': 'StatelessElement',
            'key': null,
            'text': '10.500.000 VNĐ',
            'semanticsIdentifier': 'amount',
            'isTarget': true,
            'childrenState': 'notRequested',
            'children': <Map<String, dynamic>>[],
          },
        ],
      },
    });

    expect(result.error, isNull);
    expect(result.snapshot, isNotNull);
    expect(result.snapshot!.root.children.single.parentId, 'n0');
    expect(result.snapshot!.root.children.single.isTarget, isTrue);
    expect(result.snapshot!.root.key!['kind'], 'ValueKey');
    expect(
      () => result.snapshot!.root.key!['kind'] = 'ObjectKey',
      throwsUnsupportedError,
    );
  });

  test('parses a runtime domain error without requiring a root', () {
    final result = ElementExplorerResponse.parse(<String, dynamic>{
      'schemaVersion': 1,
      'matchCount': 2,
      'returnedNodes': 0,
      'visitedNodes': 2,
      'truncated': false,
      'error': <String, dynamic>{
        'code': 'AMBIGUOUS_TARGET',
        'message': 'The Finder matched 2 Elements',
      },
    });

    expect(result.snapshot, isNull);
    expect(result.error!.code, 'AMBIGUOUS_TARGET');
    expect(result.error!.matchCount, 2);
  });

  test('rejects a malformed hierarchy', () {
    expect(
      () => ElementExplorerResponse.parse(<String, dynamic>{
        'schemaVersion': 1,
        'matchCount': 1,
        'returnedNodes': 1,
        'visitedNodes': 1,
        'truncated': false,
        'root': <String, dynamic>{
          'nodeId': 'n0',
          'parentId': 'wrong-parent',
          'widgetType': 'Text',
          'elementType': 'StatelessElement',
          'key': null,
          'text': null,
          'semanticsIdentifier': null,
          'isTarget': true,
          'childrenState': 'empty',
          'children': <Map<String, dynamic>>[],
        },
      }),
      throwsA(isA<ElementExplorerResponseException>()),
    );
  });

  test('parses optional V2 collection metadata', () {
    final result = ElementExplorerResponse.parse(<String, dynamic>{
      'schemaVersion': 1,
      'matchCount': 1,
      'returnedNodes': 1,
      'visitedNodes': 2,
      'truncated': false,
      'collection': <String, dynamic>{
        'mode': 'toRoot',
        'ancestorLevelsCollected': 1,
        'rootReached': true,
        'contextNodesCollected': 0,
        'stopReasons': <String>[],
        'limits': <String, dynamic>{
          'maxAncestorDepth': 256,
          'maxContextNodes': 200,
          'maxVisitedNodes': 1000,
          'maxReturnedNodes': 500,
        },
      },
      'root': <String, dynamic>{
        'nodeId': 'n0',
        'parentId': null,
        'widgetType': 'Text',
        'elementType': 'StatelessElement',
        'key': null,
        'text': 'target',
        'semanticsIdentifier': null,
        'isTarget': true,
        'childrenState': 'notRequested',
        'children': <Map<String, dynamic>>[],
      },
    });

    expect(result.collection!.mode, 'toRoot');
    expect(result.collection!.rootReached, isTrue);
    expect(result.collection!.limits.maxReturnedNodes, 500);
  });
}
