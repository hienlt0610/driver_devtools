import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import 'element_explorer_model.dart';

class ElementExplorerOptionsEditor extends StatelessWidget {
  const ElementExplorerOptionsEditor({
    super.key,
    required this.ancestorDepthController,
    required this.descendantDepthController,
    required this.siblingDepthController,
    required this.maxNodesController,
    required this.includeSiblings,
    required this.onIncludeSiblingsChanged,
  });

  final TextEditingController ancestorDepthController;
  final TextEditingController descendantDepthController;
  final TextEditingController siblingDepthController;
  final TextEditingController maxNodesController;
  final bool includeSiblings;
  final ValueChanged<bool> onIncludeSiblingsChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: defaultSpacing,
      runSpacing: denseSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 112,
          child: DevToolsTextField(
            key: const ValueKey<String>(
              'driver_automation.element_explorer_ancestor_depth',
            ),
            controller: ancestorDepthController,
            labelText: 'Ancestors',
          ),
        ),
        SizedBox(
          width: 112,
          child: DevToolsTextField(
            key: const ValueKey<String>(
              'driver_automation.element_explorer_descendant_depth',
            ),
            controller: descendantDepthController,
            labelText: 'Descendants',
          ),
        ),
        SizedBox(
          width: 112,
          child: DevToolsTextField(
            key: const ValueKey<String>(
              'driver_automation.element_explorer_sibling_depth',
            ),
            controller: siblingDepthController,
            labelText: 'Sibling depth',
          ),
        ),
        SizedBox(
          width: 112,
          child: DevToolsTextField(
            key: const ValueKey<String>(
              'driver_automation.element_explorer_max_nodes',
            ),
            controller: maxNodesController,
            labelText: 'Max nodes',
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              key: const ValueKey<String>(
                'driver_automation.element_explorer_include_siblings',
              ),
              value: includeSiblings,
              onChanged: (value) {
                if (value != null) onIncludeSiblingsChanged(value);
              },
            ),
            const Text('Include siblings'),
          ],
        ),
      ],
    );
  }
}

class ElementExplorerViewer extends StatefulWidget {
  const ElementExplorerViewer({
    super.key,
    required this.snapshot,
    required this.truncated,
    this.returnedNodes = 0,
    this.visitedNodes = 0,
  });

  final ElementExplorerSnapshot snapshot;
  final bool truncated;
  final int returnedNodes;
  final int visitedNodes;

  @override
  State<ElementExplorerViewer> createState() => _ElementExplorerViewerState();
}

class _ElementExplorerViewerState extends State<ElementExplorerViewer> {
  static const _rowHeight = 32.0;

  final _expandedNodeIds = <String>{};
  final _rowKeys = <String, GlobalKey>{};
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();
  String? _selectedNodeId;

  @override
  void initState() {
    super.initState();
    _resetSelection();
    _scheduleFocusTarget();
  }

  @override
  void didUpdateWidget(covariant ElementExplorerViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.snapshot, widget.snapshot)) {
      _rowKeys.clear();
      _resetSelection();
      _scheduleFocusTarget();
    }
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _resetSelection() {
    _expandedNodeIds.clear();
    final path = _pathToTarget(widget.snapshot.root);
    _selectedNodeId = path.isEmpty ? widget.snapshot.root.nodeId : path.last;
    _expandedNodeIds.addAll(path.take(path.length - 1));
    if (path.isEmpty && widget.snapshot.root.children.isNotEmpty) {
      _expandedNodeIds.add(widget.snapshot.root.nodeId);
    }
  }

  List<String> _pathToTarget(ElementExplorerNode node) {
    if (node.isTarget) return <String>[node.nodeId];
    for (final child in node.children) {
      final path = _pathToTarget(child);
      if (path.isNotEmpty) return <String>[node.nodeId, ...path];
    }
    return const <String>[];
  }

  ElementExplorerNode? _findNode(ElementExplorerNode node, String? nodeId) {
    if (node.nodeId == nodeId) return node;
    for (final child in node.children) {
      final result = _findNode(child, nodeId);
      if (result != null) return result;
    }
    return null;
  }

  List<_VisibleExplorerNode> _visibleNodes() {
    final result = <_VisibleExplorerNode>[];

    void visit(ElementExplorerNode node, int depth) {
      result.add(_VisibleExplorerNode(node: node, depth: depth));
      if (_expandedNodeIds.contains(node.nodeId)) {
        for (final child in node.children) {
          visit(child, depth + 1);
        }
      }
    }

    visit(widget.snapshot.root, 0);
    return result;
  }

  void _scheduleFocusTarget() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusTarget();
    });
  }

  void _focusTarget() {
    final path = _pathToTarget(widget.snapshot.root);
    final selectedNodeId =
        path.isEmpty ? widget.snapshot.root.nodeId : path.last;
    final changed =
        _selectedNodeId != selectedNodeId ||
        !_expandedNodeIds.containsAll(path.take(path.length - 1));
    if (changed) {
      setState(() {
        _selectedNodeId = selectedNodeId;
        _expandedNodeIds.addAll(path.take(path.length - 1));
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = _rowKeys[selectedNodeId]?.currentContext;
      if (targetContext == null) return;
      unawaited(
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _findNode(widget.snapshot.root, _selectedNodeId);
    final tree = _buildTree(context);
    final properties = _buildProperties(context, selected);
    final content = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              SizedBox(height: 300, child: tree),
              const SizedBox(height: denseSpacing),
              SizedBox(height: 220, child: properties),
            ],
          );
        }
        return SplitPane(
          axis: Axis.horizontal,
          initialFractions: const <double>[0.67, 0.33],
          minSizes: const <double>[340, 220],
          children: [tree, properties],
        );
      },
    );

    return SizedBox(height: 540, child: content);
  }

  Widget _buildTree(BuildContext context) {
    final visibleNodes = _visibleNodes();
    final stats =
        '${widget.returnedNodes} nodes · ${widget.visitedNodes} visited'
        '${widget.truncated ? ' · Truncated' : ''}';
    return RoundedOutlinedBorder(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AreaPaneHeader(
            title: const Text('Element Tree'),
            dense: true,
            roundedTopBorder: false,
            includeTopBorder: false,
            includeBottomBorder: true,
            actions: [
              Tooltip(
                message: stats,
                child: Text(stats, style: Theme.of(context).subtleTextStyle),
              ),
              DevToolsButton(
                key: const ValueKey<String>(
                  'element_explorer.focus_target_button',
                ),
                icon: Icons.center_focus_strong,
                label: 'Focus Target',
                minScreenWidthForText: 800,
                tooltip: 'Focus Target',
                onPressed: _focusTarget,
                outlined: false,
              ),
            ],
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final minWidth = constraints.maxWidth;
                final rows = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in visibleNodes)
                      KeyedSubtree(
                        key: _rowKeys.putIfAbsent(
                          item.node.nodeId,
                          GlobalKey.new,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: minWidth),
                          child: _buildNodeRow(context, item.node, item.depth),
                        ),
                      ),
                  ],
                );
                return Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    key: const ValueKey<String>(
                      'element_explorer.tree.vertical_scroll',
                    ),
                    controller: _verticalController,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: minWidth),
                      child: Scrollbar(
                        controller: _horizontalController,
                        thumbVisibility: true,
                        notificationPredicate:
                            (notification) =>
                                notification.metrics.axis == Axis.horizontal,
                        child: SingleChildScrollView(
                          key: const ValueKey<String>(
                            'element_explorer.tree.horizontal_scroll',
                          ),
                          controller: _horizontalController,
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: minWidth),
                            child: rows,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeRow(
    BuildContext context,
    ElementExplorerNode node,
    int depth,
  ) {
    final selected = node.nodeId == _selectedNodeId;
    final colorScheme = Theme.of(context).colorScheme;
    final hasChildren = node.children.isNotEmpty;
    final expanded = _expandedNodeIds.contains(node.nodeId);
    final row = SizedBox(
      height: _rowHeight,
      child: Material(
        color: selected ? colorScheme.primaryContainer : Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('element_explorer.node.${node.nodeId}'),
          onTap: () => setState(() => _selectedNodeId = node.nodeId),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TreeIndent(depth: depth),
              SizedBox(
                width: 28,
                child:
                    hasChildren
                        ? DevToolsButton.iconOnly(
                          icon:
                              expanded
                                  ? Icons.expand_more
                                  : Icons.chevron_right,
                          tooltip: expanded ? 'Collapse' : 'Expand',
                          onPressed: () {
                            setState(() {
                              if (!expanded) {
                                _expandedNodeIds.add(node.nodeId);
                              } else {
                                _expandedNodeIds.remove(node.nodeId);
                              }
                            });
                          },
                          outlined: false,
                        )
                        : const SizedBox.shrink(),
              ),
              SizedBox(
                width: 20,
                child:
                    node.isTarget
                        ? DevToolsTooltip(
                          message: 'Inspected target',
                          child: Icon(
                            Icons.gps_fixed,
                            semanticLabel: 'Inspected target',
                            size: 14,
                            color: colorScheme.primary,
                          ),
                        )
                        : null,
              ),
              Icon(
                Icons.widgets_outlined,
                size: 15,
                color: Theme.of(context).subtleTextStyle.color,
              ),
              const SizedBox(width: denseSpacing),
              Text(
                node.widgetType,
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight:
                      node.isTarget ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              if (node.text != null) ...[
                const SizedBox(width: denseSpacing),
                Text(
                  node.text!,
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).subtleTextStyle,
                ),
              ],
              if (node.key != null) ...[
                const SizedBox(width: denseSpacing),
                Text(
                  _keyInlineLabel(node.key!),
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).subtleTextStyle,
                ),
              ],
              if (node.childrenState == 'truncated') ...[
                const SizedBox(width: denseSpacing),
                const _NodeBadge(label: 'TRUNCATED'),
              ],
              const SizedBox(width: defaultSpacing),
            ],
          ),
        ),
      ),
    );
    return DevToolsTooltip(message: _nodeTooltip(node), child: row);
  }

  Widget _buildProperties(BuildContext context, ElementExplorerNode? node) {
    return RoundedOutlinedBorder(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AreaPaneHeader(
            title: Text('Properties'),
            dense: true,
            roundedTopBorder: false,
            includeTopBorder: false,
            includeBottomBorder: true,
          ),
          Expanded(
            child:
                node == null
                    ? const Center(child: Text('Select an Element'))
                    : ListView(
                      key: const ValueKey<String>(
                        'element_explorer.properties.scroll',
                      ),
                      padding: const EdgeInsets.all(defaultSpacing),
                      children: [
                        Text(
                          'Widget Identity',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: denseSpacing),
                        _PropertyRow(label: 'Widget', value: node.widgetType),
                        _PropertyRow(
                          label: 'Key',
                          value:
                              node.key == null
                                  ? null
                                  : _keyDisplayValue(node.key!),
                          nullValue:
                              _hasMetadataError(node, 'key')
                                  ? 'Unavailable'
                                  : 'None',
                        ),
                        _PropertyRow(
                          label: 'Key type',
                          value: node.key == null ? null : _keyType(node.key!),
                          nullValue:
                              _hasMetadataError(node, 'key')
                                  ? 'Unavailable'
                                  : 'None',
                        ),
                        _PropertyRow(
                          label: 'Finder compatible',
                          value:
                              node.key == null
                                  ? null
                                  : node.key!['finderCompatible'] == true
                                  ? 'Yes'
                                  : 'No',
                          nullValue:
                              _hasMetadataError(node, 'key')
                                  ? 'Unavailable'
                                  : 'None',
                        ),
                        _PropertyRow(
                          label: 'Text',
                          value: node.text,
                          nullValue:
                              _hasMetadataError(node, 'text')
                                  ? 'Unavailable'
                                  : 'Not available',
                        ),
                        _PropertyRow(
                          label: 'Semantics identifier',
                          value: node.semanticsIdentifier,
                          nullValue:
                              _hasMetadataError(node, 'semanticsIdentifier')
                                  ? 'Unavailable'
                                  : 'Not available',
                        ),
                        _PropertyRow(
                          label: 'Target',
                          value: node.isTarget ? 'Yes' : 'No',
                        ),
                        const SizedBox(height: defaultSpacing),
                        Text(
                          'Element Details',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: denseSpacing),
                        _PropertyRow(label: 'Element', value: node.elementType),
                        _PropertyRow(label: 'Node ID', value: node.nodeId),
                        _PropertyRow(
                          label: 'Parent ID',
                          value: node.parentId,
                          nullValue: 'Root',
                        ),
                        _PropertyRow(
                          label: 'Children',
                          value: _childrenStateLabel(node.childrenState),
                        ),
                        if (node.key != null) ...[
                          const SizedBox(height: denseSpacing),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: EdgeInsets.zero,
                            title: const Text('Raw key metadata'),
                            children: [FormattedJson(json: node.key!)],
                          ),
                        ],
                        if (node.metadataErrors.isNotEmpty) ...[
                          const SizedBox(height: denseSpacing),
                          Text(
                            'Metadata warnings',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          ...node.metadataErrors.map(Text.new),
                        ],
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}

class _VisibleExplorerNode {
  const _VisibleExplorerNode({required this.node, required this.depth});

  final ElementExplorerNode node;
  final int depth;
}

class _TreeIndent extends StatelessWidget {
  const _TreeIndent({required this.depth});

  final int depth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: depth * 20.0,
      height: double.infinity,
      child: CustomPaint(
        painter: _TreeIndentPainter(
          depth: depth,
          color: Theme.of(context).dividerColor,
        ),
      ),
    );
  }
}

class _TreeIndentPainter extends CustomPainter {
  const _TreeIndentPainter({required this.depth, required this.color});

  final int depth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (depth == 0) return;
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1;
    for (var index = 0; index < depth; index++) {
      final x = index * 20.0 + 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    final x = (depth - 1) * 20.0 + 10;
    canvas.drawLine(
      Offset(x, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_TreeIndentPainter oldDelegate) =>
      oldDelegate.depth != depth || oldDelegate.color != color;
}

class _NodeBadge extends StatelessWidget {
  const _NodeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(Radius.circular(3)),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _keyInlineLabel(Map<String, dynamic> key) {
  final value = _keyDisplayValue(key);
  return 'key: ${value.isEmpty ? '(empty)' : value}';
}

String _keyDisplayValue(Map<String, dynamic> key) {
  if (key['kind'] == 'ValueKey' && key['serializable'] == true) {
    final value = key['value'];
    return value == null ? 'null' : value.toString();
  }
  if (key['kind'] == 'ValueKey') {
    final valueType = key['valueType'];
    return valueType is String && valueType.isNotEmpty
        ? 'ValueKey<$valueType>'
        : _keyType(key);
  }
  return _keyType(key);
}

String _keyType(Map<String, dynamic> key) {
  final runtimeType = key['keyRuntimeType'];
  if (runtimeType is String && runtimeType.isNotEmpty) return runtimeType;
  final kind = key['kind'];
  if (kind is String && kind.isNotEmpty) return kind;
  return 'Unknown';
}

String _nodeTooltip(ElementExplorerNode node) {
  final lines = <String>[node.widgetType];
  if (node.key != null) {
    final value = _keyDisplayValue(node.key!);
    lines.add('Key: ${value.isEmpty ? '(empty)' : value}');
    final finderCompatible = node.key!['finderCompatible'];
    if (finderCompatible is bool) {
      lines.add('Finder compatible: ${finderCompatible ? 'Yes' : 'No'}');
    }
  }
  lines.add('Element: ${node.elementType}');
  lines.add('Children: ${_childrenStateLabel(node.childrenState)}');
  if (node.text != null) {
    lines.add('Text: ${node.text!.isEmpty ? '(empty)' : node.text}');
  }
  if (node.semanticsIdentifier != null) {
    lines.add('Semantics: ${node.semanticsIdentifier}');
  }
  return lines.join('\n');
}

String _childrenStateLabel(String state) {
  return switch (state) {
    'notRequested' => 'Not inspected',
    'empty' => 'No children',
    'complete' => 'Complete',
    'partial' => 'Partial',
    'truncated' => 'Truncated',
    _ => state,
  };
}

bool _hasMetadataError(ElementExplorerNode node, String field) {
  return node.metadataErrors.any((error) => error.startsWith('$field:'));
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({
    required this.label,
    required this.value,
    this.nullValue = '—',
  });

  final String label;
  final String? value;
  final String nullValue;

  @override
  Widget build(BuildContext context) {
    final displayValue =
        value == null
            ? nullValue
            : value!.isEmpty
            ? '(empty)'
            : value!;
    return Padding(
      padding: const EdgeInsets.only(bottom: denseSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
            child: Text(label, style: Theme.of(context).subtleTextStyle),
          ),
          Expanded(child: SelectableText(displayValue)),
        ],
      ),
    );
  }
}
