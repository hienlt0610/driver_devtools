import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driver_devtools/src/runtime/element_explorer_command.dart';

void main() {
  final GlobalKey globalKey = GlobalKey(debugLabel: 'global');
  late FlutterDriverExtension driverExtension;

  setUp(() {
    driverExtension = FlutterDriverExtension(
      null,
      true,
      false,
      commands: <CommandExtension>[ElementExplorerCommandExtension()],
    );
  });

  Future<Map<String, dynamic>> inspect(Map<String, String> params) async {
    final raw = await driverExtension.call(<String, String>{
      'command': elementExplorerCommandKind,
      ...params,
    });
    expect(raw['isError'], isFalse);
    return Map<String, dynamic>.from(raw['response'] as Map);
  }

  Future<void> pumpFixture(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            key: const ValueKey<String>('contract.details'),
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Text('Số tiền thanh toán'),
                  Expanded(
                    child: Semantics(
                      identifier: 'dynamic.amount',
                      child: const Text('10.500.000 VNĐ'),
                    ),
                  ),
                ],
              ),
              Container(
                key: const ValueKey<int>(7),
                child: const Text('value-key-int'),
              ),
              Container(
                key: const ObjectKey('object-key'),
                child: const Text('object-key'),
              ),
              Container(key: globalKey, child: const Text('global-key')),
              Offstage(offstage: true, child: const Text('offstage target')),
              const Text('duplicate'),
              const Text('duplicate'),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> findNode(
    Map<String, dynamic> node,
    bool Function(Map<String, dynamic>) predicate,
  ) {
    if (predicate(node)) {
      return node;
    }
    for (final child in (node['children'] as List).cast<Map>()) {
      final match = findNode(Map<String, dynamic>.from(child), predicate);
      if (match.isNotEmpty) {
        return match;
      }
    }
    return <String, dynamic>{};
  }

  testWidgets('returns the real hierarchy and target metadata', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    await pumpFixture(tester);

    final response = await inspect(<String, String>{
      'finderType': 'ByText',
      'text': '10.500.000 VNĐ',
      'ancestorDepth': '4',
      'descendantDepth': '1',
      'includeSiblings': 'true',
      'siblingDepth': '0',
      'maxNodes': '200',
    });

    expect(response['schemaVersion'], 1);
    expect(response['matchCount'], 1);
    expect(response['truncated'], isFalse);
    final root = Map<String, dynamic>.from(response['root'] as Map);
    final target = findNode(root, (node) => node['isTarget'] == true);

    expect(target['widgetType'], 'Text');
    expect(target['text'], '10.500.000 VNĐ');
    expect(target['semanticsIdentifier'], 'dynamic.amount');
    expect(target['parentId'], isNotNull);
    expect(root['widgetType'], isNot('Text'));

    final column = findNode(root, (node) {
      final key = node['key'];
      return key is Map &&
          key['kind'] == 'ValueKey' &&
          key['valueType'] == 'String' &&
          key['value'] == 'contract.details';
    });
    expect(column, isNotEmpty, reason: '$response');
    expect(
      findNode(root, (node) {
        final key = node['key'];
        return key is Map && key['kind'] == 'GlobalKey';
      }),
      isNotEmpty,
    );
    semanticsHandle.dispose();
  });

  testWidgets('reports not found and ambiguous targets', (tester) async {
    await pumpFixture(tester);

    final notFound = await inspect(<String, String>{
      'finderType': 'ByText',
      'text': 'missing',
    });
    expect(notFound['error']['code'], 'TARGET_NOT_FOUND');
    expect(notFound['matchCount'], 0);

    final ambiguous = await inspect(<String, String>{
      'finderType': 'ByText',
      'text': 'duplicate',
    });
    expect(ambiguous['error']['code'], 'AMBIGUOUS_TARGET');
    expect(ambiguous['matchCount'], 2);
  });

  testWidgets('applies depth and sibling options without losing the target', (
    tester,
  ) async {
    await pumpFixture(tester);

    final response = await inspect(<String, String>{
      'finderType': 'ByText',
      'text': '10.500.000 VNĐ',
      'ancestorDepth': '0',
      'descendantDepth': '0',
      'includeSiblings': 'true',
      'siblingDepth': '1',
      'maxNodes': '20',
    });

    final root = Map<String, dynamic>.from(response['root'] as Map);
    expect(root['isTarget'], isTrue);
    expect(root['children'], isEmpty);
    expect(root['childrenState'], 'notRequested');
  });

  testWidgets('preserves typed key metadata and active offstage elements', (
    tester,
  ) async {
    await pumpFixture(tester);

    final response = await inspect(<String, String>{
      'finderType': 'ByText',
      'text': '10.500.000 VNĐ',
      'ancestorDepth': '4',
      'includeSiblings': 'true',
      'siblingDepth': '1',
      'maxNodes': '200',
    });
    final root = Map<String, dynamic>.from(response['root'] as Map);
    final target = findNode(root, (node) => node['isTarget'] == true);
    expect(target['text'], '10.500.000 VNĐ');

    final intKey = findNode(root, (node) {
      final key = node['key'];
      return key is Map &&
          key['kind'] == 'ValueKey' &&
          key['valueType'] == 'int' &&
          key['value'] == 7;
    });
    final objectKey = findNode(root, (node) {
      final key = node['key'];
      return key is Map && key['kind'] == 'ObjectKey';
    });
    expect(intKey, isNotEmpty, reason: '$response');
    expect(objectKey['key']['serializable'], isFalse, reason: '$response');
    expect(
      findNode(root, (node) => node['text'] == 'offstage target'),
      isNotEmpty,
    );
  });

  testWidgets('supports composed Flutter Driver finders', (tester) async {
    await pumpFixture(tester);

    final response = await inspect(<String, String>{
      'finderType': 'Descendant',
      'of': '{"finderType":"ByType","type":"Row"}',
      'matching': '{"finderType":"ByText","text":"10.500.000 VNĐ"}',
      'matchRoot': 'false',
      'firstMatchOnly': 'false',
    });

    expect(response['matchCount'], 1);
    expect(
      findNode(
        Map<String, dynamic>.from(response['root'] as Map),
        (node) => node['isTarget'] == true,
      )['text'],
      '10.500.000 VNĐ',
    );
  });

  testWidgets('never truncates the required ancestor path', (tester) async {
    await pumpFixture(tester);

    final tooSmall = await inspect(<String, String>{
      'finderType': 'ByText',
      'text': '10.500.000 VNĐ',
      'ancestorDepth': '3',
      'maxNodes': '3',
    });
    expect(tooSmall['error']['code'], 'NODE_BUDGET_TOO_SMALL');

    final truncated = await inspect(<String, String>{
      'finderType': 'ByText',
      'text': '10.500.000 VNĐ',
      'ancestorDepth': '0',
      'descendantDepth': '10',
      'maxNodes': '1',
    });
    expect(truncated['returnedNodes'], 1);
    expect(truncated['truncated'], isTrue);
    expect(
      Map<String, dynamic>.from(truncated['root'] as Map)['isTarget'],
      isTrue,
    );
  });

  testWidgets('returns structured argument errors', (tester) async {
    await pumpFixture(tester);

    final response = await inspect(<String, String>{
      'finderType': 'ByText',
      'text': '10.500.000 VNĐ',
      'ancestorDepth': '-1',
    });
    expect(response['error']['code'], 'INVALID_ARGUMENT');
  });

  testWidgets('reports V2 collection status and separate context budget', (
    tester,
  ) async {
    await pumpFixture(tester);

    final response = await inspect(<String, String>{
      'finderType': 'ByText',
      'text': '10.500.000 VNĐ',
      'mode': 'toRoot',
      'ancestorDepth': '32',
      'maxAncestorDepth': '256',
      'descendantDepth': '0',
      'includeSiblings': 'false',
      'siblingDepth': '0',
      'maxContextNodes': '0',
      'maxVisitedNodes': '1000',
      'maxReturnedNodes': '500',
      'maxNodes': '500',
    });

    final collection = Map<String, dynamic>.from(response['collection'] as Map);
    expect(collection['mode'], 'toRoot');
    expect(collection['rootReached'], isTrue);
    expect(collection['contextNodesCollected'], 0);
    expect(collection['stopReasons'], isEmpty);
    expect(response['truncated'], isFalse);
  });

  testWidgets('Explore to Root traverses past the legacy depth cap', (
    tester,
  ) async {
    Widget content = const Text('deep target');
    for (var index = 0; index < 40; index++) {
      content = _DeepWrapper(child: content);
    }
    await tester.pumpWidget(MaterialApp(home: content));

    final response = await inspect(<String, String>{
      'finderType': 'ByText',
      'text': 'deep target',
      'mode': 'toRoot',
      'maxAncestorDepth': '256',
      'descendantDepth': '0',
      'includeSiblings': 'false',
      'maxContextNodes': '0',
      'maxVisitedNodes': '1000',
      'maxReturnedNodes': '500',
    });

    final collection = Map<String, dynamic>.from(response['collection'] as Map);
    expect(collection['ancestorLevelsCollected'], greaterThan(32));
    expect(collection['rootReached'], isTrue);
    expect(response['truncated'], isFalse);
  });

  testWidgets(
    'V2 resource limits preserve the target and report stop reasons',
    (tester) async {
      await pumpFixture(tester);

      final response = await inspect(<String, String>{
        'finderType': 'ByText',
        'text': '10.500.000 VNĐ',
        'mode': 'toRoot',
        'maxAncestorDepth': '256',
        'descendantDepth': '1',
        'includeSiblings': 'false',
        'maxContextNodes': '200',
        'maxVisitedNodes': '2',
        'maxReturnedNodes': '1',
      });

      final collection = Map<String, dynamic>.from(
        response['collection'] as Map,
      );
      expect(collection['rootReached'], isFalse);
      expect(
        collection['stopReasons'],
        containsAll(<String>['NODE_VISIT_LIMIT', 'RESPONSE_NODE_LIMIT']),
      );
      expect(response['truncated'], isTrue);
      expect(
        Map<String, dynamic>.from(response['root'] as Map)['isTarget'],
        isTrue,
      );
    },
  );
}

class _DeepWrapper extends StatelessWidget {
  const _DeepWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
