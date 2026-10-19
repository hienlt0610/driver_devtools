import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:driver_devtools/src/driver_automation_core.dart';
import 'package:driver_devtools/src/driver_automation_page.dart';
import 'package:driver_devtools/main.dart' show DriverAutomationApp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows DSL completions in a popup and inserts the selected item',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverAutomationPage(transport: _CaptureDriverTransport()),
          ),
        ),
      );
      await tester.pump();

      final input = find.byKey(
        const ValueKey('driver_automation.finder_input'),
      );
      await tester.enterText(input, 'ty');
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('driver_automation.finder_suggestion_type')),
        findsOneWidget,
      );
      expect(find.byType(ActionChip), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('driver_automation.finder_suggestion_type')),
      );
      await tester.pump();

      expect(tester.widget<TextField>(input).controller!.text, 'type("")');
    },
  );

  testWidgets('renders compact two-line completion rows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverAutomationPage(transport: _CaptureDriverTransport()),
        ),
      ),
    );
    await tester.pump();

    final input = find.byKey(const ValueKey('driver_automation.finder_input'));
    await tester.enterText(input, 'ty');
    await tester.pump();
    await tester.pump();

    final item = find.byKey(
      const ValueKey('driver_automation.finder_suggestion_type'),
    );
    final popup = tester.widget<Material>(
      find.byKey(const ValueKey('driver_automation.finder_completion_popup')),
    );
    expect(popup.color, const Color(0xEB171A1F));
    expect(popup.elevation, 4);
    expect(popup.shape, isA<RoundedRectangleBorder>());
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey('driver_automation.finder_completion_popup'),
            ),
          )
          .width,
      lessThanOrEqualTo(360),
    );
    expect(tester.getSize(item).height, lessThanOrEqualTo(52));
    final title = tester.widget<RichText>(
      find.descendant(of: item, matching: find.byType(RichText)).first,
    );
    expect(title.text.toPlainText(), contains('type(value: String)'));
    expect(find.text('Match widgets by runtime type.'), findsOneWidget);
  });

  testWidgets('supports keyboard navigation and acceptance', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverAutomationPage(transport: _CaptureDriverTransport()),
        ),
      ),
    );
    await tester.pump();

    final input = find.byKey(const ValueKey('driver_automation.finder_input'));
    await tester.enterText(input, '');
    await tester.pump();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(tester.widget<TextField>(input).controller!.text, 'key("")');
  });

  testWidgets('supports dismissing and explicitly reopening completions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverAutomationPage(transport: _CaptureDriverTransport()),
        ),
      ),
    );
    await tester.pump();

    final input = find.byKey(const ValueKey('driver_automation.finder_input'));
    await tester.enterText(input, 'ty');
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('driver_automation.finder_suggestion_type')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('driver_automation.finder_suggestion_type')),
      findsNothing,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('driver_automation.finder_suggestion_type')),
      findsOneWidget,
    );
  });

  testWidgets('starts the finder console in DSL mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DriverAutomationPage(transport: _CaptureDriverTransport()),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('driver_automation.finder_mode_dsl')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('driver_automation.finder_dsl_input')),
      findsOneWidget,
    );
    final editor = tester.widget<TextField>(
      find.byKey(const ValueKey('driver_automation.finder_input')),
    );
    expect(editor.controller!.text, 'key("login_button")');
    expect(
      find.byKey(const ValueKey('driver_automation.finder_json_input')),
      findsNothing,
    );
  });

  testWidgets(
    'regenerates the JSON controller after valid DSL clears invalid JSON',
    (tester) async {
      final session =
          DriverAutomationSession()
            ..finderText = '{"finderType":"ByType","type":"Column"}'
            ..finderDslText = 'type("Column")';
      await tester.pumpWidget(
        MaterialApp(
          home: DriverAutomationPage(
            transport: _CaptureDriverTransport(),
            session: session,
          ),
        ),
      );
      await tester.pump();

      final input = find.byKey(
        const ValueKey('driver_automation.finder_input'),
      );
      await tester.tap(
        find.byKey(const ValueKey('driver_automation.finder_mode_json')),
      );
      await tester.enterText(input, '');
      await tester.tap(
        find.byKey(const ValueKey('driver_automation.finder_mode_dsl')),
      );
      await tester.enterText(input, 'type("Row")');
      await tester.tap(
        find.byKey(const ValueKey('driver_automation.finder_mode_json')),
      );
      await tester.pump();

      expect(
        tester.widget<TextField>(input).controller!.text,
        contains('"type": "Row"'),
      );
      expect(session.finderCanonical, {'finderType': 'ByType', 'type': 'Row'});
      expect(session.finderError, isNull);
    },
  );

  testWidgets(
    'regenerates the DSL controller after valid JSON clears invalid DSL',
    (tester) async {
      final session =
          DriverAutomationSession()
            ..finderText = '{"finderType":"ByType","type":"Column"}'
            ..finderDslText = 'type("Column")';
      await tester.pumpWidget(
        MaterialApp(
          home: DriverAutomationPage(
            transport: _CaptureDriverTransport(),
            session: session,
          ),
        ),
      );
      await tester.pump();

      final input = find.byKey(
        const ValueKey('driver_automation.finder_input'),
      );
      await tester.enterText(input, 'type("Column"');
      await tester.tap(
        find.byKey(const ValueKey('driver_automation.finder_mode_json')),
      );
      await tester.enterText(input, '{"finderType":"ByType","type":"Text"}');
      await tester.tap(
        find.byKey(const ValueKey('driver_automation.finder_mode_dsl')),
      );
      await tester.pump();

      expect(tester.widget<TextField>(input).controller!.text, 'type("Text")');
      expect(session.finderCanonical, {'finderType': 'ByType', 'type': 'Text'});
      expect(session.finderError, isNull);
    },
  );

  testWidgets('executes a valid DSL finder through the existing transport', (
    tester,
  ) async {
    final transport = _CaptureDriverTransport();
    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationPage(transport: transport)),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('driver_automation.finder_input')),
      'type("Column").first()',
    );
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.finder_verify_button')),
    );
    await tester.pump();

    expect(transport.executionCalls.single, {
      'command': 'waitFor',
      'finderType': 'ByMatchPosition',
      'position': 'first',
      'of': '{"finderType":"ByType","type":"Column"}',
      'timeout': '5000',
    });
  });

  testWidgets('does not execute an invalid active DSL draft', (tester) async {
    final transport = _CaptureDriverTransport();
    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationPage(transport: transport)),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('driver_automation.finder_input')),
      'type("Column"',
    );
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.finder_verify_button')),
    );
    await tester.pump();

    expect(transport.executionCalls, isEmpty);
    expect(find.textContaining('Expected ")"'), findsOneWidget);
  });

  testWidgets('shows each driver operation in its own tab', (tester) async {
    final transport = _PendingDriverTransport();

    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationPage(transport: transport)),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('driver_automation.finder_tab')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('driver_automation.command_input')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('driver_automation.request_data_input')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('driver_automation.command_tab')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('driver_automation.finder_input')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('driver_automation.command_input')),
      findsOneWidget,
    );
  });

  testWidgets('renders and executes the Element Explorer tab', (tester) async {
    final transport = _ReinspectElementExplorerTransport(
      initialText: '10.500.000 VNĐ',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DriverAutomationPage(transport: transport)),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('driver_automation.element_explorer_tab')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('driver_automation.element_explorer_tab')),
    );
    await tester.pump();

    final explorerInput = find.byKey(
      const ValueKey('driver_automation.element_explorer_finder_input'),
    );
    expect(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_load_finder_button'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_format_button'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_reset_button'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_load_finder_button'),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(explorerInput).controller!.text,
      contains('finderType'),
    );
    await tester.enterText(
      explorerInput,
      '{"finderType":"ByText","text":"10.500.000 VNĐ"}',
    );
    await tester.tap(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_format_button'),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(explorerInput).controller!.text,
      contains('\n'),
    );
    await tester.tap(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_reset_button'),
      ),
    );
    await tester.pump();
    expect(find.text('Reset editor?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.reset_confirm_button')),
    );
    await tester.pump();
    await tester.enterText(
      explorerInput,
      '{"finderType":"ByText","text":"10.500.000 VNĐ"}',
    );
    final inspectButton = find.byKey(
      const ValueKey('driver_automation.element_explorer_inspect_button'),
    );
    await tester.ensureVisible(inspectButton);
    await tester.tap(inspectButton);
    await tester.pump();

    expect(transport.executionCalls.single['command'], 'element_explorer');
    expect(transport.executionCalls.single['ancestorDepth'], '32');
    expect(transport.executionCalls.single['descendantDepth'], '1');
    expect(transport.executionCalls.single['includeSiblings'], 'true');
    expect(transport.executionCalls.single['siblingDepth'], '0');
    expect(transport.executionCalls.single['maxNodes'], '500');
    expect(
      find.byKey(const ValueKey('element_explorer.node.n1')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('element_explorer.node.n1')),
        matching: find.text('10.500.000 VNĐ'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.gps_fixed), findsOneWidget);
    expect(find.text('TARGET'), findsNothing);
    expect(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_finder_summary'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_finder_input'),
      ),
      findsNothing,
    );
    expect(find.text('Reinspect'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_pending_changes'),
      ),
      findsNothing,
    );

    await tester.tap(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_options_button'),
      ),
    );
    await tester.pump();
    final ancestorDepth = find.byKey(
      const ValueKey('driver_automation.element_explorer_ancestor_depth'),
    );
    tester.widget<DevToolsTextField>(ancestorDepth).controller.text = '5';
    await tester.pump();
    expect(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_pending_changes'),
      ),
      findsOneWidget,
    );
    expect(find.text('Apply & Reinspect'), findsOneWidget);

    await tester.ensureVisible(inspectButton);
    await tester.tap(inspectButton);
    await tester.pump();
    expect(transport.executionCalls, hasLength(2));
    expect(transport.executionCalls[1]['ancestorDepth'], '5');
    expect(transport.executionCalls[1]['text'], '10.500.000 VNĐ');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('element_explorer.node.n1')),
        matching: find.text('Updated tree'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('element_explorer.node.n1')),
        matching: find.text('10.500.000 VNĐ'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_pending_changes'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_finder_input'),
      ),
      findsNothing,
    );

    await tester.tap(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_edit_finder_button'),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_finder_input'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders runtime Element Explorer errors without a tree', (
    tester,
  ) async {
    final transport = _ElementExplorerErrorTransport();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DriverAutomationPage(transport: transport)),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.element_explorer_tab')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_inspect_button'),
      ),
    );
    await tester.pump();

    expect(find.textContaining('TARGET_NOT_FOUND'), findsOneWidget);
    expect(find.byKey(const ValueKey('element_explorer.tree')), findsNothing);
  });

  testWidgets(
    'switches display mode locally and applies root traversal on inspect',
    (tester) async {
      final transport = _ReinspectElementExplorerTransport();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DriverAutomationPage(transport: transport)),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('driver_automation.element_explorer_tab')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(
          const ValueKey('driver_automation.element_explorer_inspect_button'),
        ),
      );
      await tester.pump();
      expect(transport.executionCalls, hasLength(1));

      await tester.tap(
        find.byKey(
          const ValueKey('driver_automation.element_explorer_options_button'),
        ),
      );
      await tester.pump();

      final displayMode = find.byKey(
        const ValueKey('driver_automation.element_explorer_display_mode'),
      );
      await tester.ensureVisible(displayMode);
      await tester.tap(displayMode);
      await tester.pump();
      await tester.tap(find.text('Raw').last);
      await tester.pump();
      expect(transport.executionCalls, hasLength(1));

      final traversalMode = find.byKey(
        const ValueKey('driver_automation.element_explorer_traversal_mode'),
      );
      await tester.ensureVisible(traversalMode);
      await tester.tap(traversalMode);
      await tester.pump();
      await tester.tap(find.text('Explore to Root').last);
      await tester.pump();
      expect(transport.executionCalls, hasLength(1));
      expect(
        find.byKey(
          const ValueKey('driver_automation.element_explorer_pending_changes'),
        ),
        findsOneWidget,
      );

      final inspect = find.byKey(
        const ValueKey('driver_automation.element_explorer_inspect_button'),
      );
      await tester.ensureVisible(inspect);
      await tester.tap(inspect);
      await tester.pump();
      expect(transport.executionCalls, hasLength(2));
      expect(transport.executionCalls[1]['mode'], 'toRoot');
      expect(transport.executionCalls[1]['ancestorDepth'], '32');
    },
  );

  testWidgets('preserves the previous snapshot when reinspection fails', (
    tester,
  ) async {
    final transport = _ReinspectElementExplorerTransport(failSecond: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DriverAutomationPage(transport: transport)),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.element_explorer_tab')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_inspect_button'),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_options_button'),
      ),
    );
    await tester.pump();
    final descendantDepth = find.byKey(
      const ValueKey('driver_automation.element_explorer_descendant_depth'),
    );
    (descendantDepth.evaluate().single.widget as DevToolsTextField)
        .controller
        .text = '4';
    await tester.pump();
    final inspectButton = find.byKey(
      const ValueKey('driver_automation.element_explorer_inspect_button'),
    );
    await tester.ensureVisible(inspectButton);
    await tester.tap(inspectButton);
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('element_explorer.node.n1')),
        matching: find.text('Initial tree'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('TARGET_NOT_FOUND'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_pending_changes'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('prevents duplicate Element Explorer requests', (tester) async {
    final transport = _PendingDriverTransport();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DriverAutomationPage(transport: transport)),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.element_explorer_tab')),
    );
    await tester.pump();

    final inspect = tester.widget<DevToolsButton>(
      find.byKey(
        const ValueKey('driver_automation.element_explorer_inspect_button'),
      ),
    );
    inspect.onPressed!();
    inspect.onPressed!();
    await tester.pump();

    expect(transport.pendingCount, 1);
    transport.completeNext(
      const DriverTransportResponse(isError: true, response: null),
    );
    await tester.pump();
  });

  testWidgets('disables driver actions and offers a connection retry', (
    tester,
  ) async {
    final transport = _ConnectionStateTransport(connected: false);

    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationPage(transport: transport)),
    );
    await tester.pump();

    final verifyButton = find.byKey(
      const ValueKey('driver_automation.finder_verify_button'),
    );
    expect(tester.widget<DevToolsButton>(verifyButton).onPressed, isNull);
    expect(
      find.byKey(const ValueKey('driver_automation.connection_retry_button')),
      findsOneWidget,
    );

    transport.connected = true;
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.connection_retry_button')),
    );
    await tester.pump();

    expect(tester.widget<DevToolsButton>(verifyButton).onPressed, isNotNull);
  });

  testWidgets('generates and copies Java finder without a driver connection', (
    tester,
  ) async {
    final transport = _ConnectionStateTransport(connected: false);
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText =
                (call.arguments as Map<Object?, Object?>)['text'] as String;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DriverAutomationPage(transport: transport)),
      ),
    );
    await tester.pump();

    final generateButton = find.byKey(
      const ValueKey('driver_automation.finder_generate_java_button'),
    );
    expect(tester.widget<DevToolsButton>(generateButton).onPressed, isNotNull);
    expect(
      tester
          .widget<DevToolsButton>(
            find.byKey(
              const ValueKey('driver_automation.finder_verify_button'),
            ),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey('driver_automation.finder_input')),
      '{"finderType":"ByText","text":"Login"}',
    );
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    expect(find.text('Java Finder'), findsOneWidget);
    expect(find.text('Flutter.byText("Login")'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.java_finder_copy_button')),
    );
    await tester.pump();
    expect(copiedText, 'Flutter.byText("Login")');
  });

  testWidgets('resets processing after success and error', (tester) async {
    final transport = _PendingDriverTransport();

    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationPage(transport: transport)),
    );
    await tester.pump();

    final verifyButton = find.byKey(
      const ValueKey('driver_automation.finder_verify_button'),
    );
    await tester.tap(verifyButton);
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.widget<DevToolsButton>(verifyButton).onPressed, isNotNull);

    transport.completeNext(
      const DriverTransportResponse(
        response: <String, dynamic>{},
        raw: <String, dynamic>{
          'isError': false,
          'response': <String, dynamic>{},
        },
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.widget<DevToolsButton>(verifyButton).onPressed, isNotNull);
    expect(find.text('RESULT'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('driver_automation.result_copy_button')),
      findsOneWidget,
    );
    expect(find.text('Raw details'), findsOneWidget);

    await tester.tap(verifyButton);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    transport.completeNext(
      const DriverTransportResponse(
        isError: true,
        response: 'Timeout',
        raw: <String, dynamic>{'isError': true, 'response': 'Timeout'},
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.widget<DevToolsButton>(verifyButton).onPressed, isNotNull);
    expect(find.text('Request failed'), findsOneWidget);

    final historyTile = tester.widget<ExpansionTile>(
      find.byType(ExpansionTile).last,
    );
    expect(find.textContaining('Failed ·'), findsOneWidget);
    expect(find.textContaining('Timeout'), findsWidgets);
    expect(historyTile.subtitle, isNull);
  });

  testWidgets('keeps Finder controls grouped around the editor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverAutomationPage(transport: _CaptureDriverTransport()),
        ),
      ),
    );
    await tester.pump();

    final mode = find.byKey(
      const ValueKey('driver_automation.finder_mode_dsl'),
    );
    final input = find.byKey(const ValueKey('driver_automation.finder_input'));
    final schema = find.byKey(
      const ValueKey('driver_automation.finder_schema_button'),
    );
    final format = find.byKey(
      const ValueKey('driver_automation.finder_format_button'),
    );
    final generate = find.byKey(
      const ValueKey('driver_automation.finder_generate_java_button'),
    );
    final reset = find.byKey(
      const ValueKey('driver_automation.finder_reset_button'),
    );
    final verify = find.byKey(
      const ValueKey('driver_automation.finder_verify_button'),
    );

    expect(
      tester.getTopLeft(input).dy -
          (tester.getTopLeft(mode).dy + tester.getSize(mode).height),
      lessThan(28),
    );
    expect(tester.getTopLeft(schema).dy, lessThan(tester.getTopLeft(input).dy));
    expect(
      tester.getTopLeft(format).dx,
      lessThan(tester.getTopLeft(generate).dx),
    );
    expect(
      tester.getTopLeft(generate).dx,
      lessThan(tester.getTopLeft(reset).dx),
    );
    expect(tester.getTopLeft(reset).dx, lessThan(tester.getTopLeft(verify).dx));
  });

  testWidgets('keeps Verify accessible on a narrow viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverAutomationPage(transport: _CaptureDriverTransport()),
        ),
      ),
    );
    await tester.pump();

    final reset = find.byKey(
      const ValueKey('driver_automation.finder_reset_button'),
    );
    final verify = find.byKey(
      const ValueKey('driver_automation.finder_verify_button'),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(verify).dy,
      greaterThan(tester.getTopLeft(reset).dy + tester.getSize(reset).height),
    );
  });

  testWidgets('stops a pending operation and ignores its late response', (
    tester,
  ) async {
    final transport = _PendingDriverTransport();

    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationPage(transport: transport)),
    );
    await tester.pump();

    final verifyButton = find.byKey(
      const ValueKey('driver_automation.finder_verify_button'),
    );
    await tester.tap(verifyButton);
    await tester.pump();

    expect(find.text('Stop'), findsOneWidget);
    expect(tester.widget<DevToolsButton>(verifyButton).onPressed, isNotNull);

    await tester.tap(verifyButton);
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('RESULT'), findsNothing);
    expect(find.text('No operations in this session.'), findsOneWidget);

    transport.completeNext(
      const DriverTransportResponse(
        response: <String, dynamic>{},
        raw: <String, dynamic>{
          'isError': false,
          'response': <String, dynamic>{},
        },
      ),
    );
    await tester.pump();

    expect(find.text('RESULT'), findsNothing);
    expect(tester.widget<DevToolsButton>(verifyButton).onPressed, isNotNull);
  });

  testWidgets('clears the session history', (tester) async {
    final transport = _PendingDriverTransport();

    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationPage(transport: transport)),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('driver_automation.finder_verify_button')),
    );
    await tester.pump();
    transport.completeNext(
      const DriverTransportResponse(
        response: <String, dynamic>{},
        raw: <String, dynamic>{
          'isError': false,
          'response': <String, dynamic>{},
        },
      ),
    );
    await tester.pump();

    expect(find.textContaining('Finder Verify'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('driver_automation.history_clear_button')),
    );
    await tester.pump();

    expect(find.textContaining('Finder Verify'), findsNothing);
    expect(find.text('No operations in this session.'), findsOneWidget);
  });

  testWidgets('formats and resets the JSON editors in every tab', (
    tester,
  ) async {
    final transport = _PendingDriverTransport();

    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationPage(transport: transport)),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('driver_automation.finder_format_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('driver_automation.finder_reset_button')),
      findsOneWidget,
    );
    final finderInput = find.byKey(
      const ValueKey('driver_automation.finder_input'),
    );
    final finderEditor = tester.widget<TextField>(finderInput);
    await tester.enterText(finderInput, '{"finderType":"ByText"}');
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.finder_format_button')),
    );
    await tester.pump();
    expect(finderEditor.controller!.text, '{\n  "finderType": "ByText"\n}');
    await tester.enterText(finderInput, '{"changed":true}');
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.finder_reset_button')),
    );
    await tester.pump();
    expect(find.text('Reset editor?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.reset_confirm_button')),
    );
    await tester.pump();
    expect(finderEditor.controller!.text, JsonPayloads.defaultFinder);

    await tester.tap(
      find.byKey(const ValueKey('driver_automation.command_tab')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('driver_automation.command_format_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('driver_automation.command_reset_button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('driver_automation.request_data_tab')),
    );
    await tester.pump();
    expect(
      find.byKey(
        const ValueKey('driver_automation.request_data_format_button'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('driver_automation.request_data_reset_button')),
      findsOneWidget,
    );
    final requestDataInput = find.byKey(
      const ValueKey('driver_automation.request_data_input'),
    );
    final requestDataEditor = tester.widget<TextField>(requestDataInput);
    final initialRequestData = JsonPayloads.parseObject(
      requestDataEditor.controller!.text,
    );
    expect(initialRequestData['command'], 'system.ready');

    await tester.enterText(requestDataInput, '{"version":"1"}');
    await tester.tap(
      find.byKey(
        const ValueKey('driver_automation.request_data_format_button'),
      ),
    );
    await tester.pump();
    expect(requestDataEditor.controller!.text, '{\n  "version": "1"\n}');
    await tester.enterText(requestDataInput, '{"changed":true}');
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.request_data_reset_button')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.reset_confirm_button')),
    );
    await tester.pump();
    final resetRequestData = JsonPayloads.parseObject(
      requestDataEditor.controller!.text,
    );
    expect(resetRequestData['command'], 'system.ready');
    expect(
      resetRequestData['requestId'],
      isNot(initialRequestData['requestId']),
    );
  });

  testWidgets('keeps the finder editor unchanged when reset is cancelled', (
    tester,
  ) async {
    final transport = _PendingDriverTransport();

    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationPage(transport: transport)),
    );
    await tester.pump();

    final finderInput = find.byKey(
      const ValueKey('driver_automation.finder_input'),
    );
    final finderEditor = tester.widget<TextField>(finderInput);
    await tester.enterText(finderInput, '{"changed":true}');
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.finder_reset_button')),
    );
    await tester.pump();

    expect(find.text('Reset editor?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.reset_cancel_button')),
    );
    await tester.pump();

    expect(finderEditor.controller!.text, '{"changed":true}');
  });

  testWidgets('resets the finder editor to the selected schema example', (
    tester,
  ) async {
    final transport = _PendingDriverTransport();

    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationPage(transport: transport)),
    );
    await tester.pump();

    final finderInput = find.byKey(
      const ValueKey('driver_automation.finder_input'),
    );
    final finderEditor = tester.widget<TextField>(finderInput);
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.finder_schema_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.schema_item_ByText')),
    );
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.schema_use_example_button')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      finderInput,
      '{"finderType":"ByText","text":"Changed"}',
    );
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.finder_reset_button')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.reset_confirm_button')),
    );
    await tester.pump();

    expect(
      finderEditor.controller!.text,
      '{\n  "finderType": "ByText",\n  "text": "Login"\n}',
    );
  });

  testWidgets('preserves editor state when the DevTools app is recreated', (
    tester,
  ) async {
    final transport = _PendingDriverTransport();
    const editorText = '{"finderType":"ByText","text":"Persisted"}';

    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationApp(transport: transport)),
    );
    await tester.pump();
    final finderInput = find.byKey(
      const ValueKey('driver_automation.finder_input'),
    );
    await tester.enterText(finderInput, editorText);

    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationApp(transport: transport)),
    );
    await tester.pump();

    expect(tester.widget<TextField>(finderInput).controller!.text, editorText);
  });

  testWidgets('does not send invalid RequestData JSON', (tester) async {
    final transport = _PendingDriverTransport();

    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationPage(transport: transport)),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.request_data_tab')),
    );
    await tester.pump();

    final requestDataInput = find.byKey(
      const ValueKey('driver_automation.request_data_input'),
    );
    await tester.enterText(requestDataInput, 'not-json');
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.request_data_send_button')),
    );
    await tester.pump();

    expect(find.textContaining('JSON'), findsOneWidget);
    expect(transport.pendingCount, 0);
  });

  testWidgets('opens the finder schema browser without inserting examples', (
    tester,
  ) async {
    final transport = _PendingDriverTransport();

    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationPage(transport: transport)),
    );
    await tester.pump();

    final finderInput = find.byKey(
      const ValueKey('driver_automation.finder_input'),
    );
    final editor = tester.widget<TextField>(finderInput);
    final initialText = editor.controller!.text;

    await tester.tap(
      find.byKey(const ValueKey('driver_automation.finder_schema_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finder Schemas'), findsOneWidget);
    expect(find.text('Built-in'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('ByValueKey'), findsWidgets);
    expect(find.text('ByTextMatch'), findsOneWidget);
    expect(find.text('Find widget by ValueKey.'), findsOneWidget);
    expect(find.textContaining('login_button'), findsNWidgets(2));
    expect(editor.controller!.text, initialText);
  });

  testWidgets('opens the command schema browser from the command editor', (
    tester,
  ) async {
    final transport = _PendingDriverTransport();

    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationPage(transport: transport)),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.command_tab')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.command_schema_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Command Schemas'), findsOneWidget);
    expect(find.text('tap'), findsWidgets);
    expect(find.text('Tap the widget matched by a Finder.'), findsOneWidget);
  });

  testWidgets('uses the selected schema example in the finder editor', (
    tester,
  ) async {
    final transport = _PendingDriverTransport();
    var clipboardWrites = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardWrites++;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationPage(transport: transport)),
    );
    await tester.pump();

    final finderInput = find.byKey(
      const ValueKey('driver_automation.finder_input'),
    );
    final editor = tester.widget<TextField>(finderInput);
    await tester.enterText(finderInput, '{"finderType":"ByText","text":"Old"}');
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.finder_schema_button')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('driver_automation.schema_use_example_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finder Schemas'), findsNothing);
    expect(editor.controller!.text, JsonPayloads.defaultFinder);
    expect(clipboardWrites, 0);
  });

  testWidgets('blocks known schema violations before executing', (
    tester,
  ) async {
    final transport = _PendingDriverTransport();

    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationPage(transport: transport)),
    );
    await tester.pump();

    final finderInput = find.byKey(
      const ValueKey('driver_automation.finder_input'),
    );
    await tester.enterText(
      finderInput,
      '{"finderType":"ByValueKey","keyValueString":"login_button"}',
    );
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.finder_verify_button')),
    );
    await tester.pump();

    expect(
      find.textContaining('Missing required property: keyValueType'),
      findsOneWidget,
    );
    expect(transport.pendingCount, 0);
  });

  testWidgets('allows raw execution and warns for an unknown finder schema', (
    tester,
  ) async {
    final transport = _PendingDriverTransport();

    await tester.pumpWidget(
      MaterialApp(home: DriverAutomationPage(transport: transport)),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('driver_automation.finder_input')),
      '{"finderType":"CustomFinder","foo":"bar"}',
    );
    await tester.tap(
      find.byKey(const ValueKey('driver_automation.finder_verify_button')),
    );
    await tester.pump();

    expect(
      find.textContaining('Schema unavailable for "CustomFinder".'),
      findsOneWidget,
    );
    expect(transport.pendingCount, 1);
    transport.completeNext(
      const DriverTransportResponse(
        response: <String, dynamic>{},
        raw: <String, dynamic>{
          'isError': false,
          'response': <String, dynamic>{},
        },
      ),
    );
    await tester.pump();
  });

  testWidgets(
    'only reports incomplete JSON when schema validation cannot run',
    (tester) async {
      final transport = _PendingDriverTransport();

      await tester.pumpWidget(
        MaterialApp(home: DriverAutomationPage(transport: transport)),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('driver_automation.finder_input')),
        '{"finderType":',
      );
      await tester.tap(
        find.byKey(const ValueKey('driver_automation.finder_verify_button')),
      );
      await tester.pump();

      expect(find.textContaining('Invalid or incomplete JSON'), findsOneWidget);
      expect(find.textContaining('Missing required property'), findsNothing);
      expect(transport.pendingCount, 0);
    },
  );
}

class _ReinspectElementExplorerTransport implements DriverTransport {
  _ReinspectElementExplorerTransport({
    this.failSecond = false,
    this.initialText = 'Initial tree',
  });

  final bool failSecond;
  final String initialText;
  final executionCalls = <Map<String, String>>[];

  @override
  Future<DriverTransportResponse> call(Map<String, String> args) async {
    if (args['command'] == 'get_health') {
      return const DriverTransportResponse(
        response: <String, dynamic>{'status': 'ok'},
        raw: <String, dynamic>{
          'isError': false,
          'response': <String, dynamic>{'status': 'ok'},
        },
      );
    }
    executionCalls.add(Map<String, String>.from(args));
    if (failSecond && executionCalls.length == 2) {
      const response = <String, dynamic>{
        'schemaVersion': 1,
        'matchCount': 0,
        'returnedNodes': 0,
        'visitedNodes': 1,
        'truncated': false,
        'error': <String, dynamic>{
          'code': 'TARGET_NOT_FOUND',
          'message': 'The Finder did not match an Element',
        },
      };
      return const DriverTransportResponse(
        response: response,
        raw: <String, dynamic>{'isError': false, 'response': response},
      );
    }
    final response = _elementExplorerSnapshotResponse(
      executionCalls.length == 1 ? initialText : 'Updated tree',
    );
    return DriverTransportResponse(
      response: response,
      raw: <String, dynamic>{'isError': false, 'response': response},
    );
  }
}

Map<String, dynamic> _elementExplorerSnapshotResponse(String text) {
  return <String, dynamic>{
    'schemaVersion': 1,
    'matchCount': 1,
    'returnedNodes': 2,
    'visitedNodes': 3,
    'truncated': false,
    'root': <String, dynamic>{
      'nodeId': 'n0',
      'parentId': null,
      'widgetType': 'Column',
      'elementType': 'ColumnElement',
      'key': null,
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
          'text': text,
          'semanticsIdentifier': null,
          'isTarget': true,
          'childrenState': 'notRequested',
          'children': <Map<String, dynamic>>[],
        },
      ],
    },
  };
}

class _ElementExplorerErrorTransport implements DriverTransport {
  @override
  Future<DriverTransportResponse> call(Map<String, String> args) async {
    if (args['command'] == 'get_health') {
      return const DriverTransportResponse(
        response: <String, dynamic>{'status': 'ok'},
        raw: <String, dynamic>{
          'isError': false,
          'response': <String, dynamic>{'status': 'ok'},
        },
      );
    }
    return const DriverTransportResponse(
      response: <String, dynamic>{
        'schemaVersion': 1,
        'matchCount': 0,
        'returnedNodes': 0,
        'visitedNodes': 1,
        'truncated': false,
        'error': <String, dynamic>{
          'code': 'TARGET_NOT_FOUND',
          'message': 'The Finder did not match an Element',
        },
      },
      raw: <String, dynamic>{
        'isError': false,
        'response': <String, dynamic>{
          'schemaVersion': 1,
          'matchCount': 0,
          'returnedNodes': 0,
          'visitedNodes': 1,
          'truncated': false,
          'error': <String, dynamic>{
            'code': 'TARGET_NOT_FOUND',
            'message': 'The Finder did not match an Element',
          },
        },
      },
    );
  }
}

class _PendingDriverTransport implements DriverTransport {
  final _pending = <Completer<DriverTransportResponse>>[];

  @override
  Future<DriverTransportResponse> call(Map<String, String> args) {
    if (args['command'] == 'get_health') {
      return Future.value(
        const DriverTransportResponse(
          response: <String, dynamic>{'status': 'ok'},
          raw: <String, dynamic>{
            'isError': false,
            'response': <String, dynamic>{'status': 'ok'},
          },
        ),
      );
    }

    final completer = Completer<DriverTransportResponse>();
    _pending.add(completer);
    return completer.future;
  }

  void completeNext(DriverTransportResponse response) {
    _pending.removeAt(0).complete(response);
  }

  int get pendingCount => _pending.length;
}

class _CaptureDriverTransport implements DriverTransport {
  final executionCalls = <Map<String, String>>[];

  @override
  Future<DriverTransportResponse> call(Map<String, String> args) async {
    if (args['command'] == 'get_health') {
      return const DriverTransportResponse(
        response: <String, dynamic>{'status': 'ok'},
        raw: <String, dynamic>{
          'isError': false,
          'response': <String, dynamic>{'status': 'ok'},
        },
      );
    }
    executionCalls.add(Map<String, String>.from(args));
    return const DriverTransportResponse(
      response: <String, dynamic>{'ok': true},
      raw: <String, dynamic>{
        'isError': false,
        'response': <String, dynamic>{'ok': true},
      },
    );
  }
}

class _ConnectionStateTransport implements DriverTransport {
  _ConnectionStateTransport({required this.connected});

  bool connected;

  @override
  Future<DriverTransportResponse> call(Map<String, String> args) async {
    if (args['command'] == 'get_health') {
      return DriverTransportResponse(
        isError: !connected,
        response:
            connected ? const <String, dynamic>{'status': 'ok'} : 'Offline',
        raw: <String, dynamic>{
          'isError': !connected,
          'response':
              connected ? const <String, dynamic>{'status': 'ok'} : 'Offline',
        },
      );
    }
    return const DriverTransportResponse();
  }
}
