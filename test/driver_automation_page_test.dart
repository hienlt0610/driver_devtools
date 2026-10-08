import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:driver_devtools/src/driver_automation_core.dart';
import 'package:driver_devtools/src/driver_automation_page.dart';
import 'package:driver_devtools/main.dart' show DriverAutomationApp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(tester.widget<DevToolsButton>(verifyButton).onPressed, isNull);

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
    expect(find.text('Response'), findsOneWidget);
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
    final historySummary = historyTile.subtitle! as Text;
    expect(historySummary.data, startsWith('Failed ·'));
    expect(historySummary.data, isNot(contains('Timeout')));
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

    expect(find.text('Finder Verify'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('driver_automation.history_clear_button')),
    );
    await tester.pump();

    expect(find.text('Finder Verify'), findsNothing);
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
    expect(find.textContaining('login_button'), findsOneWidget);
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
