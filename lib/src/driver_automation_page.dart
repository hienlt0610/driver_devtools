import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'driver_automation_core.dart';
import 'driver_automation_service.dart';
import 'protocol/schema/protocol_schema.dart';
import 'protocol/schema/protocol_schema_registry.dart';
import 'protocol/schema/schema_browser.dart';

class DriverAutomationSession {
  DriverAutomationSession()
    : finderText = JsonPayloads.defaultFinder,
      commandText = JsonPayloads.defaultCommand,
      requestDataText = JsonPayloads.defaultRequestData,
      finderResetTemplate = JsonPayloads.defaultFinder,
      commandResetTemplate = JsonPayloads.defaultCommand;

  String finderText;
  String commandText;
  String requestDataText;
  String finderResetTemplate;
  String commandResetTemplate;
  DriverExecutionResult? finderResult;
  DriverExecutionResult? commandResult;
  DriverExecutionResult? requestDataResult;
  final history = <HistoryEntry>[];
  String? finderError;
  String? commandError;
  String? requestDataError;
  String? finderSchemaMessage;
  String? commandSchemaMessage;
  int selectedTabIndex = 0;
}

class DriverAutomationPage extends StatefulWidget {
  const DriverAutomationPage({
    super.key,
    this.transport,
    this.schemaRegistry,
    this.session,
  });

  final DriverTransport? transport;
  final ProtocolSchemaRegistry? schemaRegistry;
  final DriverAutomationSession? session;

  @override
  State<DriverAutomationPage> createState() => _DriverAutomationPageState();
}

class _DriverOperation {
  bool cancelled = false;
}

class _DriverAutomationPageState extends State<DriverAutomationPage>
    with AutoDisposeMixin {
  ProtocolSchemaRegistry get _schemaRegistry =>
      widget.schemaRegistry ?? ProtocolSchemaRegistry.builtIn;

  late final DriverAutomationController _controller;
  late final DriverTransport _transport;
  late final DriverAutomationSession _session;
  DriverAutomationService? _service;
  late final JsonTextEditingController _finderEditor;
  late final JsonTextEditingController _commandEditor;
  late final JsonTextEditingController _requestDataEditor;

  final _busyOperations = <DriverOperationKind>{};
  final _activeOperations = <DriverOperationKind, _DriverOperation>{};

  DriverExecutionResult? get _finderResult => _session.finderResult;
  set _finderResult(DriverExecutionResult? value) {
    _session.finderResult = value;
  }

  DriverExecutionResult? get _commandResult => _session.commandResult;
  set _commandResult(DriverExecutionResult? value) {
    _session.commandResult = value;
  }

  DriverExecutionResult? get _requestDataResult => _session.requestDataResult;
  set _requestDataResult(DriverExecutionResult? value) {
    _session.requestDataResult = value;
  }

  List<HistoryEntry> get _history => _session.history;

  String? get _finderError => _session.finderError;
  set _finderError(String? value) {
    _session.finderError = value;
  }

  String? get _commandError => _session.commandError;
  set _commandError(String? value) {
    _session.commandError = value;
  }

  String? get _requestDataError => _session.requestDataError;
  set _requestDataError(String? value) {
    _session.requestDataError = value;
  }

  String? get _finderSchemaMessage => _session.finderSchemaMessage;
  set _finderSchemaMessage(String? value) {
    _session.finderSchemaMessage = value;
  }

  String? get _commandSchemaMessage => _session.commandSchemaMessage;
  set _commandSchemaMessage(String? value) {
    _session.commandSchemaMessage = value;
  }

  @override
  void initState() {
    super.initState();
    _session = widget.session ?? DriverAutomationSession();
    if (widget.transport == null) {
      _service = DriverAutomationService(serviceManager);
    }
    _transport = widget.transport ?? _service!;
    _controller = DriverAutomationController(_transport)
      ..addListener(_onControllerChanged);
    _finderEditor = JsonTextEditingController(text: _session.finderText)
      ..addListener(() => _session.finderText = _finderEditor.text);
    _commandEditor = JsonTextEditingController(text: _session.commandText)
      ..addListener(() => _session.commandText = _commandEditor.text);
    _requestDataEditor = JsonTextEditingController(
      text: _session.requestDataText,
    )..addListener(() => _session.requestDataText = _requestDataEditor.text);

    if (_service case final service?) {
      addAutoDisposeListener(
        service.connectionChanges,
        _onDevToolsConnectionChanged,
      );
      addAutoDisposeListener(service.isolateChanges, _onMainIsolateChanged);
    }
    unawaited(_controller.connect());
  }

  @override
  void dispose() {
    for (final operation in _activeOperations.values) {
      operation.cancelled = true;
    }
    _activeOperations.clear();
    _busyOperations.clear();
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    _finderEditor.dispose();
    _commandEditor.dispose();
    _requestDataEditor.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onDevToolsConnectionChanged() {
    if (!mounted) return;
    unawaited(_controller.reconnect());
  }

  void _onMainIsolateChanged() {
    if (!mounted || !(_service?.isConnected ?? false)) return;
    unawaited(_controller.reconnect());
  }

  void _retryConnection() {
    unawaited(_controller.reconnect());
  }

  void _clearHistory() {
    if (_history.isEmpty) return;
    setState(_history.clear);
  }

  Future<void> _verifyFinder() async {
    final request = _parse(
      _finderEditor.text,
      JsonPayloads.finderVerification,
      onError: (error) => _finderError = error,
      clearError: () => _finderError = null,
      validateSchema: _schemaRegistry.validateFinderPayload,
      onSchemaMessage: (message) => _finderSchemaMessage = message,
    );
    if (request == null) {
      setState(() {});
      return;
    }
    await _execute(request, onResult: (result) => _finderResult = result);
  }

  Future<void> _executeCommand() async {
    final request = _parse(
      _commandEditor.text,
      JsonPayloads.command,
      onError: (error) => _commandError = error,
      clearError: () => _commandError = null,
      validateSchema: _schemaRegistry.validateCommandPayload,
      onSchemaMessage: (message) => _commandSchemaMessage = message,
    );
    if (request == null) {
      setState(() {});
      return;
    }
    await _execute(request, onResult: (result) => _commandResult = result);
  }

  Future<void> _sendRequestData() async {
    final request = _parse(
      _requestDataEditor.text,
      JsonPayloads.requestData,
      onError: (error) => _requestDataError = error,
      clearError: () => _requestDataError = null,
    );
    if (request == null) {
      setState(() {});
      return;
    }
    await _execute(request, onResult: (result) => _requestDataResult = result);
  }

  DriverRequest? _parse(
    String source,
    DriverRequest Function(String) parser, {
    required void Function(String) onError,
    required VoidCallback clearError,
    ProtocolSchemaValidationResult Function(Map<String, dynamic> payload)?
    validateSchema,
    void Function(String? message)? onSchemaMessage,
  }) {
    try {
      final request = parser(source);
      final schemaResult =
          request.payload == null || validateSchema == null
              ? null
              : validateSchema(request.payload!);
      if (schemaResult != null) {
        onSchemaMessage?.call(
          schemaResult.messages.isEmpty
              ? null
              : schemaResult.messages.join('\n'),
        );
        if (!schemaResult.isValid) {
          onError(schemaResult.errors.join('\n'));
          return null;
        }
      }
      clearError();
      return request;
    } on JsonPayloadException catch (error) {
      onSchemaMessage?.call(null);
      onError(
        'Invalid or incomplete JSON\n'
        '${error.message}\nLine ${error.line}, Column ${error.column}',
      );
      return null;
    }
  }

  void _openSchemaBrowser(
    BuildContext context, {
    required ProtocolSchemaKind kind,
    required JsonTextEditingController editor,
    required void Function(String?) clearError,
    required void Function(String?) clearSchemaMessage,
  }) {
    showDialog<void>(
      context: context,
      builder:
          (context) => SchemaBrowserDialog(
            kind: kind,
            registry: _schemaRegistry,
            onUseExample: (example) {
              setState(() {
                if (kind == ProtocolSchemaKind.finder) {
                  _session.finderResetTemplate = example;
                } else {
                  _session.commandResetTemplate = example;
                }
                editor.value = TextEditingValue(
                  text: example,
                  selection: TextSelection.collapsed(offset: example.length),
                  composing: TextRange.empty,
                );
                clearError(null);
                clearSchemaMessage(null);
              });
            },
          ),
    );
  }

  Future<void> _execute(
    DriverRequest request, {
    required void Function(DriverExecutionResult result) onResult,
  }) async {
    final operation = _DriverOperation();
    _activeOperations[request.kind] = operation;
    setState(() => _busyOperations.add(request.kind));
    try {
      final result = await _controller.execute(request);
      if (!mounted ||
          operation.cancelled ||
          !identical(_activeOperations[request.kind], operation)) {
        return;
      }
      setState(() {
        onResult(result);
        _history.insert(0, HistoryEntry(result));
        if (_history.length > 50) _history.removeLast();
        _busyOperations.remove(request.kind);
      });
    } finally {
      if (identical(_activeOperations[request.kind], operation)) {
        _activeOperations.remove(request.kind);
        if (mounted) {
          setState(() => _busyOperations.remove(request.kind));
        }
      }
    }
  }

  void _stopOperation(DriverOperationKind kind) {
    final operation = _activeOperations.remove(kind);
    if (operation == null) return;
    operation.cancelled = true;
    if (mounted) {
      setState(() => _busyOperations.remove(kind));
    }
  }

  void _formatEditor(
    TextEditingController editor,
    void Function(String?) setError,
  ) {
    try {
      final formatted = JsonPayloads.format(editor.text);
      setState(() {
        editor.value = editor.value.copyWith(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
          composing: TextRange.empty,
        );
        setError(null);
      });
    } on JsonPayloadException catch (error) {
      setState(() {
        setError(
          '${error.message}\nLine ${error.line}, Column ${error.column}',
        );
      });
    }
  }

  void _resetEditor(
    TextEditingController editor,
    String template,
    void Function(String?) setError,
  ) {
    setState(() {
      editor.value = TextEditingValue(
        text: template,
        selection: TextSelection.collapsed(offset: template.length),
        composing: TextRange.empty,
      );
      setError(null);
    });
  }

  Future<void> _confirmReset(
    BuildContext context, {
    required TextEditingController editor,
    required String template,
    required void Function(String?) setError,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset editor?'),
          content: const Text(
            'This will replace the current JSON with the reset template.',
          ),
          actions: [
            TextButton(
              key: const ValueKey<String>(
                'driver_automation.reset_cancel_button',
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey<String>(
                'driver_automation.reset_confirm_button',
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
    if (!mounted || confirmed != true) return;
    _resetEditor(editor, template, setError);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1100,
              maxHeight: constraints.maxHeight,
            ),
            child: SizedBox(
              height: constraints.maxHeight,
              width: double.infinity,
              child: DefaultTabController(
                length: 3,
                initialIndex: _session.selectedTabIndex,
                child: Column(
                  children: [
                    AreaPaneHeader(
                      title: const Text('Driver Automation'),
                      includeLeftBorder: true,
                      includeRightBorder: true,
                      actions: [_ConnectionHeader(status: _controller.status)],
                    ),
                    TabBar(
                      onTap: (index) => _session.selectedTabIndex = index,
                      tabs: [
                        Tab(
                          key: ValueKey<String>('driver_automation.finder_tab'),
                          text: 'FINDER',
                        ),
                        Tab(
                          key: ValueKey<String>(
                            'driver_automation.command_tab',
                          ),
                          text: 'COMMAND',
                        ),
                        Tab(
                          key: ValueKey<String>(
                            'driver_automation.request_data_tab',
                          ),
                          text: 'REQUEST DATA',
                        ),
                      ],
                    ),
                    if (_controller.status ==
                        DriverConnectionStatus.unavailable)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _DriverUnavailableNotice(
                          onRetry: _retryConnection,
                        ),
                      ),
                    if (_controller.status ==
                        DriverConnectionStatus.disconnected)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _DriverDisconnectedNotice(
                          onRetry: _retryConnection,
                        ),
                      ),
                    Expanded(
                      child: TabBarView(
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildTabContent(_buildFinderConsole(context)),
                          _buildTabContent(_buildCommandConsole(context)),
                          _buildTabContent(_buildRequestDataConsole(context)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabContent(Widget console) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        console,
        const SizedBox(height: 12),
        _HistoryPanel(entries: _history, onClear: _clearHistory),
      ],
    );
  }

  Widget _buildFinderConsole(BuildContext context) {
    final isProcessing = _busyOperations.contains(
      DriverOperationKind.finderVerify,
    );
    final canExecute = _controller.status == DriverConnectionStatus.connected;
    return _ConsoleCard(
      title: 'FINDER',
      subtitle: 'Verify a Finder JSON payload against the running app.',
      isProcessing: isProcessing,
      editor: _JsonEditor(
        automationKey: const ValueKey<String>('driver_automation.finder_input'),
        controller: _finderEditor,
        errorText: _finderError,
        statusText: _finderSchemaMessage,
      ),
      actions: [
        DevToolsButton(
          key: const ValueKey<String>('driver_automation.finder_schema_button'),
          onPressed:
              () => _openSchemaBrowser(
                context,
                kind: ProtocolSchemaKind.finder,
                editor: _finderEditor,
                clearError: (error) => _finderError = error,
                clearSchemaMessage: (message) => _finderSchemaMessage = message,
              ),
          icon: Icons.menu_book_outlined,
          label: 'Schemas',
        ),
        DevToolsButton(
          key: const ValueKey<String>('driver_automation.finder_format_button'),
          onPressed:
              () =>
                  _formatEditor(_finderEditor, (error) => _finderError = error),
          label: 'Format',
        ),
        DevToolsButton(
          key: const ValueKey<String>('driver_automation.finder_reset_button'),
          onPressed:
              () => _confirmReset(
                context,
                editor: _finderEditor,
                template: _session.finderResetTemplate,
                setError: (error) => _finderError = error,
              ),
          icon: Icons.restart_alt,
          label: 'Reset',
        ),
        DevToolsButton(
          key: const ValueKey<String>('driver_automation.finder_verify_button'),
          onPressed:
              isProcessing
                  ? () => _stopOperation(DriverOperationKind.finderVerify)
                  : canExecute
                  ? _verifyFinder
                  : null,
          icon: isProcessing ? Icons.stop : Icons.search,
          label: isProcessing ? 'Stop' : 'Verify',
          elevated: true,
          outlined: false,
        ),
      ],
      result: _finderResult,
    );
  }

  Widget _buildCommandConsole(BuildContext context) {
    final isProcessing = _busyOperations.contains(DriverOperationKind.command);
    final canExecute = _controller.status == DriverConnectionStatus.connected;
    return _ConsoleCard(
      title: 'COMMAND',
      subtitle: 'Execute a complete Flutter Driver command JSON payload.',
      isProcessing: isProcessing,
      editor: _JsonEditor(
        automationKey: const ValueKey<String>(
          'driver_automation.command_input',
        ),
        controller: _commandEditor,
        errorText: _commandError,
        statusText: _commandSchemaMessage,
      ),
      actions: [
        DevToolsButton(
          key: const ValueKey<String>(
            'driver_automation.command_schema_button',
          ),
          onPressed:
              () => _openSchemaBrowser(
                context,
                kind: ProtocolSchemaKind.command,
                editor: _commandEditor,
                clearError: (error) => _commandError = error,
                clearSchemaMessage:
                    (message) => _commandSchemaMessage = message,
              ),
          icon: Icons.menu_book_outlined,
          label: 'Schemas',
        ),
        DevToolsButton(
          key: const ValueKey<String>(
            'driver_automation.command_format_button',
          ),
          onPressed:
              () => _formatEditor(
                _commandEditor,
                (error) => _commandError = error,
              ),
          label: 'Format',
        ),
        DevToolsButton(
          key: const ValueKey<String>('driver_automation.command_reset_button'),
          onPressed:
              () => _confirmReset(
                context,
                editor: _commandEditor,
                template: _session.commandResetTemplate,
                setError: (error) => _commandError = error,
              ),
          icon: Icons.restart_alt,
          label: 'Reset',
        ),
        DevToolsButton(
          key: const ValueKey<String>(
            'driver_automation.command_execute_button',
          ),
          onPressed:
              isProcessing
                  ? () => _stopOperation(DriverOperationKind.command)
                  : canExecute
                  ? _executeCommand
                  : null,
          icon: isProcessing ? Icons.stop : Icons.play_arrow,
          label: isProcessing ? 'Stop' : 'Execute',
          elevated: true,
          outlined: false,
        ),
      ],
      result: _commandResult,
    );
  }

  Widget _buildRequestDataConsole(BuildContext context) {
    final isProcessing = _busyOperations.contains(
      DriverOperationKind.requestData,
    );
    final canExecute = _controller.status == DriverConnectionStatus.connected;
    return _ConsoleCard(
      title: 'REQUEST DATA',
      subtitle: 'Send a JSON object through Flutter Driver requestData.',
      isProcessing: isProcessing,
      editor: _JsonEditor(
        automationKey: const ValueKey<String>(
          'driver_automation.request_data_input',
        ),
        controller: _requestDataEditor,
        errorText: _requestDataError,
      ),
      actions: [
        DevToolsButton(
          key: const ValueKey<String>(
            'driver_automation.request_data_format_button',
          ),
          onPressed:
              () => _formatEditor(
                _requestDataEditor,
                (error) => _requestDataError = error,
              ),
          label: 'Format',
        ),
        DevToolsButton(
          key: const ValueKey<String>(
            'driver_automation.request_data_reset_button',
          ),
          onPressed:
              () => _confirmReset(
                context,
                editor: _requestDataEditor,
                template: JsonPayloads.defaultRequestData,
                setError: (error) => _requestDataError = error,
              ),
          icon: Icons.restart_alt,
          label: 'Reset',
        ),
        DevToolsButton(
          key: const ValueKey<String>(
            'driver_automation.request_data_send_button',
          ),
          onPressed:
              isProcessing
                  ? () => _stopOperation(DriverOperationKind.requestData)
                  : canExecute
                  ? _sendRequestData
                  : null,
          icon: isProcessing ? Icons.stop : Icons.send,
          label: isProcessing ? 'Stop' : 'Send',
          elevated: true,
          outlined: false,
        ),
      ],
      result: _requestDataResult,
    );
  }
}

class HistoryEntry {
  const HistoryEntry(this.result);

  final DriverExecutionResult result;

  String get label {
    switch (result.request.kind) {
      case DriverOperationKind.finderVerify:
        return 'Finder Verify';
      case DriverOperationKind.command:
        final command = result.request.args['command'];
        return command == null || command.isEmpty
            ? 'Command'
            : 'Command · $command';
      case DriverOperationKind.requestData:
        return 'RequestData';
    }
  }

  String get summary =>
      '${result.success ? 'Success' : 'Failed'} · '
      '${result.duration.inMilliseconds} ms';
}

class _ConnectionHeader extends StatelessWidget {
  const _ConnectionHeader({required this.status});

  final DriverConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      DriverConnectionStatus.connected => (
        'Connected · ext.flutter.driver',
        Colors.green,
        Icons.circle,
      ),
      DriverConnectionStatus.connecting => (
        'Connecting...',
        Colors.orange,
        Icons.sync,
      ),
      DriverConnectionStatus.unavailable => (
        'Driver unavailable',
        Colors.redAccent,
        Icons.circle_outlined,
      ),
      DriverConnectionStatus.reconnecting => (
        'Reconnecting...',
        Colors.orange,
        Icons.sync,
      ),
      DriverConnectionStatus.disconnected => (
        'Disconnected',
        Colors.grey,
        Icons.cancel_outlined,
      ),
    };

    return Padding(
      key: const ValueKey<String>('driver_automation.connection_status_label'),
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverUnavailableNotice extends StatelessWidget {
  const _DriverUnavailableNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Notice(
      icon: Icons.warning_amber_rounded,
      title: 'Driver unavailable',
      message:
          'Không tìm thấy ext.flutter.driver trên target isolate hiện tại.\n'
          'Hãy gọi enableFlutterDriverExtension() trong Flutter application.',
      onRetry: onRetry,
    );
  }
}

class _DriverDisconnectedNotice extends StatelessWidget {
  const _DriverDisconnectedNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Notice(
      icon: Icons.link_off,
      title: 'Disconnected',
      message: 'DevTools chưa kết nối tới VM Service của Flutter application.',
      onRetry: onRetry,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.errorContainer.withValues(alpha: .45),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(message),
                  const SizedBox(height: 10),
                  DevToolsButton(
                    key: const ValueKey<String>(
                      'driver_automation.connection_retry_button',
                    ),
                    icon: Icons.refresh,
                    label: 'Retry connection',
                    onPressed: onRetry,
                    elevated: true,
                    outlined: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsoleCard extends StatelessWidget {
  const _ConsoleCard({
    required this.title,
    required this.subtitle,
    required this.isProcessing,
    required this.editor,
    required this.actions,
    required this.result,
  });

  final String title;
  final String subtitle;
  final bool isProcessing;
  final Widget editor;
  final List<Widget> actions;
  final DriverExecutionResult? result;

  @override
  Widget build(BuildContext context) {
    return RoundedOutlinedBorder(
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AreaPaneHeader(
            title: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            roundedTopBorder: false,
            includeTopBorder: false,
            includeBottomBorder: true,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle, style: Theme.of(context).subtleTextStyle),
                const SizedBox(height: 12),
                if (isProcessing) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                ],
                editor,
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
                if (result != null) ...[
                  const SizedBox(height: 14),
                  _ResultPanel(result: result!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JsonEditor extends StatelessWidget {
  const _JsonEditor({
    required this.automationKey,
    required this.controller,
    this.errorText,
    this.statusText,
  });

  final Key automationKey;
  final JsonTextEditingController controller;
  final String? errorText;
  final String? statusText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: automationKey,
      controller: controller,
      minLines: 5,
      maxLines: 14,
      keyboardType: TextInputType.multiline,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        alignLabelWithHint: true,
        hintText: '{ ... }',
        errorText: errorText,
        helperText: statusText,
        helperStyle:
            statusText == null
                ? null
                : TextStyle(color: Theme.of(context).colorScheme.primary),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class JsonTextEditingController extends TextEditingController {
  JsonTextEditingController({super.text});

  static final _tokenPattern = RegExp(
    r'"(?:\\.|[^"\\])*"(?=\s*:)|"(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?|true|false|null',
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final children = <TextSpan>[];
    var cursor = 0;

    for (final match in _tokenPattern.allMatches(text)) {
      if (match.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      final isKey = match.end < text.length && text[match.end] == ':';
      final color =
          isKey
              ? Colors.lightBlueAccent
              : token.startsWith('"')
              ? Colors.lightGreenAccent
              : token == 'true' || token == 'false'
              ? Colors.orangeAccent
              : token == 'null'
              ? Colors.purpleAccent
              : Colors.amberAccent;
      children.add(
        TextSpan(text: token, style: baseStyle.copyWith(color: color)),
      );
      cursor = match.end;
    }

    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: baseStyle, children: children);
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result});

  final DriverExecutionResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = result.success ? Colors.green : colorScheme.error;
    final response =
        result.request.kind == DriverOperationKind.requestData &&
                result.response is Map<String, dynamic>
            ? (result.response as Map<String, dynamic>)['message']
            : result.response;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(Icons.data_object, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'RESULT',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                _ResultStatusChip(
                  label: result.success ? 'Success' : 'Failed',
                  duration: result.duration,
                  color: statusColor,
                  icon:
                      result.success ? Icons.check_circle : Icons.error_outline,
                ),
              ],
            ),
          ),
          if (result.success)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _ResultSection(
                label: 'Response',
                icon: Icons.output,
                child: _ResponseCodeBlock(
                  response == null
                      ? 'No response body returned.'
                      : JsonPayloads.displayResponse(response),
                  muted: response == null,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _ResultError(message: result.error ?? 'Unknown error'),
            ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: const Text('Raw details'),
            subtitle: const Text('Request and transport response'),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final request = _RawPayloadCard(
                    label: 'Raw request',
                    icon: Icons.call_made,
                    value: result.rawRequest,
                  );
                  final response = _RawPayloadCard(
                    label: 'Raw response',
                    icon: Icons.call_received,
                    value: result.rawResponse,
                  );
                  if (constraints.maxWidth >= 720) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: request),
                        const SizedBox(width: 12),
                        Expanded(child: response),
                      ],
                    );
                  }
                  return Column(
                    children: [request, const SizedBox(height: 12), response],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultStatusChip extends StatelessWidget {
  const _ResultStatusChip({
    required this.label,
    required this.duration,
    required this.color,
    required this.icon,
  });

  final String label;
  final Duration duration;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Text(
            '${duration.inMilliseconds} ms',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.label,
    required this.icon,
    required this.child,
  });

  final String label;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            _ResultLabel(label),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ResultError extends StatelessWidget {
  const _ResultError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: .45),
        border: Border.all(color: colorScheme.error.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request failed',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                _ResponseCodeBlock(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RawPayloadCard extends StatelessWidget {
  const _RawPayloadCard({
    required this.label,
    required this.icon,
    required this.value,
  });

  final String label;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: .35),
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ResponseCodeBlock(value, maxHeight: 190),
        ],
      ),
    );
  }
}

class _ResponseCodeBlock extends StatelessWidget {
  const _ResponseCodeBlock(
    this.text, {
    this.maxHeight = 180,
    this.muted = false,
  });

  final String text;
  final double maxHeight;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(5),
      ),
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText(
            text,
            style: TextStyle(
              color: muted ? colorScheme.onSurfaceVariant : null,
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultLabel extends StatelessWidget {
  const _ResultLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _ResponseText extends StatelessWidget {
  const _ResponseText(this.value);

  final Object value;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      JsonPayloads.displayResponse(value),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.entries, required this.onClear});

  final List<HistoryEntry> entries;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return RoundedOutlinedBorder(
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AreaPaneHeader(
            title: const Text('HISTORY'),
            roundedTopBorder: false,
            includeTopBorder: false,
            includeBottomBorder: true,
            actions: [
              DevToolsButton(
                key: const ValueKey<String>(
                  'driver_automation.history_clear_button',
                ),
                icon: Icons.delete_outline,
                label: 'Clear',
                tooltip: 'Clear session history',
                onPressed: entries.isEmpty ? null : onClear,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entries.isEmpty)
                  Text(
                    'No operations in this session.',
                    style: Theme.of(context).subtleTextStyle,
                  )
                else
                  for (final entry in entries) _HistoryTile(entry: entry),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final result = entry.result;
    final color =
        result.success ? Colors.green : Theme.of(context).colorScheme.error;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      leading: Icon(
        result.success ? Icons.check_circle : Icons.error,
        color: color,
        size: 18,
      ),
      title: Text(entry.label),
      subtitle: Text(entry.summary),
      children: [
        if (result.error != null) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: _ResultLabel('Error'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _ResponseText(result.error!),
          ),
          const SizedBox(height: 8),
        ],
        const Align(
          alignment: Alignment.centerLeft,
          child: _ResultLabel('Input'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: _ResponseText(result.request.rawInput),
        ),
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerLeft,
          child: _ResultLabel('Raw Request'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: _ResponseText(result.rawRequest),
        ),
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerLeft,
          child: _ResultLabel('Raw Response'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: _ResponseText(result.rawResponse),
        ),
      ],
    );
  }
}
