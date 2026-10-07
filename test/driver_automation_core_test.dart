import 'dart:async';

import 'package:driver_devtools/src/driver_automation_core.dart';
import 'package:driver_devtools/src/driver_automation_service.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JsonPayloads', () {
    test('formats valid JSON without changing its values', () {
      final formatted = JsonPayloads.format('{"command":"tap","enabled":true}');

      expect(formatted, '{\n  "command": "tap",\n  "enabled": true\n}');
    });

    test('reports a useful line and column for invalid JSON', () {
      expect(
        () => JsonPayloads.parseObject('{\n  "command": }'),
        throwsA(
          isA<JsonPayloadException>()
              .having((error) => error.line, 'line', 2)
              .having((error) => error.column, 'column', greaterThan(0)),
        ),
      );
    });

    test(
      'builds a finder verification request without whitelisting fields',
      () {
        final request = JsonPayloads.finderVerification(
          '{"finderType":"MyCustomFinder","foo":"bar","enabled":true}',
        );

        expect(request.args, {
          'command': 'waitFor',
          'finderType': 'MyCustomFinder',
          'foo': 'bar',
          'enabled': 'true',
          'timeout': '5000',
        });
      },
    );

    test('flattens a nested command finder into Flutter Driver arguments', () {
      final request = JsonPayloads.command(
        '{"command":"tap","finder":{"finderType":"ByText","text":"Login"},"extra":true}',
      );

      expect(request.args, {
        'command': 'tap',
        'finderType': 'ByText',
        'text': 'Login',
        'extra': 'true',
      });
    });

    test('provides an executable E2E RequestData JSON template', () {
      final template = JsonPayloads.defaultRequestData;
      final request = JsonPayloads.requestData(template);
      final payload = JsonPayloads.parseObject(template);

      expect(request.args, {'command': 'request_data', 'message': template});
      expect(payload['version'], '1');
      expect(payload['command'], 'system.ready');
      expect(payload['params'], <String, dynamic>{});
      expect(
        payload['requestId'],
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('generates a new RequestData requestId for each template', () {
      final first = JsonPayloads.parseObject(JsonPayloads.defaultRequestData);
      final second = JsonPayloads.parseObject(JsonPayloads.defaultRequestData);

      expect(first['requestId'], isNot(second['requestId']));
    });

    test('rejects a RequestData message that is not JSON', () {
      expect(
        () => JsonPayloads.requestData('ping'),
        throwsA(isA<JsonPayloadException>()),
      );
    });

    test('pretty prints JSON responses and leaves plain text untouched', () {
      expect(
        JsonPayloads.displayResponse('{"username":"hien"}'),
        '{\n  "username": "hien"\n}',
      );
      expect(JsonPayloads.displayResponse('plain text'), 'plain text');
      expect(
        JsonPayloads.displayResponse(<String, dynamic>{'ok': true}),
        '{\n  "ok": true\n}',
      );
    });
  });

  group('DriverAutomationController', () {
    test('marks the driver connected when get_health succeeds', () async {
      final transport = FakeDriverTransport(
        response: const DriverTransportResponse(
          response: <String, dynamic>{'status': 'ok'},
          raw: <String, dynamic>{
            'isError': false,
            'response': <String, dynamic>{'status': 'ok'},
          },
        ),
      );
      final controller = DriverAutomationController(transport);

      await controller.connect();

      expect(controller.status, DriverConnectionStatus.connected);
      expect(transport.calls.single, {'command': 'get_health'});
    });

    test(
      'returns a failed result and keeps raw response on driver errors',
      () async {
        final transport = FakeDriverTransport(
          response: const DriverTransportResponse(
            isError: true,
            response: 'Timeout',
            raw: <String, dynamic>{'isError': true, 'response': 'Timeout'},
          ),
        );
        final controller = DriverAutomationController(transport);

        final result = await controller.execute(
          JsonPayloads.requestData(JsonPayloads.defaultRequestData),
        );

        expect(result.success, isFalse);
        expect(result.error, 'Timeout');
        expect(result.rawResponse, contains('Timeout'));
      },
    );

    test('times out a stuck driver request and logs the timeout', () async {
      final logs = <String>[];
      final controller = DriverAutomationController(
        _BlockingDriverTransport(),
        requestTimeout: const Duration(milliseconds: 1),
        logger: (message, {error, stackTrace}) => logs.add(message),
      );

      final result = await controller.execute(
        JsonPayloads.requestData(JsonPayloads.defaultRequestData),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('timed out'));
      expect(logs, contains('Driver request timed out.'));
    });

    test(
      'treats an empty transport response as an error and logs it',
      () async {
        final logs = <String>[];
        final controller = DriverAutomationController(
          FakeDriverTransport(response: const DriverTransportResponse()),
          logger: (message, {error, stackTrace}) => logs.add(message),
        );

        final result = await controller.execute(
          JsonPayloads.requestData(JsonPayloads.defaultRequestData),
        );

        expect(result.success, isFalse);
        expect(controller.status, DriverConnectionStatus.unavailable);
        expect(result.error, contains('empty response'));
        expect(logs, contains('Driver returned an empty response.'));
      },
    );

    test(
      'marks the controller disconnected and logs connection failures',
      () async {
        final logs = <String>[];
        final controller = DriverAutomationController(
          _DisconnectedDriverTransport(),
          logger: (message, {error, stackTrace}) => logs.add(message),
        );

        final result = await controller.execute(
          JsonPayloads.requestData(JsonPayloads.defaultRequestData),
        );

        expect(result.success, isFalse);
        expect(controller.status, DriverConnectionStatus.disconnected);
        expect(logs, contains('Driver request failed.'));
      },
    );
  });

  group('DriverAutomationService', () {
    test(
      'uses the shared ServiceManager connection as its transport',
      () async {
        final service = DriverAutomationService(ServiceManager());

        expect(service.isConnected, isFalse);
        await expectLater(
          service.call(<String, String>{'command': 'get_health'}),
          throwsA(isA<DriverDisconnectedException>()),
        );
      },
    );

    test('logs when the shared VM Service is disconnected', () async {
      final logs = <String>[];
      final service = DriverAutomationService(
        ServiceManager(),
        logger: (message, {error, stackTrace}) => logs.add(message),
      );

      await expectLater(
        service.call(<String, String>{'command': 'get_health'}),
        throwsA(isA<DriverDisconnectedException>()),
      );

      expect(
        logs,
        contains('Cannot call driver extension while disconnected.'),
      );
    });
  });
}

class FakeDriverTransport implements DriverTransport {
  FakeDriverTransport({required this.response});

  final DriverTransportResponse response;
  final calls = <Map<String, String>>[];

  @override
  Future<DriverTransportResponse> call(Map<String, String> args) async {
    calls.add(args);
    return response;
  }
}

class _BlockingDriverTransport implements DriverTransport {
  @override
  Future<DriverTransportResponse> call(Map<String, String> args) {
    return Completer<DriverTransportResponse>().future;
  }
}

class _DisconnectedDriverTransport implements DriverTransport {
  @override
  Future<DriverTransportResponse> call(Map<String, String> args) {
    throw const DriverDisconnectedException();
  }
}
