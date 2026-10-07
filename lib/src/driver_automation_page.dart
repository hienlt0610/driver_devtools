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

class DriverAutomationPage extends StatefulWidget {
  const DriverAutomationPage({super.key, this.transport, this.schemaRegistry});

  final DriverTransport? transport;
  final ProtocolSchemaRegistry? schemaRegistry;

  @override
  State<DriverAutomationPage> createState() => _DriverAutomationPageState();
}

class _DriverAutomationPageState extends State<DriverAutomationPage>
    with AutoDisposeMixin {
  ProtocolSchemaRegistry get _schemaRegistry =>
      widget.schemaRegistry ?? ProtocolSchemaRegistry.builtIn;

  late final DriverAutomationController _controller;
  late final DriverTransport _transport;
  DriverAutomationService? _service;
  late final JsonTextEditingController _finderEditor;
  late final JsonTextEditingController _commandEditor;
  late final JsonTextEditingController _requestDataEditor;

  DriverExecutionResult? _finderResult;
  DriverExecutionResult? _commandResult;
  DriverExecutionResult? _requestDataResult;
  final _history = <HistoryEntry>[];
  final _busyOperations = <DriverOperationKind>{};
  String? _finderError;
  String? _commandError;
  String? _requestDataError;
  String? _finderSchemaMessage;
  String? _commandSchemaMessage;

  @override
  void initState() {
    super.initState();
    if (widget.transport == null) {
      _service = DriverAutomationService(serviceManager);
    }
    _transport = widget.transport ?? _service!;
    _controller = DriverAutomationController(_transport)
      ..addListener(_onControllerChanged);
    _finderEditor = JsonTextEditingController(text: JsonPayloads.defaultFinder);
    _commandEditor = JsonTextEditingController(
      text: JsonPayloads.defaultCommand,
    );
    _requestDataEditor = JsonTextEditingController(
      text: JsonPayloads.defaultRequestData,
    );

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
    setState(() => _busyOperations.add(request.kind));
    try {
      final result = await _controller.execute(request);
      if (!mounted) return;
      setState(() {
        onResult(result);
        _history.insert(0, HistoryEntry(result));
        if (_history.length > 50) _history.removeLast();
      });
    } finally {
      if (mounted) {
        setState(() => _busyOperations.remove(request.kind));
      }
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
                child: Column(
                  children: [
                    AreaPaneHeader(
                      title: const Text('Driver Automation'),
                      includeLeftBorder: true,
                      includeRightBorder: true,
                      actions: [_ConnectionHeader(status: _controller.status)],
                    ),
                    const TabBar(
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
              () => _resetEditor(
                _finderEditor,
                JsonPayloads.defaultFinder,
                (error) => _finderError = error,
              ),
          icon: Icons.restart_alt,
          label: 'Reset',
        ),
        DevToolsButton(
          key: const ValueKey<String>('driver_automation.finder_verify_button'),
          onPressed: !canExecute || isProcessing ? null : _verifyFinder,
          icon: Icons.search,
          label: isProcessing ? 'Verifying...' : 'Verify',
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
              () => _resetEditor(
                _commandEditor,
                JsonPayloads.defaultCommand,
                (error) => _commandError = error,
              ),
          icon: Icons.restart_alt,
          label: 'Reset',
        ),
        DevToolsButton(
          key: const ValueKey<String>(
            'driver_automation.command_execute_button',
          ),
          onPressed: !canExecute || isProcessing ? null : _executeCommand,
          icon: Icons.play_arrow,
          label: isProcessing ? 'Executing...' : 'Execute',
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
              () => _resetEditor(
                _requestDataEditor,
                JsonPayloads.defaultRequestData,
                (error) => _requestDataError = error,
              ),
          icon: Icons.restart_alt,
          label: 'Reset',
        ),
        DevToolsButton(
          key: const ValueKey<String>(
            'driver_automation.request_data_send_button',
          ),
          onPressed: !canExecute || isProcessing ? null : _sendRequestData,
          icon: Icons.send,
          label: isProcessing ? 'Sending...' : 'Send',
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
    final successColor =
        result.success ? Colors.green : Theme.of(context).colorScheme.error;
    final response =
        result.request.kind == DriverOperationKind.requestData &&
                result.response is Map<String, dynamic>
            ? (result.response as Map<String, dynamic>)['message']
            : result.response;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'RESULT',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                size: 17,
                color: successColor,
              ),
              const SizedBox(width: 5),
              Text(
                result.success ? 'Success' : 'Failed',
                style: TextStyle(
                  color: successColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${result.duration.inMilliseconds} ms',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (result.success && response != null) ...[
            const SizedBox(height: 10),
            const _ResultLabel('Response'),
            _ResponseText(response),
          ],
          if (!result.success) ...[
            const SizedBox(height: 10),
            const _ResultLabel('Error'),
            _ResponseText(result.error ?? 'Unknown error'),
          ],
          const SizedBox(height: 4),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('Raw details'),
            children: [
              const _ResultLabel('Raw Request'),
              _ResponseText(result.rawRequest),
              const SizedBox(height: 8),
              const _ResultLabel('Raw Response'),
              _ResponseText(result.rawResponse),
            ],
          ),
        ],
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
      subtitle: Text(
        '${result.duration.inMilliseconds} ms${result.error == null ? '' : ' · ${result.error}'}',
      ),
      children: [
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
