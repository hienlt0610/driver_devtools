import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'driver_automation_core.dart';
import 'driver_automation_service.dart';
import 'element_explorer_model.dart';
import 'element_explorer_widgets.dart';
import 'finder_dsl.dart';
import 'finder_completion.dart';
import 'finder_editor.dart';
import 'java_finder_generator.dart';
import 'protocol/schema/protocol_schema.dart';
import 'protocol/schema/protocol_schema_registry.dart';
import 'protocol/schema/schema_browser.dart';

class DriverAutomationSession {
  DriverAutomationSession()
    : finderText = JsonPayloads.defaultFinder,
      finderDslText = 'key("login_button")',
      finderMode = FinderEditorMode.dsl,
      commandText = JsonPayloads.defaultCommand,
      requestDataText = JsonPayloads.defaultRequestData,
      elementExplorerFinderText = JsonPayloads.defaultFinder,
      finderResetTemplate = JsonPayloads.defaultFinder,
      commandResetTemplate = JsonPayloads.defaultCommand,
      elementExplorerFinderResetTemplate = JsonPayloads.defaultFinder,
      elementExplorerAncestorDepthText = '3',
      elementExplorerDescendantDepthText = '1',
      elementExplorerSiblingDepthText = '0',
      elementExplorerMaxNodesText = '200',
      elementExplorerIncludeSiblings = true;

  String finderText;
  String finderDslText;
  FinderEditorMode finderMode;
  Map<String, dynamic>? finderCanonical;
  String commandText;
  String requestDataText;
  String elementExplorerFinderText;
  String finderResetTemplate;
  String commandResetTemplate;
  String elementExplorerFinderResetTemplate;
  String elementExplorerAncestorDepthText;
  String elementExplorerDescendantDepthText;
  String elementExplorerSiblingDepthText;
  String elementExplorerMaxNodesText;
  bool elementExplorerIncludeSiblings;
  String? elementExplorerAppliedFinder;
  Map<String, String>? elementExplorerAppliedOptions;
  bool elementExplorerEditorExpanded = true;
  bool elementExplorerOptionsExpanded = false;
  DriverExecutionResult? finderResult;
  DriverExecutionResult? commandResult;
  DriverExecutionResult? requestDataResult;
  DriverExecutionResult? elementExplorerResult;
  ElementExplorerSnapshot? elementExplorerSnapshot;
  int? elementExplorerReturnedNodes;
  int? elementExplorerVisitedNodes;
  bool elementExplorerTruncated = false;
  final history = <HistoryEntry>[];
  String? finderError;
  String? commandError;
  String? requestDataError;
  String? elementExplorerError;
  String? elementExplorerSchemaMessage;
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
  late final FinderEditorState _finderState;
  late final FinderTextEditingController _finderEditor;
  late final JsonTextEditingController _commandEditor;
  late final JsonTextEditingController _requestDataEditor;
  late final JsonTextEditingController _elementExplorerFinderEditor;
  late final TextEditingController _elementExplorerAncestorDepthEditor;
  late final TextEditingController _elementExplorerDescendantDepthEditor;
  late final TextEditingController _elementExplorerSiblingDepthEditor;
  late final TextEditingController _elementExplorerMaxNodesEditor;
  bool _updatingFinderEditors = false;

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

  String? get _elementExplorerError => _session.elementExplorerError;
  set _elementExplorerError(String? value) {
    _session.elementExplorerError = value;
  }

  String? get _elementExplorerSchemaMessage =>
      _session.elementExplorerSchemaMessage;
  set _elementExplorerSchemaMessage(String? value) {
    _session.elementExplorerSchemaMessage = value;
  }

  String? get _finderSchemaMessage => _session.finderSchemaMessage;
  set _finderSchemaMessage(String? value) {
    _session.finderSchemaMessage = value;
  }

  void _logFinderSync(
    String source,
    String event, {
    String regeneration = 'notAttempted',
    String controllerUpdate = 'notAttempted',
    String? skipReason,
  }) {
    finderSyncLog(
      '$source $event '
      'activeMode=${_finderState.mode.name} '
      'dslValid=${_finderState.dslDraftIsValid} '
      'jsonValid=${_finderState.jsonDraftIsValid} '
      'dslDirty=${_finderState.dslDraftIsDirty} '
      'jsonDirty=${_finderState.jsonDraftIsDirty} '
      'canonicalRevision=${_finderState.canonicalRevision} '
      'sotCommitted=${_finderState.canonical != null} '
      'regeneration=$regeneration '
      'controllerTextUpdated=$controllerUpdate '
      'regenerationSkipped=${skipReason != null} '
      '${skipReason == null ? '' : 'reason=$skipReason'}',
    );
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
    _finderState = FinderEditorState(
      initialJson: _session.finderText,
      initialCanonical: _session.finderCanonical,
      registry: _schemaRegistry,
    );
    if (_session.finderDslText != _finderState.dslText) {
      _finderState.updateDsl(_session.finderDslText);
    }
    _finderState.setMode(_session.finderMode);
    _finderEditor = FinderTextEditingController(
      text:
          _finderState.mode == FinderEditorMode.dsl
              ? _finderState.dslText
              : _finderState.jsonText,
      mode: _finderState.mode,
    )..addListener(_onFinderChanged);
    _commandEditor = JsonTextEditingController(text: _session.commandText)
      ..addListener(() => _session.commandText = _commandEditor.text);
    _requestDataEditor = JsonTextEditingController(
      text: _session.requestDataText,
    )..addListener(() => _session.requestDataText = _requestDataEditor.text);
    _elementExplorerFinderEditor = JsonTextEditingController(
      text: _session.elementExplorerFinderText,
    )..addListener(_onElementExplorerDraftChanged);
    _elementExplorerAncestorDepthEditor = TextEditingController(
      text: _session.elementExplorerAncestorDepthText,
    )..addListener(_onElementExplorerDraftChanged);
    _elementExplorerDescendantDepthEditor = TextEditingController(
      text: _session.elementExplorerDescendantDepthText,
    )..addListener(_onElementExplorerDraftChanged);
    _elementExplorerSiblingDepthEditor = TextEditingController(
      text: _session.elementExplorerSiblingDepthText,
    )..addListener(_onElementExplorerDraftChanged);
    _elementExplorerMaxNodesEditor = TextEditingController(
      text: _session.elementExplorerMaxNodesText,
    )..addListener(_onElementExplorerDraftChanged);

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
    _elementExplorerFinderEditor.dispose();
    _elementExplorerAncestorDepthEditor.dispose();
    _elementExplorerDescendantDepthEditor.dispose();
    _elementExplorerSiblingDepthEditor.dispose();
    _elementExplorerMaxNodesEditor.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onElementExplorerDraftChanged() {
    _session.elementExplorerFinderText = _elementExplorerFinderEditor.text;
    _session.elementExplorerAncestorDepthText =
        _elementExplorerAncestorDepthEditor.text;
    _session.elementExplorerDescendantDepthText =
        _elementExplorerDescendantDepthEditor.text;
    _session.elementExplorerSiblingDepthText =
        _elementExplorerSiblingDepthEditor.text;
    _session.elementExplorerMaxNodesText = _elementExplorerMaxNodesEditor.text;
    if (mounted) setState(() {});
  }

  void _onFinderChanged() {
    if (_updatingFinderEditors) {
      _logFinderSync(
        _finderState.mode.name,
        'controllerUpdate',
        controllerUpdate: 'skipped',
        skipReason: 'synchronizationGuard',
      );
      return;
    }
    final text = _finderEditor.text;
    final source = _finderState.mode.name;
    _logFinderSync(source, 'userEdit', controllerUpdate: 'byUserInput');
    // Keep old JSON paste workflows working while the preferred mode is DSL.
    if (_finderState.mode == FinderEditorMode.dsl &&
        text.trimLeft().startsWith('{')) {
      _finderState.setMode(FinderEditorMode.json);
      _finderEditor.mode = FinderEditorMode.json;
      _finderState.updateJson(text);
    } else if (_finderState.mode == FinderEditorMode.dsl) {
      _finderState.updateDsl(text);
    } else {
      _finderState.updateJson(text);
    }
    _syncFinderSession();
    _logFinderSync(source, 'stateNotification', regeneration: 'stateHandled');
    if (mounted) setState(() {});
  }

  void _syncFinderSession() {
    _session.finderMode = _finderState.mode;
    _session.finderDslText = _finderState.dslText;
    _session.finderText = _finderState.jsonText;
    _session.finderCanonical = _finderState.canonical;
    _session.finderError =
        _finderState.mode == FinderEditorMode.dsl
            ? _finderState.dslError ?? _finderState.dslMessage
            : _finderState.jsonError;
    _session.finderSchemaMessage =
        _finderState.mode == FinderEditorMode.dsl
            ? null
            : _finderState.jsonMessage;
    _logFinderSync('state', 'notification');
  }

  void _setFinderMode(FinderEditorMode mode) {
    if (_finderState.mode == mode) {
      _logFinderSync(
        mode.name,
        'modeSwitch',
        controllerUpdate: 'skipped',
        skipReason: 'alreadyActive',
      );
      return;
    }
    _updatingFinderEditors = true;
    _finderState.setMode(mode);
    final text =
        mode == FinderEditorMode.dsl
            ? _finderState.dslText
            : _finderState.jsonText;
    _finderEditor.mode = mode;
    _finderEditor.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
    _updatingFinderEditors = false;
    _syncFinderSession();
    _logFinderSync(mode.name, 'modeSwitch', controllerUpdate: 'updated');
    setState(() {});
  }

  void _setFinderCanonical(Map<String, dynamic> canonical) {
    _updatingFinderEditors = true;
    _finderState.loadCanonical(canonical);
    final text =
        _finderState.mode == FinderEditorMode.dsl
            ? _finderState.dslText
            : _finderState.jsonText;
    _finderEditor.mode = _finderState.mode;
    _finderEditor.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
    _updatingFinderEditors = false;
    _syncFinderSession();
    _logFinderSync(
      _finderState.mode.name,
      'programmaticUpdate',
      regeneration: 'stateHandled',
      controllerUpdate: 'updated',
    );
  }

  Map<String, dynamic>? _resolveFinderDraft() {
    _logFinderSync(
      _finderState.mode.name,
      'validation',
      controllerUpdate: 'skipped',
      skipReason: 'programmaticResolveGuard',
    );
    _updatingFinderEditors = true;
    if (_finderState.mode == FinderEditorMode.dsl &&
        _finderEditor.text.trimLeft().startsWith('{')) {
      _finderState.setMode(FinderEditorMode.json);
      _finderEditor.mode = FinderEditorMode.json;
      _finderState.updateJson(_finderEditor.text);
    } else if (_finderState.mode == FinderEditorMode.dsl) {
      _finderState.updateDsl(_finderEditor.text);
    } else {
      _finderState.updateJson(_finderEditor.text);
    }
    _updatingFinderEditors = false;
    _syncFinderSession();
    if (!_finderState.activeDraftIsValid) {
      setState(() {});
      return null;
    }
    return _finderState.canonical;
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
    final canonical = _resolveFinderDraft();
    if (canonical == null) return;
    final source = _finderEditor.text;
    final request = JsonPayloads.finderVerificationFromCanonical(
      canonical,
      rawInput: source,
    );
    await _execute(request, onResult: (result) => _finderResult = result);
  }

  void _generateJavaFinder(BuildContext context) {
    final canonical = _resolveFinderDraft();
    if (canonical == null) return;

    try {
      final code = JavaFinderGenerator.generate(canonical);
      setState(() => _finderError = null);
      showDialog<void>(
        context: context,
        builder: (_) => _JavaFinderDialog(code: code),
      );
    } on JavaFinderGenerationException catch (error) {
      setState(() => _finderError = error.toString());
    }
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

  Map<String, String>? _elementExplorerOptions() {
    final options = _elementExplorerOptionsDraft();
    final integerFields = <String, int>{};
    for (final name in <String>[
      'ancestorDepth',
      'descendantDepth',
      'siblingDepth',
      'maxNodes',
    ]) {
      final value = int.tryParse(options[name]!);
      if (value == null) {
        _elementExplorerError = '$name must be an integer.';
        return null;
      }
      integerFields[name] = value;
    }
    for (final name in <String>[
      'ancestorDepth',
      'descendantDepth',
      'siblingDepth',
    ]) {
      final value = integerFields[name]!;
      if (value < 0 || value > 32) {
        _elementExplorerError = '$name must be between 0 and 32.';
        return null;
      }
    }
    final maxNodes = integerFields['maxNodes']!;
    if (maxNodes < 1 || maxNodes > 2000) {
      _elementExplorerError = 'maxNodes must be between 1 and 2000.';
      return null;
    }
    return options;
  }

  Map<String, String> _elementExplorerOptionsDraft() {
    return <String, String>{
      'ancestorDepth': _elementExplorerAncestorDepthEditor.text,
      'descendantDepth': _elementExplorerDescendantDepthEditor.text,
      'includeSiblings': _session.elementExplorerIncludeSiblings.toString(),
      'siblingDepth': _elementExplorerSiblingDepthEditor.text,
      'maxNodes': _elementExplorerMaxNodesEditor.text,
    };
  }

  String? _elementExplorerFinderDraftKey() {
    try {
      return const JsonEncoder.withIndent(
        '  ',
      ).convert(JsonPayloads.parseObject(_elementExplorerFinderEditor.text));
    } on JsonPayloadException {
      return null;
    }
  }

  bool _elementExplorerOptionsMatch(
    Map<String, String> left,
    Map<String, String> right,
  ) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }

  bool get _elementExplorerHasPendingChanges {
    if (_session.elementExplorerSnapshot == null) return false;
    final appliedFinder = _session.elementExplorerAppliedFinder;
    final appliedOptions = _session.elementExplorerAppliedOptions;
    if (appliedFinder == null || appliedOptions == null) return true;
    return _elementExplorerFinderDraftKey() != appliedFinder ||
        !_elementExplorerOptionsMatch(
          _elementExplorerOptionsDraft(),
          appliedOptions,
        );
  }

  Future<void> _inspectElementExplorer() async {
    if (_busyOperations.contains(DriverOperationKind.elementExplorer)) return;
    Map<String, dynamic> finder;
    try {
      finder = JsonPayloads.parseObject(_elementExplorerFinderEditor.text);
    } on JsonPayloadException catch (error) {
      setState(() {
        _elementExplorerError =
            'Invalid or incomplete JSON\n'
            '${error.message}\nLine ${error.line}, Column ${error.column}';
        _elementExplorerSchemaMessage = null;
      });
      return;
    }

    final schemaResult = _schemaRegistry.validateFinderPayload(finder);
    final options = _elementExplorerOptions();
    if (!schemaResult.isValid || options == null) {
      setState(() {
        _elementExplorerSchemaMessage =
            schemaResult.messages.isEmpty
                ? null
                : schemaResult.messages.join('\n');
        if (!schemaResult.isValid) {
          _elementExplorerError = schemaResult.errors.join('\n');
        }
      });
      return;
    }

    final request = JsonPayloads.elementExplorerFromCanonical(
      finder,
      options: options,
      rawInput: _elementExplorerFinderEditor.text,
    );
    setState(() {
      _elementExplorerError = null;
      _elementExplorerSchemaMessage =
          schemaResult.messages.isEmpty
              ? null
              : schemaResult.messages.join('\n');
      _session.elementExplorerResult = null;
    });
    await _execute(
      request,
      onResult: (result) {
        _session.elementExplorerResult = result;
        if (!result.success) {
          _elementExplorerError =
              result.error ?? 'Element Explorer request failed.';
          return;
        }
        try {
          final parsed = ElementExplorerResponse.parse(result.response);
          if (parsed.error != null) {
            _elementExplorerError =
                '${parsed.error!.code}: ${parsed.error!.message}';
          } else {
            _elementExplorerError = null;
            _session.elementExplorerSnapshot = parsed.snapshot;
            _session.elementExplorerReturnedNodes = parsed.returnedNodes;
            _session.elementExplorerVisitedNodes = parsed.visitedNodes;
            _session.elementExplorerTruncated = parsed.truncated;
            _session.elementExplorerAppliedFinder =
                const JsonEncoder.withIndent('  ').convert(finder);
            _session.elementExplorerAppliedOptions = Map<String, String>.from(
              options,
            );
            _session.elementExplorerEditorExpanded = false;
          }
        } on ElementExplorerResponseException catch (error) {
          _elementExplorerError = 'INSPECTION_FAILED: $error';
        }
      },
    );
  }

  void _loadFinderIntoElementExplorer() {
    final canonical = _resolveFinderDraft();
    if (canonical == null) return;
    final formatted = const JsonEncoder.withIndent('  ').convert(canonical);
    _elementExplorerFinderEditor.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
    setState(() {
      _elementExplorerError = null;
      _elementExplorerSchemaMessage = null;
    });
  }

  void _formatElementExplorerFinder() {
    _formatEditor(
      _elementExplorerFinderEditor,
      (error) => _elementExplorerError = error,
    );
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

  void _openFinderSchemaBrowser(BuildContext context) {
    showDialog<void>(
      context: context,
      builder:
          (context) => SchemaBrowserDialog(
            kind: ProtocolSchemaKind.finder,
            registry: _schemaRegistry,
            onUseExample: (example) {
              final canonical = JsonPayloads.parseObject(example);
              setState(() {
                _session.finderResetTemplate = example;
                _setFinderCanonical(canonical);
                _finderError = null;
                _finderSchemaMessage = null;
              });
            },
          ),
    );
  }

  Future<void> _execute(
    DriverRequest request, {
    required void Function(DriverExecutionResult result) onResult,
  }) async {
    if (_busyOperations.contains(request.kind)) return;
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

  void _formatFinder() {
    if (_finderState.mode == FinderEditorMode.dsl &&
        _finderEditor.text.trimLeft().startsWith('{')) {
      _updatingFinderEditors = true;
      _finderState.setMode(FinderEditorMode.json);
      _finderEditor.mode = FinderEditorMode.json;
      _finderState.updateJson(_finderEditor.text);
      _updatingFinderEditors = false;
    }
    if (_finderState.mode == FinderEditorMode.json) {
      try {
        final formatted = JsonPayloads.format(_finderEditor.text);
        _updatingFinderEditors = true;
        _finderState.updateJson(formatted);
        _finderEditor.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
          composing: TextRange.empty,
        );
        _updatingFinderEditors = false;
        _syncFinderSession();
        setState(() {});
      } on JsonPayloadException catch (error) {
        setState(
          () =>
              _finderError =
                  '${error.message}\nLine ${error.line}, Column ${error.column}',
        );
      }
      return;
    }
    final canonical = _resolveFinderDraft();
    if (canonical == null) return;
    try {
      final formatted = FinderDslGenerator.generateCanonical(
        canonical,
        registry: _schemaRegistry,
      );
      _updatingFinderEditors = true;
      if (_finderState.mode == FinderEditorMode.dsl) {
        _finderState.updateDsl(formatted);
      }
      _finderEditor.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
        composing: TextRange.empty,
      );
      _updatingFinderEditors = false;
      _syncFinderSession();
      setState(() {});
    } on JsonPayloadException catch (error) {
      setState(
        () =>
            _finderError =
                '${error.message}\nLine ${error.line}, Column ${error.column}',
      );
    } on FinderDslException catch (error) {
      setState(() => _finderError = error.toString());
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

  Future<void> _confirmFinderReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset editor?'),
          content: const Text(
            'This will replace the current finder with the reset template.',
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
    try {
      _setFinderCanonical(
        JsonPayloads.parseObject(_session.finderResetTemplate),
      );
      setState(() {
        _finderError = null;
        _finderSchemaMessage = null;
      });
    } on JsonPayloadException catch (error) {
      setState(
        () =>
            _finderError =
                '${error.message}\nLine ${error.line}, Column ${error.column}',
      );
    }
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
              child: Material(
                child: DefaultTabController(
                  length: 4,
                  animationDuration: Duration.zero,
                  initialIndex: _session.selectedTabIndex,
                  child: Column(
                    children: [
                      AreaPaneHeader(
                        title: const Text('Driver Automation'),
                        includeLeftBorder: true,
                        includeRightBorder: true,
                        actions: [
                          _ConnectionHeader(
                            status: _controller.status,
                            compact: constraints.maxWidth < 560,
                          ),
                          DevToolsButton(
                            key: const ValueKey<String>(
                              'driver_automation.history_clear_button',
                            ),
                            icon: Icons.delete_outline,
                            tooltip: 'Clear session history',
                            onPressed: _history.isEmpty ? null : _clearHistory,
                          ),
                        ],
                      ),
                      TabBar(
                        onTap: (index) => _session.selectedTabIndex = index,
                        tabs: [
                          Tab(
                            key: ValueKey<String>(
                              'driver_automation.finder_tab',
                            ),
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
                          Tab(
                            key: ValueKey<String>(
                              'driver_automation.element_explorer_tab',
                            ),
                            text: 'ELEMENT EXPLORER',
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
                            _buildTabContent(
                              _buildElementExplorerConsole(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabContent(Widget console) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          console,
          const SizedBox(height: 8),
          _HistoryPanel(entries: _history),
        ],
      ),
    );
  }

  void _insertFinderSuggestion(
    FinderCompletionContext context,
    FinderCompletionItem item,
  ) {
    final current = _finderEditor.value;
    final edit = context.apply(item, current.text);
    _finderEditor.value = TextEditingValue(
      text: edit.text,
      selection: TextSelection.collapsed(offset: edit.selectionOffset),
      composing: TextRange.empty,
    );
  }

  Widget _buildFinderConsole(BuildContext context) {
    final isProcessing = _busyOperations.contains(
      DriverOperationKind.finderVerify,
    );
    final canExecute = _controller.status == DriverConnectionStatus.connected;
    return _ConsoleCard(
      title: 'Finder',
      headerActions: [
        DevToolsButton(
          key: const ValueKey<String>('driver_automation.finder_schema_button'),
          onPressed: () => _openFinderSchemaBrowser(context),
          icon: Icons.menu_book_outlined,
          label: 'Schemas',
        ),
      ],
      isProcessing: isProcessing,
      editor: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FinderModeToggle(mode: _finderState.mode, onChanged: _setFinderMode),
          const SizedBox(height: 6),
          _FinderEditor(
            mode: _finderState.mode,
            controller: _finderEditor,
            errorText: _finderError,
            statusText: _finderSchemaMessage,
            onSuggestion: _insertFinderSuggestion,
          ),
        ],
      ),
      actions: [
        DevToolsButton(
          key: const ValueKey<String>('driver_automation.finder_format_button'),
          onPressed: _formatFinder,
          label: 'Format',
        ),
        DevToolsButton(
          key: const ValueKey<String>(
            'driver_automation.finder_generate_java_button',
          ),
          onPressed: () => _generateJavaFinder(context),
          icon: Icons.code,
          label: 'Generate Java',
        ),
        DevToolsButton(
          key: const ValueKey<String>('driver_automation.finder_reset_button'),
          onPressed: () => _confirmFinderReset(context),
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
      subtitle: 'Send an object through Flutter Driver requestData.',
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

  String _elementExplorerFinderSummary() {
    final text = _elementExplorerFinderEditor.text.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    return text.isEmpty ? 'Enter a Finder JSON payload' : text;
  }

  String _elementExplorerOptionsSummary([Map<String, String>? options]) {
    final values = options ?? _elementExplorerOptionsDraft();
    final siblings = values['includeSiblings'] == 'true' ? 'on' : 'off';
    return 'Ancestors ${values['ancestorDepth']} · '
        'Descendants ${values['descendantDepth']} · '
        'Siblings $siblings · '
        'Max ${values['maxNodes']}';
  }

  Widget _buildElementExplorerInspectButton({
    required bool isProcessing,
    required bool canExecute,
  }) {
    final hasSnapshot = _session.elementExplorerSnapshot != null;
    final label =
        isProcessing
            ? 'Stop'
            : hasSnapshot && _elementExplorerHasPendingChanges
            ? 'Apply & Reinspect'
            : hasSnapshot
            ? 'Reinspect'
            : 'Inspect';
    return DevToolsButton(
      key: const ValueKey<String>(
        'driver_automation.element_explorer_inspect_button',
      ),
      onPressed:
          isProcessing
              ? () => _stopOperation(DriverOperationKind.elementExplorer)
              : canExecute
              ? _inspectElementExplorer
              : null,
      icon: isProcessing ? Icons.stop : Icons.search,
      label: label,
      elevated: true,
      outlined: false,
    );
  }

  Widget _buildElementExplorerConsole(BuildContext context) {
    final isProcessing = _busyOperations.contains(
      DriverOperationKind.elementExplorer,
    );
    final canExecute = _controller.status == DriverConnectionStatus.connected;
    final snapshot = _session.elementExplorerSnapshot;
    final editorExpanded =
        _session.elementExplorerEditorExpanded || snapshot == null;
    final optionsExpanded = _session.elementExplorerOptionsExpanded;
    return RoundedOutlinedBorder(
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AreaPaneHeader(
            title: Text(
              'ELEMENT EXPLORER',
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
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isProcessing) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                ],
                if (editorExpanded) ...[
                  Text(
                    'Finder input',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  _JsonEditor(
                    automationKey: const ValueKey<String>(
                      'driver_automation.element_explorer_finder_input',
                    ),
                    controller: _elementExplorerFinderEditor,
                    errorText: _elementExplorerError,
                    statusText: _elementExplorerSchemaMessage,
                  ),
                  const SizedBox(height: 8),
                  _ActionToolbar(
                    actions: [
                      DevToolsButton(
                        key: const ValueKey<String>(
                          'driver_automation.element_explorer_load_finder_button',
                        ),
                        onPressed: _loadFinderIntoElementExplorer,
                        icon: Icons.input,
                        label: 'Load from Finder',
                      ),
                      DevToolsButton(
                        key: const ValueKey<String>(
                          'driver_automation.element_explorer_format_button',
                        ),
                        onPressed: _formatElementExplorerFinder,
                        label: 'Format',
                      ),
                      DevToolsButton(
                        key: const ValueKey<String>(
                          'driver_automation.element_explorer_reset_button',
                        ),
                        onPressed:
                            () => _confirmReset(
                              context,
                              editor: _elementExplorerFinderEditor,
                              template:
                                  _session.elementExplorerFinderResetTemplate,
                              setError:
                                  (error) => _elementExplorerError = error,
                            ),
                        icon: Icons.restart_alt,
                        label: 'Reset',
                      ),
                      _buildElementExplorerInspectButton(
                        isProcessing: isProcessing,
                        canExecute: canExecute,
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Icon(Icons.filter_alt_outlined, size: 16),
                      const SizedBox(width: denseSpacing),
                      Expanded(
                        child: Text(
                          _elementExplorerFinderSummary(),
                          key: const ValueKey<String>(
                            'driver_automation.element_explorer_finder_summary',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildElementExplorerInspectButton(
                        isProcessing: isProcessing,
                        canExecute: canExecute,
                      ),
                      DevToolsButton(
                        key: const ValueKey<String>(
                          'driver_automation.element_explorer_edit_finder_button',
                        ),
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        tooltip: 'Edit Finder',
                        onPressed:
                            () => setState(
                              () =>
                                  _session.elementExplorerEditorExpanded = true,
                            ),
                        outlined: false,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              _elementExplorerOptionsSummary(
                                snapshot == null
                                    ? null
                                    : _session.elementExplorerAppliedOptions,
                              ),
                              style: Theme.of(context).subtleTextStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_elementExplorerHasPendingChanges) ...[
                            const SizedBox(width: denseSpacing),
                            Text(
                              'Pending changes',
                              key: const ValueKey<String>(
                                'driver_automation.element_explorer_pending_changes',
                              ),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    DevToolsButton(
                      key: const ValueKey<String>(
                        'driver_automation.element_explorer_options_button',
                      ),
                      icon:
                          optionsExpanded
                              ? Icons.expand_less
                              : Icons.tune_outlined,
                      label: optionsExpanded ? 'Hide options' : 'Options',
                      tooltip: 'Inspection options',
                      onPressed:
                          () => setState(
                            () =>
                                _session.elementExplorerOptionsExpanded =
                                    !optionsExpanded,
                          ),
                      outlined: false,
                    ),
                  ],
                ),
                if (!editorExpanded && _elementExplorerError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _elementExplorerError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (optionsExpanded) ...[
                  const SizedBox(height: 6),
                  ElementExplorerOptionsEditor(
                    ancestorDepthController:
                        _elementExplorerAncestorDepthEditor,
                    descendantDepthController:
                        _elementExplorerDescendantDepthEditor,
                    siblingDepthController: _elementExplorerSiblingDepthEditor,
                    maxNodesController: _elementExplorerMaxNodesEditor,
                    includeSiblings: _session.elementExplorerIncludeSiblings,
                    onIncludeSiblingsChanged: (value) {
                      setState(
                        () => _session.elementExplorerIncludeSiblings = value,
                      );
                    },
                  ),
                ],
                if (snapshot != null) ...[
                  const SizedBox(height: 12),
                  ElementExplorerViewer(
                    snapshot: snapshot,
                    truncated: _session.elementExplorerTruncated,
                    returnedNodes: _session.elementExplorerReturnedNodes ?? 0,
                    visitedNodes: _session.elementExplorerVisitedNodes ?? 0,
                  ),
                ] else if (!isProcessing && _elementExplorerError == null)
                  Container(
                    key: const ValueKey<String>(
                      'driver_automation.element_explorer_empty',
                    ),
                    padding: const EdgeInsets.all(defaultSpacing),
                    child: Text(
                      'Enter a Finder and press Inspect to capture an Element '
                      'Tree snapshot.',
                      style: Theme.of(context).subtleTextStyle,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
      case DriverOperationKind.elementExplorer:
        return 'Element Explorer';
    }
  }

  String get summary =>
      '${result.success ? 'Success' : 'Failed'} · '
      '${result.duration.inMilliseconds} ms';
}

class _ConnectionHeader extends StatelessWidget {
  const _ConnectionHeader({required this.status, required this.compact});

  final DriverConnectionStatus status;
  final bool compact;

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

    return Tooltip(
      message: label,
      child: Padding(
        key: const ValueKey<String>(
          'driver_automation.connection_status_label',
        ),
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 7),
            Text(
              compact ? label.split(' · ').first : label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
    this.subtitle,
    this.headerActions = const [],
    required this.isProcessing,
    required this.editor,
    required this.actions,
    required this.result,
  });

  final String title;
  final String? subtitle;
  final List<Widget> headerActions;
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
            actions: headerActions,
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null) ...[
                  Text(subtitle!, style: Theme.of(context).subtleTextStyle),
                  const SizedBox(height: 6),
                ],
                if (isProcessing) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                ],
                editor,
                const SizedBox(height: 6),
                _ActionToolbar(actions: actions),
                if (result != null) ...[
                  const SizedBox(height: 10),
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

class _ActionToolbar extends StatelessWidget {
  const _ActionToolbar({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.length < 2) {
      return Align(alignment: Alignment.centerRight, child: actions.first);
    }

    final secondaryActions = actions.sublist(0, actions.length - 1);
    final primaryAction = actions.last;
    return LayoutBuilder(
      builder: (context, constraints) {
        final secondary = Wrap(
          alignment: WrapAlignment.start,
          spacing: 6,
          runSpacing: 6,
          children: secondaryActions,
        );
        if (constraints.maxWidth >= 560) {
          return Row(
            children: [
              Expanded(child: secondary),
              const SizedBox(width: 8),
              primaryAction,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            secondary,
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerRight, child: primaryAction),
          ],
        );
      },
    );
  }
}

class _JavaFinderDialog extends StatelessWidget {
  const _JavaFinderDialog({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Java Finder'),
      content: SizedBox(
        width: 720,
        child: _ResponseCodeBlock(code, maxHeight: 320),
      ),
      actions: [
        DevToolsButton(
          key: const ValueKey<String>(
            'driver_automation.java_finder_copy_button',
          ),
          icon: Icons.copy,
          label: 'Copy',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Java Finder copied.')),
              );
            }
          },
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
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
      minLines: 4,
      maxLines: 10,
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

class _FinderModeToggle extends StatelessWidget {
  const _FinderModeToggle({required this.mode, required this.onChanged});

  final FinderEditorMode mode;
  final ValueChanged<FinderEditorMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return ToggleButtons(
      isSelected: [mode == FinderEditorMode.dsl, mode == FinderEditorMode.json],
      onPressed:
          (index) => onChanged(
            index == 0 ? FinderEditorMode.dsl : FinderEditorMode.json,
          ),
      constraints: const BoxConstraints(minHeight: 30, minWidth: 38),
      children: [
        KeyedSubtree(
          key: const ValueKey<String>('driver_automation.finder_mode_dsl'),
          child: const Text('DSL'),
        ),
        KeyedSubtree(
          key: const ValueKey<String>('driver_automation.finder_mode_json'),
          child: const Text('JSON'),
        ),
      ],
    );
  }
}

class _FinderEditor extends StatefulWidget {
  const _FinderEditor({
    required this.mode,
    required this.controller,
    required this.errorText,
    required this.statusText,
    required this.onSuggestion,
  });

  final FinderEditorMode mode;
  final FinderTextEditingController controller;
  final String? errorText;
  final String? statusText;
  final void Function(FinderCompletionContext, FinderCompletionItem)
  onSuggestion;

  @override
  State<_FinderEditor> createState() => _FinderEditorState();
}

class _FinderEditorState extends State<_FinderEditor> {
  final _fieldKey = GlobalKey();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  final _overlayController = OverlayPortalController(
    debugLabel: 'finder-completion-popup',
  );

  FinderCompletionContext _context = const FinderCompletionContext(
    prefix: '',
    replacementStart: 0,
    replacementEnd: 0,
    items: [],
  );
  Offset _popupOffset = Offset.zero;
  double _popupWidth = 320;
  double _popupMaxHeight = 272;
  bool _openUp = false;
  bool _explicit = false;
  int _selectedIndex = 0;
  int _refreshToken = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _focusNode.addListener(_onFocusChanged);
    _recomputeContext();
  }

  @override
  void didUpdateWidget(_FinderEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.mode != widget.mode) {
      _explicit = false;
      _selectedIndex = 0;
      _recomputeContext();
      _scheduleRefresh();
    }
  }

  @override
  void dispose() {
    _hideCompletionPopup();
    widget.controller.removeListener(_onControllerChanged);
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    _explicit = false;
    _selectedIndex = 0;
    _recomputeContext();
    _scheduleRefresh();
  }

  void _onFocusChanged() {
    _scheduleRefresh();
  }

  void _recomputeContext() {
    if (widget.mode != FinderEditorMode.dsl) {
      _context = const FinderCompletionContext(
        prefix: '',
        replacementStart: 0,
        replacementEnd: 0,
        items: [],
      );
      return;
    }
    final selection = widget.controller.selection;
    final caret =
        selection.isValid
            ? selection.extentOffset
            : widget.controller.text.length;
    _context = FinderCompletionContextAnalyzer.analyze(
      widget.controller.text,
      caret,
      explicit: _explicit,
    );
  }

  void _showExplicitCompletion() {
    if (widget.mode != FinderEditorMode.dsl) return;
    _explicit = true;
    _recomputeContext();
    _selectedIndex = 0;
    _scheduleRefresh();
  }

  void _moveSelection(int delta) {
    if (!_canShowPopup || _context.items.isEmpty) return;
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(
        0,
        _context.items.length - 1,
      );
    });
  }

  void _acceptSelection() {
    if (!_canShowPopup || _context.items.isEmpty) return;
    final item = _context.items[_selectedIndex];
    widget.onSuggestion(_context, item);
    _explicit = false;
    _focusNode.requestFocus();
    _scheduleRefresh();
  }

  void _dismissCompletion() {
    _explicit = false;
    _hideCompletionPopup();
    if (mounted) setState(() {});
  }

  void _hideCompletionPopup() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
  }

  bool get _canShowPopup =>
      widget.mode == FinderEditorMode.dsl &&
      _focusNode.hasFocus &&
      (_context.items.isNotEmpty || _context.signature != null);

  void _scheduleRefresh() {
    final token = ++_refreshToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || token != _refreshToken) return;
      _updatePopupAnchor();
      if (_canShowPopup) {
        _overlayController.show();
      } else {
        _hideCompletionPopup();
      }
    });
  }

  void _updatePopupAnchor() {
    final field = _fieldKey.currentContext?.findRenderObject();
    final fieldBox = field is RenderBox ? field : null;
    final editable = _findRenderEditable(field);
    if (fieldBox == null || editable == null || !fieldBox.hasSize) return;

    final selection = widget.controller.selection;
    final caretOffset =
        selection.isValid
            ? selection.extentOffset.clamp(0, widget.controller.text.length)
            : widget.controller.text.length;
    final caret = editable.getLocalRectForCaret(
      TextPosition(offset: caretOffset),
    );
    final globalTop = editable.localToGlobal(caret.topLeft);
    final globalBottom = editable.localToGlobal(caret.bottomLeft);
    final localTop = fieldBox.globalToLocal(globalTop);
    final localBottom = fieldBox.globalToLocal(globalBottom);
    final viewport = MediaQuery.sizeOf(context);
    final availableWidth = math.max(180.0, viewport.width - 16);
    final width = math.min(360.0, math.max(240.0, fieldBox.size.width));
    _popupWidth = math.min(width, availableWidth);

    final spaceBelow = viewport.height - globalBottom.dy;
    final spaceAbove = globalTop.dy;
    _openUp = spaceBelow < 272 && spaceAbove > spaceBelow;
    final availableHeight = math.max(
      88.0,
      (_openUp ? spaceAbove : spaceBelow) - 8,
    );
    _popupMaxHeight = math.min(272.0, availableHeight);

    final anchor = _openUp ? localTop : localBottom;
    var popupGlobalX = globalBottom.dx;
    if (popupGlobalX + _popupWidth > viewport.width - 8) {
      popupGlobalX = viewport.width - 8 - _popupWidth;
    }
    popupGlobalX = math.max(8.0, popupGlobalX);
    final dx = anchor.dx + popupGlobalX - globalBottom.dx;
    final nextOffset = Offset(dx, anchor.dy);
    if (nextOffset != _popupOffset && mounted) {
      setState(() => _popupOffset = nextOffset);
    }
  }

  RenderEditable? _findRenderEditable(RenderObject? object) {
    if (object is RenderEditable) return object;
    RenderEditable? result;
    object?.visitChildren((child) {
      result ??= _findRenderEditable(child);
    });
    return result;
  }

  Widget _buildTextField(BuildContext context) {
    final modeKey =
        widget.mode == FinderEditorMode.dsl
            ? 'driver_automation.finder_dsl_input'
            : 'driver_automation.finder_json_input';
    return KeyedSubtree(
      key: ValueKey<String>(modeKey),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Container(
          key: _fieldKey,
          child: NotificationListener<ScrollNotification>(
            onNotification: (_) {
              _scheduleRefresh();
              return false;
            },
            child: TextField(
              key: const ValueKey<String>('driver_automation.finder_input'),
              controller: widget.controller,
              focusNode: _focusNode,
              minLines: 4,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                alignLabelWithHint: true,
                hintText:
                    widget.mode == FinderEditorMode.dsl
                        ? 'type("Column").first()'
                        : '{ ... }',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                errorText: widget.errorText,
                helperText: widget.statusText,
                helperStyle:
                    widget.statusText == null
                        ? null
                        : TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.arrowDown):
                _FinderCompletionNextIntent(),
            const SingleActivator(LogicalKeyboardKey.arrowUp):
                _FinderCompletionPreviousIntent(),
            const SingleActivator(LogicalKeyboardKey.enter):
                _FinderCompletionAcceptIntent(),
            const SingleActivator(LogicalKeyboardKey.numpadEnter):
                _FinderCompletionAcceptIntent(),
            const SingleActivator(LogicalKeyboardKey.tab):
                _FinderCompletionAcceptIntent(),
            const SingleActivator(LogicalKeyboardKey.escape):
                _FinderCompletionDismissIntent(),
            const SingleActivator(LogicalKeyboardKey.space, control: true):
                _FinderCompletionShowIntent(),
            const SingleActivator(LogicalKeyboardKey.space, meta: true):
                _FinderCompletionShowIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _FinderCompletionNextIntent: _FinderCompletionAction(
                enabled: () => _canShowPopup,
                callback: () => _moveSelection(1),
              ),
              _FinderCompletionPreviousIntent: _FinderCompletionAction(
                enabled: () => _canShowPopup,
                callback: () => _moveSelection(-1),
              ),
              _FinderCompletionAcceptIntent: _FinderCompletionAction(
                enabled: () => _canShowPopup,
                callback: _acceptSelection,
              ),
              _FinderCompletionDismissIntent: _FinderCompletionAction(
                enabled: () => _canShowPopup,
                callback: _dismissCompletion,
              ),
              _FinderCompletionShowIntent: _FinderCompletionAction(
                enabled: () => widget.mode == FinderEditorMode.dsl,
                callback: _showExplicitCompletion,
              ),
            },
            child: OverlayPortal.targetsRootOverlay(
              controller: _overlayController,
              overlayChildBuilder:
                  (context) => CompositedTransformFollower(
                    link: _layerLink,
                    showWhenUnlinked: false,
                    targetAnchor: Alignment.topLeft,
                    followerAnchor:
                        _openUp ? Alignment.bottomLeft : Alignment.topLeft,
                    offset: _popupOffset + Offset(0, _openUp ? -4 : 4),
                    child: TextFieldTapRegion(
                      child: _FinderCompletionPopup(
                        context: _context,
                        selectedIndex: _selectedIndex,
                        width: _popupWidth,
                        maxHeight: _popupMaxHeight,
                        onSelected: (index) {
                          if (index >= 0 && index < _context.items.length) {
                            widget.onSuggestion(
                              _context,
                              _context.items[index],
                            );
                            _focusNode.requestFocus();
                            _scheduleRefresh();
                          }
                        },
                      ),
                    ),
                  ),
              child: _buildTextField(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _FinderCompletionNextIntent extends Intent {
  const _FinderCompletionNextIntent();
}

class _FinderCompletionPreviousIntent extends Intent {
  const _FinderCompletionPreviousIntent();
}

class _FinderCompletionAcceptIntent extends Intent {
  const _FinderCompletionAcceptIntent();
}

class _FinderCompletionDismissIntent extends Intent {
  const _FinderCompletionDismissIntent();
}

class _FinderCompletionShowIntent extends Intent {
  const _FinderCompletionShowIntent();
}

class _FinderCompletionAction<T extends Intent> extends Action<T> {
  _FinderCompletionAction({required this.enabled, required this.callback});

  final bool Function() enabled;
  final VoidCallback callback;

  @override
  bool get isActionEnabled => enabled();

  @override
  Object? invoke(T intent) {
    if (enabled()) callback();
    return null;
  }
}

class _FinderCompletionPopup extends StatelessWidget {
  const _FinderCompletionPopup({
    required this.context,
    required this.selectedIndex,
    required this.width,
    required this.maxHeight,
    required this.onSelected,
  });

  final FinderCompletionContext context;
  final int selectedIndex;
  final double width;
  final double maxHeight;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext _) {
    const popupColor = Color(0xEB171A1F);
    final borderColor = Colors.white.withValues(alpha: 0.13);
    return UnconstrainedBox(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: Material(
          key: const ValueKey<String>(
            'driver_automation.finder_completion_popup',
          ),
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.32),
          color: popupColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
            side: BorderSide(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 2),
              shrinkWrap: true,
              children: [
                if (context.items.isEmpty && context.signature != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
                    child: Text(
                      context.signature!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                for (var index = 0; index < context.items.length; index++)
                  _buildItem(index),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index) {
    final item = context.items[index];
    final selected = index == selectedIndex;
    return InkWell(
      key: ValueKey<String>(
        'driver_automation.finder_suggestion_${item.label}',
      ),
      onTap: () => onSelected(index),
      hoverColor: Colors.white.withValues(alpha: 0.06),
      splashColor: Colors.white.withValues(alpha: 0.10),
      child: Container(
        color: selected ? Colors.white.withValues(alpha: 0.10) : null,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _CompletionLabel(
              label: item.label,
              signature: item.signature,
              prefix: context.prefix,
              selected: selected,
            ),
            const SizedBox(height: 2),
            Text(
              item.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 11,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionLabel extends StatelessWidget {
  const _CompletionLabel({
    required this.label,
    required this.signature,
    required this.prefix,
    required this.selected,
  });

  final String label;
  final String signature;
  final String prefix;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final length = math.min(prefix.length, label.length);
    final color =
        selected ? Theme.of(context).colorScheme.primary : Colors.white;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: label.substring(0, length),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selected ? color : null,
            ),
          ),
          TextSpan(
            text: label.substring(length),
            style: const TextStyle(color: Colors.white),
          ),
          TextSpan(
            text: '  $signature',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
        style: const TextStyle(fontSize: 13, height: 1.1),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class FinderTextEditingController extends TextEditingController {
  FinderTextEditingController({super.text, required this.mode});

  FinderEditorMode mode;

  static final _dslTokenPattern = FinderCompletionRegistry.dslTokenPattern;
  static final _jsonTokenPattern = RegExp(
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
    final tokenPattern =
        mode == FinderEditorMode.dsl ? _dslTokenPattern : _jsonTokenPattern;
    for (final match in tokenPattern.allMatches(text)) {
      if (match.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      final isKey =
          mode == FinderEditorMode.json &&
          match.end < text.length &&
          text[match.end] == ':';
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

    final responseText =
        response == null
            ? 'No response body returned.'
            : JsonPayloads.displayResponse(response);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
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
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ResponseCodeBlock(
                      responseText,
                      muted: response == null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _CopyResultButton(text: responseText),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: _ResultError(message: result.error ?? 'Unknown error'),
            ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 10),
            childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            title: const Text('Raw details'),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final request = _RawPayloadCard(
                    label: 'Canonical input',
                    icon: Icons.call_made,
                    value: _canonicalInput(result),
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

  String _canonicalInput(DriverExecutionResult result) {
    final payload = result.request.payload;
    return payload == null
        ? result.request.rawInput
        : JsonPayloads.displayResponse(payload);
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

class _CopyResultButton extends StatelessWidget {
  const _CopyResultButton({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DevToolsButton(
      key: const ValueKey<String>('driver_automation.result_copy_button'),
      icon: Icons.copy_outlined,
      tooltip: 'Copy response',
      onPressed: () => Clipboard.setData(ClipboardData(text: text)),
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
      padding: const EdgeInsets.all(10),
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
      padding: const EdgeInsets.all(8),
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
      padding: const EdgeInsets.all(8),
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
  const _HistoryPanel({required this.entries});

  final List<HistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return RoundedOutlinedBorder(
      clip: true,
      child: ExpansionTile(
        initiallyExpanded: false,
        dense: true,
        visualDensity: VisualDensity.compact,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        title: Row(
          children: [
            const Text('History'),
            const SizedBox(width: 4),
            Text('(${entries.length})'),
            if (entries.isNotEmpty) ...[
              const Spacer(),
              Flexible(
                child: Text(
                  'Latest: ${entries.first.label} · ${entries.first.summary}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).subtleTextStyle,
                ),
              ),
            ] else ...[
              const Spacer(),
              Flexible(
                child: Text(
                  'No operations in this session.',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).subtleTextStyle,
                ),
              ),
            ],
          ],
        ),
        children: [
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No operations in this session.',
                  style: Theme.of(context).subtleTextStyle,
                ),
              ),
            )
          else
            for (final entry in entries.reversed) _HistoryTile(entry: entry),
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
          child: _ResultLabel('Canonical Input'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: _ResponseText(
            result.request.payload == null
                ? result.request.rawInput
                : JsonPayloads.displayResponse(result.request.payload!),
          ),
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
