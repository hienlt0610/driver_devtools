import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The POC exercises the framework's protected Inspector identity surface.
// ignore_for_file: invalid_use_of_protected_member

void main() {
  testWidgets(
    'Inspector value IDs resolve the exact Element across object groups',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Column(children: [Text('same'), Text('same')])),
      );

      final first = tester.element(find.text('same').first);
      final service = WidgetInspectorService.instance;
      const groupA = 'driver_devtools_poc_a';
      const groupB = 'driver_devtools_poc_b';

      final idA = service.toId(first, groupA);
      final idB = service.toId(first, groupB);

      expect(idA, isNotNull);
      expect(idB, idA);
      expect(identical(service.toObject(idA, groupA), first), isTrue);
      expect(identical(service.toObject(idB, groupB), first), isTrue);
      expect(identical(service.toObject(idA, groupB), first), isTrue);

      service.selection.currentElement = first;
      final selected = jsonDecode(service.getSelectedWidget(null, groupA));
      expect(selected['valueId'], idA);

      service.disposeGroup(groupA);
      expect(identical(service.toObject(idB, groupB), first), isTrue);
      service.disposeGroup(groupB);
    },
  );
}
