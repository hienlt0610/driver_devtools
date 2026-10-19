import 'package:driver_devtools/src/element_explorer_model.dart';
import 'package:driver_devtools/src/element_explorer_projection.dart';
import 'package:driver_devtools/src/element_explorer_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps a deeply nested tree readable in both scroll axes', (
    tester,
  ) async {
    final snapshot = _deepSnapshot(32);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 600,
            child: ElementExplorerViewer(
              snapshot: snapshot,
              truncated: false,
              returnedNodes: 33,
              visitedNodes: 33,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('element_explorer.tree.vertical_scroll')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('element_explorer.tree.horizontal_scroll')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<SingleChildScrollView>(
            find.byKey(
              const ValueKey('element_explorer.tree.horizontal_scroll'),
            ),
          )
          .controller!
          .position
          .maxScrollExtent,
      greaterThan(0),
    );
    expect(
      tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('element_explorer.tree.vertical_scroll')),
          )
          .controller!
          .position
          .maxScrollExtent,
      greaterThan(0),
    );
    expect(
      find.byKey(const ValueKey('element_explorer.node.n32')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('element_explorer.node.n32')),
        matching: find.text('DeepTarget'),
      ),
      findsNWidgets(2),
    );

    final targetRect = tester.getRect(
      find.byKey(const ValueKey('element_explorer.node.n32')),
    );
    final treeRect = tester.getRect(
      find.byKey(const ValueKey('element_explorer.tree.vertical_scroll')),
    );
    expect(targetRect.top, greaterThanOrEqualTo(treeRect.top));
    expect(targetRect.bottom, lessThanOrEqualTo(treeRect.bottom));
  });

  testWidgets('focus target restores the target selection without a request', (
    tester,
  ) async {
    final snapshot = _deepSnapshot(4);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 600,
            child: ElementExplorerViewer(
              snapshot: snapshot,
              truncated: true,
              returnedNodes: 5,
              visitedNodes: 9,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('element_explorer.focus_target_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('element_explorer.node.n4')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.gps_fixed), findsOneWidget);
    expect(find.text('TARGET'), findsNothing);
    expect(find.textContaining('5 nodes'), findsOneWidget);
    expect(find.textContaining('Truncated'), findsOneWidget);
  });

  testWidgets('keeps target identity independent from node selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 720,
            height: 600,
            child: ElementExplorerViewer(
              snapshot: _finderMetadataSnapshot(),
              truncated: false,
              returnedNodes: 7,
              visitedNodes: 7,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.gps_fixed), findsOneWidget);
    expect(find.text('TARGET'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('element_explorer.node.root')));
    await tester.pump();

    expect(find.byIcon(Icons.gps_fixed), findsOneWidget);
    expect(find.text('StatefulElement'), findsNothing);
    expect(find.text('RenderObjectElement'), findsOneWidget);

    final horizontalController =
        tester
            .widget<SingleChildScrollView>(
              find.byKey(
                const ValueKey('element_explorer.tree.horizontal_scroll'),
              ),
            )
            .controller!;
    horizontalController.jumpTo(0);
    await tester.pump();

    final rootRow = find.byKey(const ValueKey('element_explorer.node.root'));
    await tester.tap(
      find.descendant(of: rootRow, matching: find.byIcon(Icons.expand_more)),
    );
    await tester.pump();
    expect(find.byIcon(Icons.gps_fixed), findsNothing);

    await tester.tap(
      find.descendant(of: rootRow, matching: find.byIcon(Icons.chevron_right)),
    );
    await tester.pump();
    expect(find.byIcon(Icons.gps_fixed), findsOneWidget);
  });

  testWidgets('removes normal not-inspected badges but keeps truncated state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 720,
            height: 600,
            child: ElementExplorerViewer(
              snapshot: _finderMetadataSnapshot(),
              truncated: false,
              returnedNodes: 7,
              visitedNodes: 7,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NOT INSPECTED'), findsNothing);
    expect(find.text('TRUNCATED'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('element_explorer.properties.scroll')),
      const Offset(0, -400),
    );
    await tester.pump();
    expect(find.textContaining('Not inspected'), findsOneWidget);
  });

  testWidgets('shows typed key previews and finder-focused properties', (
    tester,
  ) async {
    final longKey = _longKey;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 720,
            height: 600,
            child: ElementExplorerViewer(
              snapshot: _finderMetadataSnapshot(),
              truncated: false,
              returnedNodes: 7,
              visitedNodes: 7,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('key: login.email_input'), findsOneWidget);
    expect(find.text('key: 123'), findsOneWidget);
    expect(find.text('key: ObjectKey'), findsOneWidget);
    expect(find.text('key: GlobalKey<State>'), findsOneWidget);
    expect(find.text('key: $longKey'), findsOneWidget);
    expect(find.text('KEY'), findsNothing);
    expect(find.text('Widget Identity'), findsOneWidget);
    expect(find.text('Element Details'), findsOneWidget);
    expect(find.text('Finder compatible'), findsOneWidget);
    expect(find.text('ValueKey<String>'), findsOneWidget);
    expect(find.text('Yes'), findsNWidgets(2));

    await tester.tap(
      find.byKey(const ValueKey('element_explorer.node.object')),
    );
    await tester.pump();

    expect(find.text('ObjectKey'), findsNWidgets(2));
    expect(find.text('No'), findsNWidgets(2));

    await tester.tap(
      find.byKey(const ValueKey('element_explorer.node.missing')),
    );
    await tester.pump();

    expect(find.text('None'), findsNWidgets(3));
  });

  testWidgets('provides concise metadata through the shared node tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 720,
            height: 600,
            child: ElementExplorerViewer(
              snapshot: _finderMetadataSnapshot(),
              truncated: false,
              returnedNodes: 7,
              visitedNodes: 7,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byTooltip(
        'TextFormField\n'
        'Key: login.email_input\n'
        'Finder compatible: Yes\n'
        'Element: StatefulElement\n'
        'Children: Not inspected\n'
        'Text: (empty)\n'
        'Semantics: email',
      ),
      findsOneWidget,
    );
  });

  testWidgets('selecting a node updates its properties', (tester) async {
    final snapshot = _deepSnapshot(1);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 720,
            height: 600,
            child: ElementExplorerViewer(
              snapshot: snapshot,
              truncated: false,
              returnedNodes: 2,
              visitedNodes: 2,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('element_explorer.node.n0')));
    await tester.pump();

    expect(find.text('ContainerElement'), findsOneWidget);
    expect(find.text('Root text'), findsNWidgets(2));
  });

  testWidgets('reveals hidden Elements in Pruned mode without a request', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 720,
            height: 600,
            child: ElementExplorerViewer(
              snapshot: _finderMetadataSnapshot(),
              truncated: false,
              returnedNodes: 7,
              visitedNodes: 7,
              displayMode: ElementExplorerDisplayMode.pruned,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('element_explorer.node.object')),
      findsNothing,
    );
    final hiddenGroup = find.byKey(
      const ValueKey('element_explorer.node.group:root'),
    );
    expect(hiddenGroup, findsOneWidget);

    await tester.tap(hiddenGroup);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('element_explorer.node.object')),
      findsOneWidget,
    );
    expect(find.text('ObjectKey'), findsWidgets);
  });
}

ElementExplorerSnapshot _deepSnapshot(int depth) {
  var node = ElementExplorerNode(
    nodeId: 'n$depth',
    parentId: depth == 0 ? null : 'n${depth - 1}',
    widgetType: 'DeepTarget',
    elementType: 'StatelessElement',
    key: null,
    text: 'DeepTarget',
    semanticsIdentifier: null,
    isTarget: true,
    childrenState: 'notRequested',
    children: const [],
    metadataErrors: const [],
  );
  for (var index = depth - 1; index >= 0; index--) {
    node = ElementExplorerNode(
      nodeId: 'n$index',
      parentId: index == 0 ? null : 'n${index - 1}',
      widgetType: index == 0 ? 'Root' : 'Ancestor$index',
      elementType: index == 0 ? 'ContainerElement' : 'StatelessElement',
      key: null,
      text: index == 0 ? 'Root text' : null,
      semanticsIdentifier: null,
      isTarget: false,
      childrenState: 'complete',
      children: [node],
      metadataErrors: const [],
    );
  }
  return ElementExplorerSnapshot(root: node);
}

const _longKey =
    'a-key-that-is-long-enough-to-exercise-horizontal-scrolling-and-tooltip-access';

ElementExplorerSnapshot _finderMetadataSnapshot() {
  const target = ElementExplorerNode(
    nodeId: 'target',
    parentId: 'root',
    widgetType: 'TextFormField',
    elementType: 'StatefulElement',
    key: <String, dynamic>{
      'kind': 'ValueKey',
      'keyRuntimeType': 'ValueKey<String>',
      'valueType': 'String',
      'value': 'login.email_input',
      'serializable': true,
      'finderCompatible': true,
    },
    text: '',
    semanticsIdentifier: 'email',
    isTarget: true,
    childrenState: 'notRequested',
    children: <ElementExplorerNode>[],
    metadataErrors: <String>[],
  );
  const intKey = ElementExplorerNode(
    nodeId: 'int',
    parentId: 'root',
    widgetType: 'SubmitButton',
    elementType: 'StatelessElement',
    key: <String, dynamic>{
      'kind': 'ValueKey',
      'keyRuntimeType': 'ValueKey<int>',
      'valueType': 'int',
      'value': 123,
      'serializable': true,
      'finderCompatible': true,
    },
    text: null,
    semanticsIdentifier: null,
    isTarget: false,
    childrenState: 'truncated',
    children: <ElementExplorerNode>[],
    metadataErrors: <String>[],
  );
  const objectKey = ElementExplorerNode(
    nodeId: 'object',
    parentId: 'root',
    widgetType: 'ObjectKeyWidget',
    elementType: 'StatelessElement',
    key: <String, dynamic>{
      'kind': 'ObjectKey',
      'keyRuntimeType': 'ObjectKey',
      'valueType': 'User',
      'serializable': false,
      'finderCompatible': false,
    },
    text: null,
    semanticsIdentifier: null,
    isTarget: false,
    childrenState: 'empty',
    children: <ElementExplorerNode>[],
    metadataErrors: <String>[],
  );
  const globalKey = ElementExplorerNode(
    nodeId: 'global',
    parentId: 'root',
    widgetType: 'GlobalKeyWidget',
    elementType: 'StatefulElement',
    key: <String, dynamic>{
      'kind': 'GlobalKey',
      'keyRuntimeType': 'GlobalKey<State>',
      'serializable': false,
      'finderCompatible': false,
    },
    text: null,
    semanticsIdentifier: null,
    isTarget: false,
    childrenState: 'empty',
    children: <ElementExplorerNode>[],
    metadataErrors: <String>[],
  );
  const missingKey = ElementExplorerNode(
    nodeId: 'missing',
    parentId: 'root',
    widgetType: 'NoKeyWidget',
    elementType: 'StatelessElement',
    key: null,
    text: null,
    semanticsIdentifier: null,
    isTarget: false,
    childrenState: 'empty',
    children: <ElementExplorerNode>[],
    metadataErrors: <String>[],
  );
  const longKey = ElementExplorerNode(
    nodeId: 'long',
    parentId: 'root',
    widgetType: 'LongKeyWidget',
    elementType: 'StatelessElement',
    key: <String, dynamic>{
      'kind': 'ValueKey',
      'keyRuntimeType': 'ValueKey<String>',
      'valueType': 'String',
      'value': _longKey,
      'serializable': true,
      'finderCompatible': true,
    },
    text: null,
    semanticsIdentifier: null,
    isTarget: false,
    childrenState: 'empty',
    children: <ElementExplorerNode>[],
    metadataErrors: <String>[],
  );
  return ElementExplorerSnapshot(
    root: ElementExplorerNode(
      nodeId: 'root',
      parentId: null,
      widgetType: 'Column',
      elementType: 'RenderObjectElement',
      key: null,
      text: null,
      semanticsIdentifier: null,
      isTarget: false,
      childrenState: 'complete',
      children: [target, intKey, objectKey, globalKey, missingKey, longKey],
      metadataErrors: const [],
    ),
  );
}
