import 'package:driver_devtools/src/finder_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts in DSL mode with both drafts derived from canonical JSON', () {
    final state = FinderEditorState(
      initialJson: '{"finderType":"ByText","text":"Login"}',
    );

    expect(state.mode, FinderEditorMode.dsl);
    expect(state.dslText, 'text("Login")');
    expect(state.jsonText, contains('"finderType": "ByText"'));
    expect(state.canonical, {'finderType': 'ByText', 'text': 'Login'});
  });

  test('commits valid DSL edits and updates a clean JSON draft', () {
    final state = FinderEditorState(
      initialJson: '{"finderType":"ByText","text":"Login"}',
    );

    state.updateDsl('type("Column")');

    expect(state.dslError, isNull);
    expect(state.canonical, {'finderType': 'ByType', 'type': 'Column'});
    expect(state.jsonText, contains('"finderType": "ByType"'));
    expect(state.jsonError, isNull);
  });

  test('regenerates JSON after a valid DSL edit clears invalid JSON', () {
    final state = FinderEditorState(
      initialJson: '{"finderType":"ByType","type":"Column"}',
    );

    state.updateJson('');
    expect(state.jsonError, isNotNull);

    state.updateDsl('type("Row")');

    expect(state.canonical, {'finderType': 'ByType', 'type': 'Row'});
    expect(state.jsonText, contains('"type": "Row"'));
    expect(state.jsonError, isNull);
  });

  test('regenerates DSL after a valid JSON edit clears invalid DSL', () {
    final state = FinderEditorState(
      initialJson: '{"finderType":"ByType","type":"Column"}',
    );

    state.updateDsl('type("Column"');
    expect(state.dslError, isNotNull);

    state.updateJson('{"finderType":"ByType","type":"Text"}');

    expect(state.canonical, {'finderType': 'ByType', 'type': 'Text'});
    expect(state.dslText, 'type("Text")');
    expect(state.dslError, isNull);
  });

  test('invalid DSL keeps the last committed canonical finder', () {
    final state = FinderEditorState(
      initialJson: '{"finderType":"ByText","text":"Login"}',
    );
    final committed = state.canonical;

    state.updateDsl('type("Column"');

    expect(state.dslError, isNotNull);
    expect(state.canonical, committed);
    expect(state.jsonText, contains('"text": "Login"'));
  });

  test('regenerates an invalid DSL draft from a valid JSON edit', () {
    final state = FinderEditorState(
      initialJson: '{"finderType":"ByText","text":"Login"}',
    );
    state.updateDsl('type("Column"');

    state.updateJson('{"finderType":"ByType","type":"Row"}');

    expect(state.canonical, {'finderType': 'ByType', 'type': 'Row'});
    expect(state.dslText, 'type("Row")');
    expect(state.dslError, isNull);
  });

  test('keeps unknown JSON finders executable without fabricating DSL', () {
    final state = FinderEditorState(
      initialJson: '{"finderType":"ByText","text":"Login"}',
    );

    state.updateJson('{"finderType":"CustomFinder","foo":"bar"}');

    expect(state.jsonError, isNull);
    expect(state.jsonMessage, contains('Schema unavailable'));
    expect(state.canonical, {'finderType': 'CustomFinder', 'foo': 'bar'});
    expect(state.dslText, 'text("Login")');
    expect(state.dslMessage, contains('not representable'));
  });

  test('mode switching does not discard either draft', () {
    final state = FinderEditorState(
      initialJson: '{"finderType":"ByText","text":"Login"}',
    );
    state.updateDsl('type("Column"');
    state.setMode(FinderEditorMode.json);

    expect(state.dslText, 'type("Column"');
    expect(state.jsonText, contains('"text": "Login"'));
    expect(state.mode, FinderEditorMode.json);
  });
}
