import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'protocol/schema/protocol_schema.dart';
import 'protocol/schema/protocol_schema_registry.dart';

const driverExtensionName = 'ext.flutter.driver';
const finderVerificationTimeout = '5000';
const driverRequestTimeout = Duration(seconds: 30);
const driverConnectionTimeout = Duration(seconds: 5);

typedef DriverErrorLogger =
    void Function(String message, {Object? error, StackTrace? stackTrace});

void defaultDriverErrorLogger(
  String message, {
  Object? error,
  StackTrace? stackTrace,
}) {
  developer.log(
    message,
    name: 'driver_devtools',
    level: 1000,
    error: error,
    stackTrace: stackTrace,
  );
}

enum DriverOperationKind { finderVerify, command, requestData }

class DriverRequest {
  const DriverRequest({
    required this.kind,
    required this.rawInput,
    required this.args,
    this.payload,
  });

  final DriverOperationKind kind;
  final String rawInput;
  final Map<String, String> args;
  final Map<String, dynamic>? payload;
}

class JsonPayloadException implements Exception {
  const JsonPayloadException({
    required this.message,
    required this.line,
    required this.column,
  });

  final String message;
  final int line;
  final int column;

  @override
  String toString() => '$message (Line $line, Column $column)';
}

class JsonPayloads {
  const JsonPayloads._();

  static String get defaultFinder => _formatSchemaExample(
    ProtocolSchemaRegistry.builtIn.findFinder('ByValueKey')!,
  );

  static String get defaultCommand =>
      _formatSchemaExample(ProtocolSchemaRegistry.builtIn.findCommand('tap')!);

  static String _formatSchemaExample(ProtocolSchema schema) =>
      const JsonEncoder.withIndent('  ').convert(schema.example);

  static String get defaultRequestData =>
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'version': '1',
        'requestId': _uuidV4(),
        'command': 'system.ready',
        'params': <String, dynamic>{},
      });

  static Map<String, dynamic> parseObject(String source) {
    final decoded = _decode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const JsonPayloadException(
        message: 'JSON object required.',
        line: 1,
        column: 1,
      );
    }
    return decoded;
  }

  static String format(String source) {
    final decoded = _decode(source);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  }

  static DriverRequest finderVerification(String source) {
    final finder = parseObject(source);
    final args = <String, String>{
      ..._toDriverArgs(finder),
      'command': 'waitFor',
      'timeout': finderVerificationTimeout,
    };
    return DriverRequest(
      kind: DriverOperationKind.finderVerify,
      rawInput: source,
      args: args,
      payload: finder,
    );
  }

  static DriverRequest command(String source) {
    final command = parseObject(source);
    return DriverRequest(
      kind: DriverOperationKind.command,
      rawInput: source,
      args: _toDriverArgs(command),
      payload: command,
    );
  }

  static DriverRequest requestData(String source) {
    final payload = parseObject(source);
    return DriverRequest(
      kind: DriverOperationKind.requestData,
      rawInput: source,
      args: <String, String>{'command': 'request_data', 'message': source},
      payload: payload,
    );
  }

  static String displayResponse(Object? response) {
    if (response == null) return '';

    if (response is String) {
      try {
        final decoded = jsonDecode(response);
        if (decoded is Map<String, dynamic> || decoded is List<dynamic>) {
          return const JsonEncoder.withIndent('  ').convert(decoded);
        }
      } on FormatException {
        // A RequestData response is allowed to be arbitrary plain text.
      }
      return response;
    }

    if (response is Map<String, dynamic> || response is List<dynamic>) {
      return const JsonEncoder.withIndent('  ').convert(response);
    }

    return response.toString();
  }

  static dynamic _decode(String source) {
    try {
      return jsonDecode(source);
    } on FormatException catch (error) {
      final offset = error.offset ?? source.length;
      final safeOffset = offset.clamp(0, source.length);
      final beforeError = source.substring(0, safeOffset);
      final line = '\n'.allMatches(beforeError).length + 1;
      final lastLineBreak = beforeError.lastIndexOf('\n');
      final column = safeOffset - lastLineBreak;
      throw JsonPayloadException(
        message: error.message,
        line: line,
        column: column,
      );
    }
  }

  static Map<String, String> _toDriverArgs(Map<String, dynamic> payload) {
    final args = <String, String>{};
    for (final entry in payload.entries) {
      if (entry.key == 'finder' && entry.value is Map<String, dynamic>) {
        final finder = entry.value as Map<String, dynamic>;
        args.addAll(_toDriverArgs(finder));
      } else {
        args[entry.key] = _encodeDriverValue(entry.value);
      }
    }
    final command = payload['command'];
    if (command != null) {
      args['command'] = _encodeDriverValue(command);
    }
    return args;
  }

  static String _encodeDriverValue(Object? value) {
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    if (value is Map<String, dynamic>) {
      return jsonEncode(<String, String>{
        for (final entry in value.entries)
          entry.key: _encodeDriverValue(entry.value),
      });
    }
    return jsonEncode(_normalizeNestedValue(value));
  }

  static Object? _normalizeNestedValue(Object? value) {
    if (value == null || value is String) return value;
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      return value
          .map<Object?>((item) => _normalizeNestedValue(item))
          .toList();
    }
    if (value is Map<String, dynamic>) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key: _normalizeNestedValue(entry.value),
      };
    }
    return value;
  }

  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map(_hexByte).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static String _hexByte(int byte) => byte.toRadixString(16).padLeft(2, '0');
}

class DriverTransportResponse {
  const DriverTransportResponse({
    this.isError = false,
    this.response,
    this.raw,
  });

  final bool isError;
  final Object? response;
  final Object? raw;
}

abstract interface class DriverTransport {
  Future<DriverTransportResponse> call(Map<String, String> args);
}

class DriverDisconnectedException implements Exception {
  const DriverDisconnectedException();

  @override
  String toString() => 'VM Service is disconnected.';
}

class DriverRequestTimeoutException implements Exception {
  const DriverRequestTimeoutException(this.timeout);

  final Duration timeout;

  @override
  String toString() =>
      'Driver request timed out after ${timeout.inMilliseconds} ms.';
}

class DriverEmptyResponseException implements Exception {
  const DriverEmptyResponseException();

  @override
  String toString() => 'Driver returned an empty response.';
}

enum DriverConnectionStatus {
  connecting,
  connected,
  unavailable,
  reconnecting,
  disconnected,
}

class DriverExecutionResult {
  const DriverExecutionResult({
    required this.request,
    required this.success,
    required this.duration,
    required this.rawRequest,
    required this.rawResponse,
    this.response,
    this.error,
  });

  final DriverRequest request;
  final bool success;
  final Duration duration;
  final String rawRequest;
  final String rawResponse;
  final Object? response;
  final String? error;
}

class DriverAutomationController {
  DriverAutomationController(
    this.transport, {
    this.requestTimeout = driverRequestTimeout,
    this.connectionTimeout = driverConnectionTimeout,
    DriverErrorLogger? logger,
  }) : _logger = logger ?? defaultDriverErrorLogger;

  final DriverTransport transport;
  final Duration requestTimeout;
  final Duration connectionTimeout;
  final DriverErrorLogger _logger;
  final _listeners = <void Function()>[];
  DriverConnectionStatus _status = DriverConnectionStatus.connecting;
  Future<void>? _connectionAttempt;

  DriverConnectionStatus get status => _status;

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void dispose() => _listeners.clear();

  Future<void> connect() {
    return _startConnection(reconnecting: false);
  }

  Future<void> reconnect() {
    return _startConnection(reconnecting: true);
  }

  Future<DriverExecutionResult> execute(DriverRequest request) async {
    final stopwatch = Stopwatch()..start();
    final rawRequest = JsonPayloads.displayResponse(request.args);

    try {
      final response = await transport
          .call(request.args)
          .timeout(requestTimeout);
      if (response.raw == null && response.response == null) {
        const error = DriverEmptyResponseException();
        _setStatus(DriverConnectionStatus.unavailable);
        _logger('Driver returned an empty response.', error: error);
        return _failedResult(request, stopwatch, rawRequest, error);
      }
      stopwatch.stop();
      final responseText = JsonPayloads.displayResponse(response.raw);
      final error =
          response.isError
              ? JsonPayloads.displayResponse(response.response)
              : null;
      if (response.isError) {
        _logger(
          'Driver extension returned an error.',
          error: response.response ?? error,
        );
      }
      return DriverExecutionResult(
        request: request,
        success: !response.isError,
        duration: stopwatch.elapsed,
        rawRequest: rawRequest,
        rawResponse: responseText,
        response: response.response,
        error: error,
      );
    } on TimeoutException catch (error, stackTrace) {
      stopwatch.stop();
      final timeoutError = DriverRequestTimeoutException(requestTimeout);
      _logger(
        'Driver request timed out.',
        error: timeoutError,
        stackTrace: stackTrace,
      );
      return DriverExecutionResult(
        request: request,
        success: false,
        duration: stopwatch.elapsed,
        rawRequest: rawRequest,
        rawResponse: timeoutError.toString(),
        error: timeoutError.toString(),
      );
    } catch (error, stackTrace) {
      stopwatch.stop();
      if (error is DriverDisconnectedException) {
        _setStatus(DriverConnectionStatus.disconnected);
      } else {
        _setStatus(DriverConnectionStatus.unavailable);
      }
      _logger('Driver request failed.', error: error, stackTrace: stackTrace);
      return DriverExecutionResult(
        request: request,
        success: false,
        duration: stopwatch.elapsed,
        rawRequest: rawRequest,
        rawResponse: error.toString(),
        error: error.toString(),
      );
    }
  }

  Future<void> _startConnection({required bool reconnecting}) {
    final existingAttempt = _connectionAttempt;
    if (existingAttempt != null) return existingAttempt;

    _setStatus(
      reconnecting
          ? DriverConnectionStatus.reconnecting
          : DriverConnectionStatus.connecting,
    );
    return _connectionAttempt = _probe().whenComplete(() {
      _connectionAttempt = null;
    });
  }

  Future<void> _probe() async {
    try {
      final response = await transport
          .call(<String, String>{'command': 'get_health'})
          .timeout(connectionTimeout);
      if (response.raw == null && response.response == null) {
        const error = DriverEmptyResponseException();
        _setStatus(DriverConnectionStatus.unavailable);
        _logger('Driver returned an empty response.', error: error);
        return;
      }
      _setStatus(
        response.isError
            ? DriverConnectionStatus.unavailable
            : DriverConnectionStatus.connected,
      );
      if (response.isError) {
        _logger('Driver health check failed.', error: response.response);
      }
    } on TimeoutException catch (error, stackTrace) {
      _setStatus(DriverConnectionStatus.unavailable);
      _logger(
        'Driver connection probe timed out.',
        error: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      _setStatus(
        error is DriverDisconnectedException
            ? DriverConnectionStatus.disconnected
            : DriverConnectionStatus.unavailable,
      );
      _logger(
        'Driver connection probe failed.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  DriverExecutionResult _failedResult(
    DriverRequest request,
    Stopwatch stopwatch,
    String rawRequest,
    Object error,
  ) {
    stopwatch.stop();
    return DriverExecutionResult(
      request: request,
      success: false,
      duration: stopwatch.elapsed,
      rawRequest: rawRequest,
      rawResponse: error.toString(),
      error: error.toString(),
    );
  }

  void _setStatus(DriverConnectionStatus status) {
    if (_status == status) return;
    _status = status;
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
  }
}
