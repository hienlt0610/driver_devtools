import 'package:devtools_app_shared/service.dart';
import 'package:flutter/foundation.dart';

import 'driver_automation_core.dart';

/// VM Service adapter for the Driver Automation extension.
///
/// [ServiceManager] is created and connected by [DevToolsExtension]. This
/// class intentionally does not create another VM Service connection; it only
/// exposes the shared DevTools service lifecycle to the driver console.
class DriverAutomationService implements DriverTransport {
  DriverAutomationService(this.serviceManager, {DriverErrorLogger? logger})
    : _logger = logger ?? defaultDriverErrorLogger;

  final ServiceManager serviceManager;
  final DriverErrorLogger _logger;

  /// Connection changes from the shared DevTools service manager.
  Listenable get connectionChanges => serviceManager.connectedState;

  /// Main-isolate changes from the shared DevTools isolate manager.
  Listenable get isolateChanges => serviceManager.isolateManager.mainIsolate;

  bool get isConnected =>
      serviceManager.connectedState.value.connected &&
      serviceManager.service != null;

  @override
  Future<DriverTransportResponse> call(Map<String, String> args) async {
    if (!isConnected) {
      const error = DriverDisconnectedException();
      _logger('Cannot call driver extension while disconnected.', error: error);
      throw error;
    }

    final response = await serviceManager.callServiceExtensionOnMainIsolate(
      driverExtensionName,
      args: args,
    );
    final raw = response.json;
    if (raw == null) {
      const error = DriverEmptyResponseException();
      _logger('Driver service returned no response data.', error: error);
      throw error;
    }
    return DriverTransportResponse(
      isError: raw['isError'] == true,
      response: raw['response'],
      raw: raw,
    );
  }
}
