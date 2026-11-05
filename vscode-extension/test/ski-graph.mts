import assert from 'node:assert/strict';
import { test } from 'node:test';
import { complete, hover, hoverText, loadFixture, open, withServer } from './lsp-helpers.mts';

test('SKI completes defined nodes and hovers their definitions', { timeout: 5000 }, async () => {
  await withServer(async (connection, initialization) => {
    assert.deepEqual(initialization.capabilities.completionProvider.triggerCharacters, ['#']);
    assert.equal(initialization.capabilities.hoverProvider, true);

    const { uri, text } = await loadFixture('ski-lsp-test.ski');
    open(connection, uri, 'ski-graph', text);
    const items = await complete(connection, uri, 4, 6);
    assert.deepEqual(
      items.map((item) => item.label),
      ['#0', '#1', '#2'],
    );
    assert.deepEqual(items[1].textEdit, {
      range: { start: { line: 4, character: 5 }, end: { line: 4, character: 6 } },
      newText: '#1',
    });
    assert.match((await hoverText(connection, uri, 0, 6)) ?? '', /#1 = I/);
    assert.equal(await hover(connection, uri, 3, 4), null);
  });
});
