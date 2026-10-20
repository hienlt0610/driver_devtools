import 'dart:async';
import 'dart:convert';

import 'package:driver_devtools/src/inspector_selection_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the selected Inspector value ID from the extension result', () {
    expect(
      InspectorSelectionBridge.parseSelectedValueId(
        jsonEncode(<String, dynamic>{'valueId': 'inspector-7'}),
      ),
      'inspector-7',
    );
    expect(InspectorSelectionBridge.parseSelectedValueId('null'), isNull);
    expect(
      () => InspectorSelectionBridge.parseSelectedValueId(
        jsonEncode(<String, dynamic>{'valueId': 7}),
      ),
      throwsFormatException,
    );
  });

  test('latest selection query wins over an older in-flight query', () async {
    final first = Completer<String?>();
    final second = Completer<String?>();
    final queries = <Future<String?> Function()>[
      () => first.future,
      () => second.future,
    ];
    final selections = <String?>[];
    final coordinator = InspectorSelectionCoordinator(
      query: () => queries.removeAt(0)(),
      onSelection: selections.add,
    );

    final firstRefresh = coordinator.refresh();
    final secondRefresh = coordinator.refresh();
    second.complete('inspector-2');
    await secondRefresh;
    first.complete('inspector-1');
    await firstRefresh;

    expect(selections, <String?>['inspector-2']);
  });

  test('invalidating the coordinator suppresses a late selection', () async {
    final pending = Completer<String?>();
    final selections = <String?>[];
    final coordinator = InspectorSelectionCoordinator(
      query: () => pending.future,
      onSelection: selections.add,
    );

    final refresh = coordinator.refresh();
    coordinator.invalidate();
    pending.complete('inspector-late');
    await refresh;

    expect(selections, isEmpty);
  });
}
