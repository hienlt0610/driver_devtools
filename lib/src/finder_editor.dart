import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'driver_automation_core.dart';
import 'finder_dsl.dart';
import 'protocol/schema/protocol_schema_registry.dart';

enum FinderEditorMode { dsl, json }

void finderSyncLog(String event) {
  debugPrint('[FinderSync] $event');
}

class FinderEditorState {
  FinderEditorState({
    required String initialJson,
    ProtocolSchemaRegistry? registry,
    Map<String, dynamic>? initialCanonical,
  }) : _registry = registry ?? ProtocolSchemaRegistry.builtIn,
       jsonText = initialJson {
    _initialize(initialJson);
    if (initialCanonical != null) {
      _canonical = _copyMap(initialCanonical);
      _canonicalRevision++;
    }
  }

  final ProtocolSchemaRegistry _registry;

  FinderEditorMode mode = FinderEditorMode.dsl;
  String dslText = '';
  String jsonText;
  Map<String, dynamic>? _canonical;
  String? dslError;
  String? jsonError;
  String? dslMessage;
  String? jsonMessage;
  bool _dslDirty = false;
  bool _jsonDirty = false;
  int _canonicalRevision = 0;

  Map<String, dynamic>? get canonical => _canonical;

  int get canonicalRevision => _canonicalRevision;

  bool get dslDraftIsDirty => _dslDirty;

  bool get jsonDraftIsDirty => _jsonDirty;

  bool get dslDraftIsValid => dslError == null && dslMessage == null;

  bool get jsonDraftIsValid => jsonError == null;

  bool get activeDraftIsValid =>
      mode == FinderEditorMode.dsl
          ? dslError == null && dslMessage == null
          : jsonError == null;

  bool get activeDraftIsDirty =>
      mode == FinderEditorMode.dsl ? _dslDirty : _jsonDirty;

  void setMode(FinderEditorMode value) {
    finderSyncLog(
      'modeSwitch target=${value.name} ${_diagnosticState()} '
      'regenerationSkipped=true reason=modeSwitchOnly',
    );
    mode = value;
  }

  void updateDsl(String source) {
    dslText = source;
    _dslDirty = true;
    dslError = null;
    dslMessage = null;
    finderSyncLog('DSL userEdit ${_diagnosticState()}');
    try {
      final canonical = FinderDslCodec.toCanonical(
        FinderDslParser.parse(source),
        registry: _registry,
      );
      finderSyncLog('DSL validationSucc ${_diagnosticState()}');
      _commit(canonical, source: FinderEditorMode.dsl);
    } on FinderDslException catch (error) {
      dslError = error.toString();
      finderSyncLog('DSL validationFailed ${_diagnosticState()}');
    }
  }

  void updateJson(String source) {
    jsonText = source;
    _jsonDirty = true;
    jsonError = null;
    jsonMessage = null;
    finderSyncLog('JSON userEdit ${_diagnosticState()}');
    try {
      final canonical = JsonPayloads.parseObject(source);
      final validation = _registry.validateFinderPayload(canonical);
      if (!validation.isValid) {
        throw FinderDslException(validation.errors.join('\n'));
      }
      jsonMessage =
          validation.messages.isEmpty ? null : validation.messages.join('\n');
      finderSyncLog('JSON validationSucc ${_diagnosticState()}');
      _commit(canonical, source: FinderEditorMode.json);
    } on JsonPayloadException catch (error) {
      jsonError = 'Invalid or incomplete JSON\n$error';
      finderSyncLog('JSON validationFailed ${_diagnosticState()}');
    } on FinderDslException catch (error) {
      jsonError = error.toString();
      finderSyncLog('JSON validationFailed ${_diagnosticState()}');
    }
  }

  void loadCanonical(Map<String, dynamic> value) {
    final canonical = _copyMap(value);
    final validation = _registry.validateFinderPayload(canonical);
    if (!validation.isValid) {
      throw FinderDslException(validation.errors.join('\n'));
    }
    jsonMessage =
        validation.messages.isEmpty ? null : validation.messages.join('\n');
    _canonical = canonical;
    _canonicalRevision++;
    jsonText = _formatJson(canonical);
    jsonError = null;
    _jsonDirty = false;
    finderSyncLog('programmatic commit ${_diagnosticState()}');
    _updateDslFromCanonical();
  }

  void _initialize(String source) {
    try {
      final canonical = JsonPayloads.parseObject(source);
      final validation = _registry.validateFinderPayload(canonical);
      if (!validation.isValid) {
        jsonError = validation.errors.join('\n');
        return;
      }
      jsonMessage =
          validation.messages.isEmpty ? null : validation.messages.join('\n');
      _canonical = _copyMap(canonical);
      _canonicalRevision++;
      jsonText = _formatJson(_canonical!);
      _updateDslFromCanonical();
    } on JsonPayloadException catch (error) {
      jsonError = 'Invalid or incomplete JSON\n$error';
    }
  }

  void _commit(Map<String, dynamic> value, {required FinderEditorMode source}) {
    _canonical = _copyMap(value);
    _canonicalRevision++;
    finderSyncLog(
      '${source.name} commit ${_diagnosticState()} '
      'sotCommitted=true regenerationSkipped=false',
    );
    if (source == FinderEditorMode.dsl) {
      _dslDirty = false;
      dslError = null;
      jsonText = _formatJson(_canonical!);
      jsonError = null;
      jsonMessage = null;
      _jsonDirty = false;
      finderSyncLog('JSON regeneration ${_diagnosticState()}');
      return;
    }

    _jsonDirty = false;
    jsonError = null;
    _updateDslFromCanonical();
  }

  void _updateDslFromCanonical() {
    try {
      dslText = FinderDslGenerator.generateCanonical(
        _canonical!,
        registry: _registry,
      );
      dslError = null;
      dslMessage = null;
      _dslDirty = false;
      finderSyncLog('DSL regeneration ${_diagnosticState()}');
    } on FinderDslException catch (error) {
      dslMessage = error.toString();
      dslError = null;
      _dslDirty = false;
      finderSyncLog(
        'DSL regenerationFailed ${_diagnosticState()} '
        'regenerationSkipped=false',
      );
    }
  }

  String _diagnosticState() {
    return 'mode=${mode.name} '
        'dslValid=$dslDraftIsValid '
        'jsonValid=$jsonDraftIsValid '
        'dslDirty=$_dslDirty '
        'jsonDirty=$_jsonDirty '
        'canonicalRevision=$_canonicalRevision '
        'sotCommitted=${_canonical != null}';
  }

  String _formatJson(Map<String, dynamic> value) {
    return const JsonEncoder.withIndent('  ').convert(value);
  }

  static Map<String, dynamic> _copyMap(Map<String, dynamic> value) {
    return {
      for (final entry in value.entries) entry.key: _copyValue(entry.value),
    };
  }

  static Object? _copyValue(Object? value) {
    if (value is Map<String, dynamic>) return _copyMap(value);
    if (value is List) return value.map(_copyValue).toList();
    return value;
  }
}
