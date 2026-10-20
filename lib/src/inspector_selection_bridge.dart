import 'dart:async';
import 'dart:convert';

import 'package:devtools_app_shared/service.dart';

const _getSelectedWidgetExtension = 'ext.flutter.inspector.getSelectedWidget';
const _disposeGroupExtension = 'ext.flutter.inspector.disposeGroup';
const _selectionObjectGroup = 'driver_devtools_selection';

typedef InspectorSelectionQuery = Future<String?> Function();

class InspectorSelectionCoordinator {
  InspectorSelectionCoordinator({
    required this.query,
    required this.onSelection,
    this.onError,
  });

  final InspectorSelectionQuery query;
  final void Function(String? valueId) onSelection;
  final void Function(Object error)? onError;

  int _generation = 0;
  bool _disposed = false;

  Future<void> refresh() async {
    final generation = ++_generation;
    try {
      final valueId = await query();
      if (!_disposed && generation == _generation) {
        onSelection(valueId);
      }
    } catch (error) {
      if (!_disposed && generation == _generation) {
        onError?.call(error);
      }
    }
  }

  void invalidate() {
    _generation++;
  }

  void dispose() {
    _disposed = true;
    _generation++;
  }
}

class InspectorSelectionBridge {
  InspectorSelectionBridge(
    this.serviceManager, {
    required this.onSelection,
    this.onError,
  }) {
    _coordinator = InspectorSelectionCoordinator(
      query: _querySelectedValueId,
      onSelection: _emitSelection,
      onError: onError,
    );
  }

  final ServiceManager serviceManager;
  final void Function(String? valueId) onSelection;
  final void Function(Object error)? onError;
  late final InspectorSelectionCoordinator _coordinator;

  dynamic _attachedService;
  StreamSubscription<dynamic>? _debugSubscription;
  Timer? _pollTimer;
  bool _active = false;
  bool _disposed = false;
  bool _hasEmittedSelection = false;
  String? _lastEmittedValueId;

  static String? parseSelectedValueId(Object? source) {
    Object? decoded = source;
    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } on FormatException catch (error) {
        throw FormatException('Invalid Inspector selection JSON: $error');
      }
    }
    if (decoded == null) return null;
    if (decoded is! Map) {
      throw const FormatException('Inspector selection must be an object.');
    }
    final valueId = decoded['valueId'];
    if (valueId == null) return null;
    if (valueId is! String || valueId.isEmpty) {
      throw const FormatException(
        'Inspector valueId must be a non-empty string.',
      );
    }
    return valueId;
  }

  Future<void> refreshConnection() async {
    if (_disposed) return;
    final service = serviceManager.service;
    if (!serviceManager.connectedState.value.connected || service == null) {
      await _detach();
      return;
    }
    if (!identical(_attachedService, service)) {
      await _attach(service);
    }
    if (_active) {
      unawaited(_coordinator.refresh());
    }
  }

  void setActive(bool active) {
    if (_disposed || _active == active) return;
    _active = active;
    if (_active) {
      _startPolling();
      unawaited(refreshConnection());
    } else {
      _stopPolling();
      _coordinator.invalidate();
    }
  }

  Future<void> disposeObjectGroup(String groupName) async {
    final service = serviceManager.service;
    if (service == null) return;
    try {
      await serviceManager.callServiceExtensionOnMainIsolate(
        _disposeGroupExtension,
        args: <String, String>{'objectGroup': groupName},
      );
    } catch (error) {
      onError?.call(error);
    }
  }

  Future<void> _attach(dynamic service) async {
    await _debugSubscription?.cancel();
    _attachedService = service;
    _hasEmittedSelection = false;
    _debugSubscription = service.onDebugEvent.listen((event) {
      if (_active && event.kind == 'Inspect') {
        unawaited(_coordinator.refresh());
      }
    });
    _startPolling();
  }

  Future<void> _detach() async {
    _coordinator.invalidate();
    await _debugSubscription?.cancel();
    _debugSubscription = null;
    _attachedService = null;
    _stopPolling();
    if (_active) {
      _emitSelection(null);
      _hasEmittedSelection = false;
    }
  }

  void _emitSelection(String? valueId) {
    if (_hasEmittedSelection && _lastEmittedValueId == valueId) return;
    _hasEmittedSelection = true;
    _lastEmittedValueId = valueId;
    onSelection(valueId);
  }

  void _startPolling() {
    if (!_active || _pollTimer != null) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_coordinator.refresh());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<String?> _querySelectedValueId() async {
    final service = serviceManager.service;
    if (service == null) return null;
    await disposeObjectGroup(_selectionObjectGroup);
    final response = await serviceManager.callServiceExtensionOnMainIsolate(
      _getSelectedWidgetExtension,
      args: const <String, String>{'objectGroup': _selectionObjectGroup},
    );
    return parseSelectedValueId(response.json?['result']);
  }

  void close() {
    if (_disposed) return;
    _disposed = true;
    _coordinator.dispose();
    _stopPolling();
    unawaited(_debugSubscription?.cancel());
    _debugSubscription = null;
    unawaited(disposeObjectGroup(_selectionObjectGroup));
  }
}
