import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'src/driver_automation_core.dart';
import 'src/driver_automation_page.dart';

export 'src/driver_automation_core.dart';
export 'src/driver_automation_page.dart';
export 'src/driver_automation_service.dart';
export 'src/protocol/schema/command_schema.dart';
export 'src/protocol/schema/builtin_command_schemas.dart';
export 'src/protocol/schema/builtin_finder_schemas.dart';
export 'src/protocol/schema/finder_schema.dart';
export 'src/protocol/schema/property_schema.dart';
export 'src/protocol/schema/protocol_schema.dart';
export 'src/protocol/schema/protocol_schema_registry.dart';

void main() {
  runApp(const DevToolsExtension(child: DriverAutomationApp()));
}

class DriverAutomationApp extends StatelessWidget {
  const DriverAutomationApp({super.key, this.transport});

  static final _session = DriverAutomationSession();

  final DriverTransport? transport;

  @override
  Widget build(BuildContext context) {
    return DriverAutomationPage(transport: transport, session: _session);
  }
}
